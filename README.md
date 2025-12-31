# Mac Widgets

一個輕量級的 macOS 桌面系統監控小工具，以優雅的毛玻璃效果顯示系統資源使用情況。

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## 功能特色

- **即時系統監控** - 持續監控並顯示系統資源使用情況
- **CPU 負載監控** - 即時顯示處理器使用率
- **記憶體監控** - 顯示記憶體使用情況
- **硬碟監控** - 顯示硬碟總容量、已用空間和剩餘空間
- **優雅設計** - 採用 macOS 原生毛玻璃效果（Ultra Thin Material）
- **桌面浮動** - 始終顯示在其他視窗上方
- **輕量化** - 低資源佔用，不影響系統效能

## 系統需求

- macOS 13.0 (Ventura) 或更高版本
- Xcode 14.0 或更高版本（用於編譯）

## 安裝方式

### 方法一：使用預編譯腳本

1. 克隆此儲存庫：
```bash
git clone https://github.com/vollocare/mac_widgets.git
cd mac_widgets
```

2. 執行編譯腳本：
```bash
chmod +x build-app.sh
./build-app.sh
```

3. 應用程式將會被建立在 `build/MacWidget.app`，將它移動到「應用程式」資料夾即可使用。

### 方法二：使用 Swift Package Manager

```bash
swift build -c release
```

編譯完成後，執行檔位於 `.build/release/MacWidget`

## 使用說明

1. 啟動應用程式後，小工具會自動顯示在桌面上
2. 可以拖曳小工具移動到任何位置
3. 右鍵點擊小工具選擇「結束 MacWidget」可關閉應用程式
4. 小工具會持續更新系統資源資訊

## 技術細節

- **開發語言**: Swift
- **UI 框架**: SwiftUI
- **最低部署目標**: macOS 13.0
- **架構**: 採用 `@StateObject` 和 `ObservableObject` 實現響應式 UI
- **視窗設定**:
  - 透明背景
  - 隱藏標題列
  - 浮動層級（`.floating`）
  - 可拖曳移動

## 專案結構

```
mac_widgets/
├── Sources/
│   └── MacWidget/
│       ├── MacWidgetApp.swift      # 應用程式入口點
│       ├── ContentView.swift       # 主要 UI 介面
│       └── SystemMonitor.swift     # 系統監控邏輯
├── Resources/
│   └── Info.plist                  # 應用程式資訊檔案
├── Package.swift                   # Swift Package 設定
└── build-app.sh                    # 編譯腳本
```

## 開發計劃

- [ ] 支援自訂主題顏色
- [ ] 支援調整更新頻率
- [ ] 加入網路流量監控
- [ ] 支援多個小工具實例
- [ ] 加入偏好設定視窗

## 授權

MIT License

## 作者

**Louis Lai**

如有問題或建議，歡迎提交 Issue 或 Pull Request。
