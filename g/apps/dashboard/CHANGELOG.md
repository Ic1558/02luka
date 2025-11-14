# Dashboard Changelog

## [2.1.0] - 2025-01-05

### Phase 3: WO Detail Drawer Enhancement

#### ✨ Features Added

**1. Tabbed Drawer Interface**
- Added 4-tab system to organize work order details:
  - 📋 **Summary**: Basic information, timestamps, and file paths
  - 📥 **I-O**: Standard output and error streams
  - 📜 **Logs**: Log tail (last 100 lines)
  - ⚡ **Actions**: Interactive action buttons

**2. Auto-Select on MLS Card Click**
- Clicking MLS cards (Total/Solutions/Failures) now:
  - Scrolls smoothly to Work Order History section
  - Auto-selects first work order if any exist
  - Opens drawer automatically with selected WO

**3. Enhanced Empty States**
- Redesigned empty state messages with:
  - Large emoji icons for visual appeal
  - Clear titles and explanations
  - Helpful hints for next actions
  - Context-specific messaging per filter type

**4. Action Buttons**
- **Retry Button**: Creates new idempotent work order with same parameters
- **Cancel Button**: Sends cancellation signal (if supported by WO type)
- **Tail Button**: Prepares for live log streaming viewer
- All buttons include confirmation dialogs and helpful descriptions

#### 🎨 UI Improvements

- **Tab System**: Clean, modern tab interface with active state highlighting
- **Action Buttons**: Color-coded buttons with hover effects and descriptions
- **Smooth Scrolling**: Animated scroll to Work Order History section
- **Better Organization**: Content separated into logical, easy-to-navigate tabs

#### 🔧 Technical Changes

- Added `renderSummaryTab()`, `renderIOTab()`, `renderLogsTab()`, `renderActionsTab()` functions
- Implemented tab switching logic with event delegation
- Added action handlers: `retryWorkOrder()`, `cancelWorkOrder()`, `tailWorkOrderLog()`
- Updated CSS with `.wo-drawer-tabs`, `.wo-tab`, `.wo-tab-content` styles
- Enhanced MLS card onClick handler with auto-select and scroll logic

#### 📋 Acceptance Criteria Met

- ✅ Drawer opens on WO click from history list
- ✅ Drawer opens on MLS card click (auto-selects first WO)
- ✅ Tabs render correctly (Summary/I-O/Logs/Actions)
- ✅ Tab switching works smoothly
- ✅ Empty states show helpful messages
- ✅ Action buttons render with proper styling
- ✅ Confirmation dialogs work for destructive actions
- ✅ ESC key closes drawer
- ✅ Backdrop click closes drawer
- ✅ Smooth scroll to WO History on MLS click

#### 🚀 Future Enhancements (TODO)

- Implement actual API endpoints for Retry/Cancel actions
- Build live log streaming with SSE or fetch polling
- Add keyboard shortcuts for tab navigation
- Implement WO filtering by MLS category
- Add export functionality for WO details

---

## [2.0.2] - 2025-01-04

### Phase 2: Interactive KPI Cards

#### Features
- Made MLS and Service cards clickable
- Added visual feedback on hover and active states
- URL state management for deep linking
- Keyboard accessibility (Enter/Space)

---

## [2.0.0] - 2025-01-03

### Initial Dashboard Release

#### Features
- Real-time monitoring of work orders
- Service status display
- MLS (Master Learning System) metrics
- Live log streaming
- Auto-refresh every 30 seconds
- Health indicator

---

## Version Format

Format: `MAJOR.MINOR.PATCH`
- **MAJOR**: Breaking changes or complete rewrites
- **MINOR**: New features, enhancements
- **PATCH**: Bug fixes, small improvements
