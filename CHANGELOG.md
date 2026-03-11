# Changelog

## [0.2] - 2026-03-10

### Added
- **Recent Notifications tab**: View recent notifications and double-click to create rules from them
- **Hide options**: New style settings to hide icon, title, or text in custom notifications
- **Preferences in Dock**: Preferences window now appears in Dock for easier Cmd+Tab switching
- **Redesigned menu**: Cleaner menu bar layout with Start/Stop at top, version info, and Check for Updates

### Fixed
- Duplicate notifications no longer appear in Recent tab (improved deduplication)
- Styles and rules now load correctly after app updates (backwards-compatible data format)
- Resource cleanup on app termination

### Changed
- Default border width for new styles is now 1 pixel (was 0)
- Standardized font sizes across all preference panes
- Improved About window with clickable GitHub and contact links

### Security
- Added path validation for custom icon and background image files
- Fixed unsafe type casts in accessibility code

## [0.1] - 2026-03-09

Initial release.

- Reposition system notifications to any corner or center of the screen
- Create custom notification styles with control over size, colors, position, opacity, display duration, icons, background images, and animations
- Rule-based matching by app name or keywords in title/body
- Option to replace system notifications entirely with custom versions
- Export/import settings for backup or sharing across machines
- Menu bar interface with optional CLI mode
