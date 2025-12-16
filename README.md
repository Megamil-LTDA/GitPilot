<div align="center">

# ✈️ GitPilot

**Automated Git Monitoring & Build Triggering for macOS**

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

*Monitor your Git repositories, detect new commits, and automatically trigger builds — all from your menu bar.*

---

**Developed by [Megamil](mailto:eduardo@megamil.com.br)** • Open Source • Made with ❤️ in Brazil

</div>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔍 **Smart Monitoring** | Continuously monitors Git repositories for new commits or tags |
| ⚡ **Trigger Rules** | Execute custom commands based on commit message patterns |
| 🏷️ **Tag Monitoring** | Watch for new tags (e.g., `-prod`, `-dev`) instead of commits |
| 📝 **Template Variables** | Use `{{commits}}`, `{{branch}}`, etc. in your commands |
| 🔨 **Force Build** | Manually trigger builds/tests using the latest commit without needing a new push |
| 📬 **Notifications** | Send alerts via Telegram, Microsoft Teams, or native macOS notifications |
| 🎛️ **Granular Notifications** | Configure which notification types each messenger receives |
| 👥 **Notification Groups** | Organize notification settings per project or team |
| 🌍 **Multi-language** | Fully translated to 🇧🇷 Portuguese, 🇺🇸 English, and 🇪🇸 Spanish |
| 📤 **Export/Import** | Share configurations with your team via JSON |
| 🗑️ **System Reset** | Easily wipe all data and start fresh with a single click |
| 📊 **Check History** | Complete log of all monitoring attempts with Git output |

---

## 🚀 Quick Start

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ (for building from source)
- Git installed on your system

### Installation

#### Option 1: Download Release
Download the latest `.app` from [Releases](https://github.com/Megamil-LTDA/GitPilot/releases)

#### Option 2: Build from Source
```bash
git clone https://github.com/Megamil-LTDA/GitPilot.git
cd GitPilot
./build_and_run.sh
```

#### On Application Crash
```bash
pkill -9 -f GitPilot
```

### First Steps

1. **Click the "✈️" icon** in your menu bar
2. **Add a Repository** → Select your local Git folder
3. **Create a Trigger** → Define the command to run (e.g., `sh deploy.sh`)
4. **Set up Notifications** → Create a group with Telegram/Teams webhooks
5. **Start Monitoring** → GitPilot will check for new commits automatically

---

## 📝 Template Variables

Use these variables in your trigger commands — they'll be replaced with actual values at runtime:

| Variable | Description | Example Output |
|----------|-------------|----------------|
| `{{commits}}` | Last 5 commits with author (multi-line) | `- abc1234 Fix bug (Eduardo)` |
| `{{commits_oneline}}` | Last 5 commits (single line, pipe-separated) | `abc1234: Fix bug (Eduardo) \| def5678: Add feature (João)` |
| `{{commit_hash}}` | Short commit hash (7 chars) | `abc1234` |
| `{{commit_hash_full}}` | Full commit hash | `abc1234567890...` |
| `{{commit_message}}` | Commit message that triggered the build | `--deploy Fix login bug` |
| `{{branch}}` | Current branch name | `main` |
| `{{repo_name}}` | Repository name | `my-project` |
| `{{repo_path}}` | Full repository path | `/Users/dev/projects/my-project` |
| `{{date}}` | Current date | `2024-01-15` |
| `{{datetime}}` | Current date and time | `2024-01-15 14:30:00` |

### Example Usage

```bash
# Flutter build with changelog
flutter pub get && \
cd ios && \
fastlane build_and_upload changelog:"{{commits}}"

# Deploy with commit info
./deploy.sh --branch={{branch}} --version={{commit_hash}}
```

---

## 🔔 Notification Settings

### Notification Types

Configure which notifications each messenger (Telegram/Teams) receives:

| Notification | Description |
|--------------|-------------|
| 📥 **New Commit/Tag** | When a new commit or tag is detected |
| 🚀 **Trigger Starting** | When a trigger command begins execution |
| ✅ **Build Success** | When a build completes successfully |
| ❌ **Build Failure** | When a build fails |
| ⚠️ **Git Check Error** | When there's an error checking the repository |

### Telegram Setup

1. Create a bot with [@BotFather](https://t.me/botfather)
2. Get your Chat ID from [@userinfobot](https://t.me/userinfobot)
3. Add the token and chat ID to a Notification Group
4. Use the **Test** button to verify the connection

### Microsoft Teams / Power Automate

1. Create a Power Automate workflow with HTTP trigger
2. Copy the webhook URL
3. Add the URL to a Notification Group
4. Use the **Test** button to verify the connection

---

## 🏗️ Architecture

GitPilot follows a clean, modular architecture inspired by **MVVM** and **Clean Architecture** principles:

```
GitPilot/
├── App/                          # Application entry point
│   ├── GitPilotApp.swift         # @main app struct, Scene configuration
│   └── AppState.swift            # Global app state (ObservableObject)
│
├── Models/                       # SwiftData models (entities)
│   ├── WatchedRepository.swift   # Repository configuration
│   ├── TriggerRule.swift         # Trigger definitions
│   ├── BuildLog.swift            # Build execution history
│   ├── CheckLog.swift            # Monitoring check history
│   ├── NotificationGroup.swift   # Notification group settings
│   └── AppSettings.swift         # User preferences
│
├── Services/                     # Business logic layer
│   ├── GitService.swift          # Git operations (fetch, check commits)
│   ├── GitMonitorService.swift   # Timer-based monitoring coordinator
│   ├── CommandRunnerService.swift# Shell command execution
│   ├── NotificationService.swift # Native macOS notifications
│   ├── TelegramService.swift     # Telegram Bot API integration
│   ├── TeamsService.swift        # MS Teams / Power Automate
│   ├── ExportImportService.swift # JSON export/import
│   └── LocalizationManager.swift # i18n management
│
├── Views/                        # SwiftUI views (UI layer)
│   ├── MainWindowView.swift      # Main application window
│   ├── MenuBar/                  # Menu bar components
│   ├── Repositories/             # Repository management views
│   ├── Groups/                   # Notification group views
│   ├── Logs/                     # Build history views
│   └── Settings/                 # Settings views
│
└── Utils/                        # Helper utilities
    └── Shell.swift               # Shell command helpers
```

### Key Technologies

- **SwiftUI** - Declarative UI framework
- **SwiftData** - Modern persistence framework  
- **Combine** - Reactive programming for state management
- **Foundation** - URLSession for network requests
- **AppKit** - Menu bar integration, file dialogs

---

## 🌍 Internationalization (i18n)

GitPilot is fully translated. Change language in **Settings → Data → Language**.

| Language | Status |
|----------|--------|
| 🇧🇷 Portuguese (Brazil) | ✅ Complete |
| 🇺🇸 English | ✅ Complete |
| 🇪🇸 Spanish | ✅ Complete |

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Made with ❤️ by [Megamil](mailto:eduardo@megamil.com.br)**

*If this project helped you, consider giving it a ⭐!*

</div>
