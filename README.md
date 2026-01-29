<img width="6335" height="2100" alt="image" src="https://github.com/user-attachments/assets/e044e085-4035-4c42-bde3-ca9d4dc431cc" />

# Zero

> **Code without footprints.**  
> Zero Pollution. Zero Config. Native Experience.

<img width="1312" height="912" alt="image" src="https://github.com/user-attachments/assets/00186d99-b578-4a62-a8fa-093c8dbfcc3e" />

**Zero** is a native macOS IDE designed for ephemeral development. It creates isolated, disposable Docker environments instantly, allowing you to code without polluting your local machine.


## ✨ Features

- **🐳 Instant Environments**: Spawns lightweight Alpine Linux containers (~50MB) in seconds.
- **📝 Native Editor**: High-performance Swift-based editor with syntax highlighting for 190+ languages.
- **🎨 Beautiful UI**: Material Theme icons, dark mode, and a clean macOS-native interface.
- **🐙 Git Integration**: Seamless GitHub login, repository browsing (User/Org), and cloning.
- **🔒 Secure & Isolated**: All dependencies and files stay inside the container. No local `node_modules` or `venvs`.
- **⌨️ Developer Friendly**: Line numbers, breadcrumbs, and status bar info.

## 🚀 Installation

Download the latest version from **[GitHub Releases](https://github.com/zero-ide/Zero/releases)**.

1. Download `Zero.dmg`
2. Drag `Zero.app` to Applications
3. Run and code!

> **Note**: Requires Docker Desktop to be running.

## 🛠️ Tech Stack

- **Language**: Swift 5.9
- **UI Framework**: SwiftUI (macOS 14+)
- **Container Engine**: Docker (via Swift Client)
- **Editor**: Highlightr (Highlight.js wrapper)

## 📦 Building form Source

```bash
git clone https://github.com/zero-ide/Zero.git
cd Zero

# Build and Run
swift run

# Build DMG
./scripts/build_dmg.sh
```

## 🤝 Contributing

Pull requests are welcome! Please check the issues for open tasks.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

Built with ❤️ by [Zero Team](https://github.com/zero-ide)
