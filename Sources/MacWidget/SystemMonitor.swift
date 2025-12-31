// ============================================================================
// SystemMonitor.swift - 系統監控器
// ============================================================================
// 這個檔案負責監控 Mac 電腦的系統資源使用情況，包括：
// - CPU（處理器）使用率
// - 記憶體（RAM）使用量
// - 硬碟儲存空間使用量
// ============================================================================

// ----------------------------------------------------------------------------
// 匯入必要的程式庫（類似其他語言的 import 或 include）
// ----------------------------------------------------------------------------
import Foundation  // 基礎功能庫：提供字串處理、檔案操作等基本功能
import Darwin      // macOS 底層系統 API：讓我們可以存取作業系統的核心資訊
import Combine     // 響應式程式設計框架：用於資料變化時自動通知介面更新

// ============================================================================
// 常數定義區
// ============================================================================
// 【技術背景說明】
// macOS 作業系統是用 C 語言寫的，它有一些「巨集常數」（macro constants）
// Swift 無法直接使用這些 C 巨集，所以我們要手動計算並定義這些數值
//
// 【概念解釋】
// MemoryLayout 是 Swift 用來計算資料結構在記憶體中佔用多少空間的工具
// 舉例：假設一個「學生資料」結構包含姓名、年齡等，MemoryLayout 會告訴你它佔用多少位元組
// ----------------------------------------------------------------------------

// HOST_CPU_LOAD_INFO_COUNT_SWIFT：告訴系統 CPU 負載資訊結構有多大
// 計算方式：CPU 負載資訊的總大小 ÷ 單一整數的大小 = 需要多少個整數來儲存
private let HOST_CPU_LOAD_INFO_COUNT_SWIFT = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)

// HOST_VM_INFO64_COUNT_SWIFT：告訴系統記憶體（虛擬記憶體）資訊結構有多大
// 計算方式同上，但針對的是 64 位元的記憶體統計資料結構
private let HOST_VM_INFO64_COUNT_SWIFT = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

// ============================================================================
// SystemMonitor 類別 - 系統監控器主體
// ============================================================================
// 【類別說明】
// 這是一個「可被觀察的物件」（ObservableObject）
// 意思是：當這個物件裡的資料改變時，使用它的畫面會自動更新
// 就像 Excel 試算表一樣，當一個格子的值改變，參照它的其他格子也會跟著更新
// ----------------------------------------------------------------------------
class SystemMonitor: ObservableObject {
    
    // ========================================================================
    // 【對外公開的資料屬性】
    // @Published 標記代表：這些變數改變時，會自動通知所有「訂閱者」更新
    // 類似「訂閱 YouTube 頻道」的概念，當有新影片（資料更新），訂閱者會收到通知
    // ========================================================================
    
    @Published var cpuUsage: String = "0%"           // CPU 使用率，例如 "45.2%"
    @Published var memoryUsage: String = "0 / 0 GB"  // 記憶體使用量，例如 "8.5 / 16.0 GB"
    @Published var diskUsage: String = "0 / 0 GB"    // 硬碟使用量，例如 "250 / 500 GB"
    @Published var diskFree: String = "0 GB"         // 硬碟剩餘空間，例如 "250 GB"
    
    // ========================================================================
    // 【內部私有屬性】
    // private 代表這些變數只能在這個類別內部使用，外部無法存取
    // 這是一種保護機制，避免外部程式碼意外修改內部狀態
    // ========================================================================
    
    private var timer: Timer?  // 計時器：用來定期執行更新（問號代表這個變數可以是空值）
    
    // 儲存「上一次」的 CPU 使用資訊，用來計算兩次測量之間的變化
    // cpu_ticks 是一個包含 4 個數字的組合：(使用者模式, 系統模式, 閒置, 低優先度)
    private var previousInfo = host_cpu_load_info(cpu_ticks: (0, 0, 0, 0))
    
    // 標記是否已經有「上一次」的資料（第一次執行時沒有）
    private var hasPreviousInfo = false
    
    // ========================================================================
    // 【初始化函式】- 建構子（Constructor）
    // 當程式建立一個 SystemMonitor 物件時，這個函式會自動執行
    // ========================================================================
    init() {
        startMonitoring()  // 自動開始監控
    }
    
    // ========================================================================
    // 【開始監控函式】
    // 設定一個計時器，每隔 1 秒自動更新系統資訊
    // ========================================================================
    func startMonitoring() {
        updateStats()  // 先立即更新一次
        
        // 建立一個重複執行的計時器：
        // - withTimeInterval: 1.0 → 每 1 秒執行一次
        // - repeats: true → 重複執行（不是只執行一次）
        // - [weak self] → 防止記憶體洩漏的技術（避免物件無法被正常釋放）
        // - { _ in ... } → 這是一個「閉包」（closure），類似匿名函式
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()  // 每秒呼叫 updateStats() 更新資料
        }
    }
    
    // ========================================================================
    // 【更新統計資料函式】
    // 這是主要的資料更新邏輯，會呼叫各個子函式取得 CPU、記憶體、硬碟資訊
    // private 代表這個函式只能在這個類別內部使用
    // ========================================================================
    private func updateStats() {
        // 更新 CPU 使用率
        // String(format: "%.1f%%", ...) 是格式化字串：
        // %.1f 代表顯示小數點後 1 位的浮點數
        // %% 代表顯示一個 % 符號
        self.cpuUsage = String(format: "%.1f%%", getCPUUsage())
        
        // 更新記憶體使用量
        let mem = getMemoryUsage()  // 取得記憶體資訊（已用, 總共）
        // %.1f 代表顯示小數點後 1 位
        self.memoryUsage = String(format: "%.1f / %.1f GB", mem.used, mem.total)
        
        // 更新硬碟使用量
        let disk = getDiskUsage()  // 取得硬碟資訊（已用, 總共, 剩餘）
        // %.0f 代表不顯示小數（整數）
        self.diskUsage = String(format: "%.0f / %.0f GB", disk.used, disk.total)
        self.diskFree = String(format: "%.0f GB", disk.free)
    }
    
    // ========================================================================
    // 【CPU 使用率計算函式】
    // 
    // 【原理說明】
    // CPU 使用率的計算並不是直接讀取一個數字，而是要比較「兩個時間點」的差異
    // 
    // 想像一個計步器：
    // - 早上顯示 1000 步
    // - 中午顯示 3000 步
    // - 所以你早上到中午走了 2000 步
    //
    // CPU 使用率也是類似的概念：
    // - 系統會記錄 CPU 處於各種狀態的「時間刻度」（ticks）
    // - 我們比較兩次測量的差異，計算「工作時間 ÷ 總時間」得到使用率
    //
    // CPU 的四種狀態：
    // 1. 使用者模式（user）：執行一般應用程式
    // 2. 系統模式（system）：執行作業系統核心任務
    // 3. 閒置模式（idle）：CPU 沒事做
    // 4. 低優先度模式（nice）：執行低優先度的背景任務
    //
    // -> Double 代表這個函式會回傳一個「雙精度浮點數」（有小數的數字）
    // ========================================================================
    private func getCPUUsage() -> Double {
        // 準備一個變數來儲存資料數量
        var count = HOST_CPU_LOAD_INFO_COUNT_SWIFT
        
        // 準備一個空的結構來接收 CPU 資訊
        var info = host_cpu_load_info(cpu_ticks: (0, 0, 0, 0))
        
        // 【呼叫系統 API 取得 CPU 資訊】
        // 這段程式碼比較複雜，主要是在處理 Swift 和 C 語言之間的資料轉換
        // withUnsafeMutablePointer：取得變數的記憶體位址（指標）
        // withMemoryRebound：將記憶體位址轉換成系統 API 需要的格式
        // host_statistics：macOS 系統 API，用來取得主機統計資訊
        // mach_host_self()：取得目前電腦的識別碼
        // HOST_CPU_LOAD_INFO：告訴系統我們要的是 CPU 負載資訊
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(HOST_CPU_LOAD_INFO_COUNT_SWIFT)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        // 檢查 API 呼叫是否成功
        // guard 是 Swift 的流程控制：如果條件不成立，就執行 else 區塊並離開函式
        // KERN_SUCCESS 是系統常數，代表「操作成功」
        guard result == KERN_SUCCESS else { return 0.0 }
        
        // 【首次執行的特殊處理】
        // 第一次執行時沒有「上一次」的資料可以比較，所以只儲存不計算
        if !hasPreviousInfo {
            previousInfo = info       // 儲存這次的資料
            hasPreviousInfo = true    // 標記已經有資料了
            return 0.0                // 回傳 0%（因為無法計算）
        }
        
        // 【計算各狀態的時間差】
        // cpu_ticks.0, .1, .2, .3 分別代表四種狀態的累計時間刻度
        // 用「這次」減去「上次」得到這段時間內各狀態的持續時間
        let userDiff = Double(info.cpu_ticks.0 - previousInfo.cpu_ticks.0)  // 使用者模式時間差
        let sysDiff  = Double(info.cpu_ticks.1 - previousInfo.cpu_ticks.1)  // 系統模式時間差
        let idleDiff = Double(info.cpu_ticks.2 - previousInfo.cpu_ticks.2)  // 閒置模式時間差
        let niceDiff = Double(info.cpu_ticks.3 - previousInfo.cpu_ticks.3)  // 低優先度模式時間差
        
        // 計算總時間 = 所有狀態時間的總和
        let totalTicks = userDiff + sysDiff + idleDiff + niceDiff
        
        // 儲存這次的資料，供下次計算使用
        previousInfo = info
        
        // 避免除以零的錯誤（數學上除以零會出錯）
        if totalTicks == 0 { return 0.0 }
        
        // 【計算 CPU 使用率】
        // 「已使用」時間 = 使用者 + 系統 + 低優先度（不包括閒置）
        let usedTicks = userDiff + sysDiff + niceDiff
        
        // 使用率 = (已使用時間 ÷ 總時間) × 100%
        return (usedTicks / totalTicks) * 100.0
    }
    
    // ========================================================================
    // 【記憶體使用量計算函式】
    //
    // 【原理說明】
    // 電腦的記憶體（RAM）會被分成不同的區塊，主要有：
    // - Active（活躍）：正在被應用程式使用的記憶體
    // - Wired（固定）：作業系統核心使用，不能被換出到硬碟的記憶體
    // - Inactive（非活躍）：最近用過但目前沒在用，可以快速被重新使用
    // - Free（空閒）：完全沒被使用的記憶體
    //
    // 我們計算「已使用」= Active + Wired（這是最直觀的「正在使用」的定義）
    //
    // -> (used: Double, total: Double) 代表回傳一個包含兩個數字的組合
    //    第一個叫 used（已使用），第二個叫 total（總共）
    // ========================================================================
    private func getMemoryUsage() -> (used: Double, total: Double) {
        // 【取得電腦的總實體記憶體】
        // ProcessInfo.processInfo 是系統提供的工具，可以取得各種系統資訊
        // physicalMemory 回傳的是位元組（bytes）數
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        
        // 準備呼叫系統 API
        var count = HOST_VM_INFO64_COUNT_SWIFT
        
        // 【配置記憶體空間來接收資料】
        // UnsafeMutablePointer.allocate：在記憶體中預留一塊空間
        // 這是較低階的操作，需要手動管理記憶體
        let infoPointer = UnsafeMutablePointer<vm_statistics64>.allocate(capacity: 1)
        
        // defer 區塊會在函式結束時自動執行，確保記憶體被正確釋放
        // 這就像「借東西一定要還」的規則
        defer { infoPointer.deallocate() }
        
        // 【呼叫系統 API 取得記憶體統計資訊】
        // host_statistics64：取得 64 位元的主機統計資訊
        // HOST_VM_INFO64：指定我們要取得虛擬記憶體資訊
        let result = infoPointer.withMemoryRebound(to: integer_t.self, capacity: Int(HOST_VM_INFO64_COUNT_SWIFT)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
        
        // 從指標取得實際的資料內容
        let info = infoPointer.pointee
        
        // 計算已使用的記憶體
        var usedBytes: UInt64 = 0  // UInt64 是無符號 64 位元整數（只能存正數，但範圍更大）
        
        if result == KERN_SUCCESS {
            // 【頁面大小說明】
            // 作業系統管理記憶體的單位是「頁面」（page），不是位元組
            // 頁面大小通常是 4KB 或 16KB
            // 系統回傳的是「頁面數量」，要乘以頁面大小才是實際的位元組數
            let pageSize = vm_kernel_page_size
            
            // 活躍記憶體 = 活躍頁面數 × 頁面大小
            let active = UInt64(info.active_count) * UInt64(pageSize)
            
            // 固定記憶體 = 固定頁面數 × 頁面大小
            let wired = UInt64(info.wire_count) * UInt64(pageSize)
            
            // 已使用記憶體 = 活躍 + 固定
            usedBytes = active + wired
        }
        
        // 【單位轉換：位元組 → GB】
        // 1 GB = 1,073,741,824 位元組（1024 × 1024 × 1024）
        // 用 1_073_741_824.0 是 Swift 的數字寫法，底線可以讓大數字更易讀
        let usedGB = Double(usedBytes) / 1_073_741_824.0
        let totalGB = Double(totalBytes) / 1_073_741_824.0
        
        // 回傳已使用和總共的 GB 數
        return (usedGB, totalGB)
    }
    
    // ========================================================================
    // 【硬碟使用量計算函式】
    //
    // 【原理說明】
    // 這個函式比較簡單，因為 macOS 提供了直接的 API 來取得檔案系統資訊
    // "/" 代表根目錄，也就是整個系統磁碟
    //
    // -> (used: Double, total: Double, free: Double) 回傳三個數字的組合
    // ========================================================================
    private func getDiskUsage() -> (used: Double, total: Double, free: Double) {
        // do-catch 是 Swift 的錯誤處理機制
        // 類似其他語言的 try-catch
        // 某些操作可能會失敗（例如磁碟被移除），需要處理這些錯誤情況
        do {
            // 【取得檔案系統屬性】
            // FileManager 是 Swift 提供的檔案管理工具
            // attributesOfFileSystem(forPath: "/") 取得根目錄所在磁碟的資訊
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            
            // 從屬性字典中取得磁碟剩餘空間和總空間
            // as? NSNumber 是型別轉換，把資料轉成數字格式
            // ?.int64Value 是「可選鏈」，如果轉換成功就取得數值，否則就是空值
            if let freeSize = (attrs[.systemFreeSize] as? NSNumber)?.int64Value,
               let totalSize = (attrs[.systemSize] as? NSNumber)?.int64Value {
                
                // 單位轉換：位元組 → GB
                let freeGB = Double(freeSize) / 1_073_741_824.0
                let totalGB = Double(totalSize) / 1_073_741_824.0
                
                // 已使用 = 總共 - 剩餘
                let usedGB = totalGB - freeGB
                
                return (usedGB, totalGB, freeGB)
            }
        } catch {
            // 如果發生錯誤，印出錯誤訊息到控制台（給開發者看的，使用者不會看到）
            // \(error) 是字串插值，會把 error 變數的內容嵌入字串中
            print("Error getting disk usage: \(error)")
        }
        
        // 如果取得資訊失敗，回傳全部為 0
        return (0, 0, 0)
    }
}
