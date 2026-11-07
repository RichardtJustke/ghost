# Roadmap

Planned improvements that were left out of 2.9.0. Each one should land on its own and be tested in the running shell.

## Lighter

- **Performance profiles.** Turn `general.performance` into Light / Normal / Full, where Light also turns off shaders, cava and heavy animations.
- **Fonts on demand.** 62 MB of Nerd Fonts still ship in `src/assets/fonts`. Ship about five and let the theme tab download the rest.
- **Lazy singletons.** `PauseReminder` and `MonitorRestore` are touched in `Shell.qml` only so their timers start; move that work to where it is needed.

## Easier to maintain

- **Split the largest QML files.** `guide/bar/BarModulesTab.qml` (~3.5k lines) first, then `dock/Dock.qml`, `guide/wellbeing/DigitalWellbeingTab.qml` and `media/MusicPopup.qml`. Splitting `BarModulesTab` also paves the way for bar module plugins.

## More useful

- **Bar module plugins.** Load extra modules from `~/.config/ghost/modules/*.qml`.
- **Launcher plugins.** Calculator, unit conversion, recent files, shell commands and open windows.
- **Settings hot reload.** Validate `settings.json` against a schema, apply changes without restarting and report errors as a notification.
- **Do not disturb and notification history**, with per-app rules.
- **Bluetooth.** Reconnect the last used headphones automatically when they turn on.

## Dictation follow-ups

- Translate the dictation strings in `dictation/Dictation.qml` and `scripts/dictation.sh` through I18n.
- Optional local transcription with whisper.cpp for offline use.
