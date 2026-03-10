# NotifyMeHow

A macOS menu bar app that lets you customize how notifications appear on your screen.

## Why?

macOS notifications are easy to miss. They appear briefly in the corner, look the same whether it's a routine update or something urgent, and disappear before you notice them. Apps give you limited control: maybe an option for sounds or banners, but nothing that truly makes important notifications stand out.

NotifyMeHow fixes this. You can create rules that match notifications by app name or keywords, then apply custom styles that make them impossible to miss: larger size, different colors, screen-center positioning, attention-grabbing animations. When you enable "hide system notification," your custom notification completely replaces the default one—giving you full control over how that notification looks and behaves.

**Some examples:**
- Make Slack messages containing "urgent" or your name appear as large, red notifications in the center of your screen
- Keep routine notifications subtle while critical alerts demand attention
- Add pulsing or bouncing animations to notifications that need immediate action

## Features

NotifyMeHow can reposition system notifications to any corner or center of the screen. It also creates custom notification styles where you control position, size (0.5x to 3x scale), colors, opacity, display duration, icons, background images, and animations.

The rule system matches notifications by app name or keywords in the title and body. You can require all keywords to match or just any one of them. When a rule matches, it applies your chosen style—and if you've enabled "hide system notification," the default notification disappears entirely, replaced by your custom version.

Settings can be exported and imported, so you can back up your configuration or share it across machines.

## Installation

### From Source

```bash
git clone https://github.com/yourusername/notifymehow.git
cd notifymehow
./create-app.sh
open NotifyMeHow.app
```

### First Run

Launch the app and it appears as an icon in your menu bar. macOS will prompt you to grant Accessibility permissions. Open **System Settings > Privacy & Security > Accessibility** and enable NotifyMeHow, then click "Start Monitoring" from the menu.

## Usage

### Repositioning Notifications

Select **Reposition To** from the menu to move all system notifications to a different location.

### Creating Custom Styles

Open **Custom Notification Styles** from the menu, go to the **Styles** tab, and click **Add Style**. Configure the appearance to your liking. Enable **Hide system notification** if you want your custom notification to replace the default entirely.

### Setting Up Rules

In the **Rules** tab, click **Add Rule**. Set the app name and/or keywords to match, choose whether any keyword or all keywords must match, and select which style to apply. Rules are evaluated in order—the first match wins.

## Requirements

macOS 26 (Tahoe). Other versions are untested. Accessibility permissions required.

## Command Line

NotifyMeHow also works from the terminal. Run `NotifyMeHow --help` for options, or just launch the app bundle to use the menu bar interface.

## License

MIT
