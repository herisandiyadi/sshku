# SSHKU

Mobile SSH client built with Flutter. Manage servers, connect via terminal, and execute commands — all from your phone.

## Features

### 🖥️ Terminal
- Full interactive SSH terminal with ANSI color support
- Scrollback history (up to 1000 lines)
- Text selection via long press + drag (auto-copy to clipboard)
- Paste from clipboard with double tap
- Keyboard toggle button in AppBar
- Custom keyboard bar with Ctrl modifier and special keys (Tab, Esc, arrows)
- Auto-reconnect on disconnect (up to 3 retries)
- Resizable PTY (auto-adapts to screen size)

### 🗄️ Server Management
- Add, edit, and delete SSH connections
- Group servers by category with color-coded labels
- Filter servers by group
- Test connection before saving
- Support password and SSH key authentication

### 🔑 SSH Keys
- Generate RSA and Ed25519 key pairs on-device
- Encrypted private key storage (Android Keystore)
- Assign keys to specific connections
- View and copy public keys

### ⚡ Quick Commands (Snippets)
- Save frequently used commands
- Organize in folders with custom sort order
- One-tap execution during terminal session

### 📜 Command History
- Auto-logs every command executed
- Search through history
- Re-execute past commands

### 🔒 Security
- App lock with PIN (4-6 digits)
- Private keys encrypted via Android Keystore
- Host key verification (TOFU model)
- Known hosts database

### 💾 Backup & Restore
- Export entire database to JSON (servers, keys, snippets, history, known hosts)
- Import backup from file
- Accessible from dashboard menu and settings

### 🎨 Appearance
- Dark / Light / System theme
- Adjustable terminal font size

## Tech Stack

- **Framework:** Flutter (Dart)
- **Architecture:** Clean Architecture + BLoC/Cubit
- **SSH:** dartssh2 (pure Dart SSH implementation)
- **Storage:** SQLite (sqflite)
- **DI:** get_it + injectable
- **State:** flutter_bloc

## Getting Started

```bash
# Clone
git clone https://github.com/sshku/sshku.git
cd sshku

# Install dependencies
flutter pub get

# Run
flutter run
```

## Requirements

- Flutter SDK ≥ 3.9.0
- Android 5.0+ (API 21+)

## License

MIT
