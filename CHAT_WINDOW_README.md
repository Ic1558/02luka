# Luka Chat Window Feature

This update adds the ability to open the AI chat interface in a separate window, providing better multitasking capabilities and improved user experience.

## New Files

- `chat-window.html` - Standalone chat interface that can be opened in a separate window
- `chat-launcher.html` - Simple launcher page for opening the chat window directly

## Features

### Main Interface (`luka.html`)
- Added "Open Chat Window" button in the header toolbar
- Gateway selection synchronization between main window and chat window
- Automatic focus management when opening existing chat window

### Chat Window (`chat-window.html`)
- Complete chat functionality in a separate window
- Window controls (minimize, close buttons)
- Gateway selection synchronization with main window
- All original chat features preserved (prompt library, message history, etc.)

### Chat Launcher (`chat-launcher.html`)
- Simple launcher page for direct access to chat
- Can be used standalone or as a bookmark
- Auto-open functionality via URL parameter (`?auto=chat`)

## Usage

### From Main Interface
1. Open `luka.html` in your browser
2. Click the "Open Chat Window" button in the header
3. A new window will open with the chat interface
4. Gateway selections are synchronized between windows

### Direct Access
1. Open `chat-launcher.html` for a simple launcher
2. Click "Open Chat Window" to launch the chat interface
3. Or open `chat-window.html` directly

### URL Parameters
- `chat-launcher.html?auto=chat` - Automatically opens the chat window

## Technical Details

### Window Communication
- Uses `postMessage` API for communication between windows
- Gateway selection is synchronized bidirectionally
- Window state is tracked to prevent multiple instances

### Window Features
- Resizable and scrollable
- No toolbar or menubar for clean interface
- Proper window management controls

### Browser Compatibility
- Works in all modern browsers that support `window.open()`
- Requires JavaScript enabled
- Popup blockers may need to be disabled for the launcher

## File Structure

```
/workspaces/02luka-repo/
├── luka.html                 # Main interface (updated)
├── chat-window.html          # Separate chat window
├── chat-launcher.html        # Chat launcher page
└── CHAT_WINDOW_README.md     # This documentation
```

## Integration Notes

- The chat window maintains all original functionality
- Gateway selection is synchronized between main window and chat window
- Window controls allow proper window management
- Communication is handled via the standard `postMessage` API
- No server-side changes required
