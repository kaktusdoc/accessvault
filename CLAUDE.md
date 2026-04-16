# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # install dependencies
flutter run -d windows   # run on Windows desktop
flutter build windows    # build release for Windows
flutter test             # run all tests
flutter test test/widget_test.dart  # run a single test file
flutter analyze          # lint/static analysis
```

## Architecture

**App entry point:** `lib/main.dart` — sets up `MaterialApp` with a global dark theme (seed color `0xFF1565C0`, scaffold background `0xFF121212`) and launches `PinScreen` as `home`.

**Auth flow:** `PinScreen` (`lib/screens/pin_screen.dart`) is always the first widget. On init it calls `PinService.hasPin()` and switches between three modes via `_PinMode` enum:
- `set` → `confirm` (two-step PIN creation for new users)
- `verify` (PIN entry for returning users)

On success it does a `pushReplacement` to `DocumentListScreen`.

**Secure storage:** `lib/services/pin_service.dart` wraps `flutter_secure_storage` with `WindowsOptions()` for Windows compatibility. The PIN is stored under the key `accessvault_pin`. All methods are static.

**Document list:** `lib/screens/document_list_screen.dart` currently uses hardcoded placeholder `Document` objects. The app bar has a refresh icon and a settings gear icon (settings navigation is a `TODO`). A FAB exists for future document upload.

**Data model:** `lib/models/document.dart` — `Document` has `name`, `type` (`DocumentType` enum), and `date`. The `DocumentTypeDisplay` extension on `DocumentType` provides `label`, `icon`, and `color` for each type (pdf, image, word, spreadsheet, generic).

**Document tile:** `lib/widgets/document_tile.dart` — stateless, renders icon in a colored rounded square, relative date formatting.

## Key dependency

`flutter_secure_storage: ^9.2.2` — requires no extra Windows configuration beyond passing `WindowsOptions()` to the constructor (already done in `PinService`).
