# Hottoshita

A daily wellness check-in app for elderly users, for iPad and iPhone. After answering a short series of guided questions, the app generates a readable report and pre-fills an email to a trusted contact. Fully localized in English and Japanese.

*Hottoshita (ほっとした) — Japanese for "relieved".*

## What it does

Every day, the user taps **Start Today's Check-in** and answers three simple questions, one per screen:

1. **Sleep** — How was your sleep? (Slept deeply / Slept OK / Barely slept / Didn't sleep)
2. **Feeling** — How are you feeling now? (multi-select: Good, Tired, Dizzy, Heavy, Anxious, Happy, Sad, Calm)
3. **Blood pressure** — optional systolic/diastolic entry

A summary screen lets them review their answers, then **Send Report** opens the iOS Mail compose sheet pre-filled with a localized report addressed to their trusted contact. Check-ins are also saved locally and browsable in a History screen.

All data stays on-device — nothing is sent to any server. The only way information leaves the device is the user's own outgoing email. See [PRIVACY.md](PRIVACY.md) for the full privacy policy (English + Japanese).

## Designed for elderly users

- Large text everywhere, with full Dynamic Type support
- Generous touch targets and big, labelled buttons
- Minimal navigation: a guided, linear one-question-per-screen flow
- Personalised time-aware greeting on the Home screen
- 7 pastel colour themes (with dark-mode variants), chosen during onboarding
- Optional daily reminder via local notification
- "Choose from Contacts" uses the out-of-process `CNContactPickerViewController`, so no permission prompt ever appears

## Tech stack

| | |
|---|---|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Email | MessageUI (`MFMailComposeViewController`) |
| Contacts | ContactsUI (`CNContactPickerViewController`) |
| Storage | `@AppStorage`/UserDefaults (settings), JSON file in Documents (history) |
| Localization | `Localizable.strings` (en, ja) |
| Project generation | [xcodegen](https://github.com/yonaskolb/XcodeGen) |
| Minimum deployment | iOS 16, universal (iPhone + iPad) |

## Project structure

```
Hottoshita/
├── project.yml                        # xcodegen config
├── PLAN.md                            # detailed design & task plan
├── Sources/Hottoshita/
│   ├── HottoshitaApp.swift            # app entry point; test launch args
│   ├── en.lproj/ ja.lproj/            # localized strings
│   ├── Models/
│   │   ├── CheckInAnswers.swift       # SleepRating, BloodPressure, feelings
│   │   ├── CheckInStore.swift         # JSON persistence + submittedToday
│   │   └── AppTheme.swift             # colour themes
│   ├── Views/
│   │   ├── RootView.swift             # routes to Onboarding or Home
│   │   ├── OnboardingView.swift       # 5-step first-launch setup
│   │   ├── HomeView.swift
│   │   ├── CheckInFlowView.swift      # one-question-per-screen flow
│   │   ├── SummaryView.swift
│   │   ├── HistoryView.swift
│   │   └── SettingsView.swift
│   └── Utilities/
│       ├── ReportGenerator.swift      # localized email subject + body
│       ├── MailComposeView.swift      # MFMailComposeViewController wrapper
│       ├── ContactPickerView.swift    # CNContactPickerViewController wrapper
│       └── ReminderScheduler.swift    # daily local notification
└── Tests/
    ├── HottoshitaTests/               # unit tests (store, report, BP)
    └── HottoshitaUITests/             # onboarding, check-in flow, home
```

## Building

The Xcode project is generated with xcodegen:

```sh
brew install xcodegen   # if needed
xcodegen generate
open Hottoshita.xcodeproj
```

Then build and run the `Hottoshita` scheme on an iOS 16+ simulator or device.

## Testing

Run unit and UI tests from Xcode (⌘U) or the command line:

```sh
xcodebuild test -project Hottoshita.xcodeproj -scheme Hottoshita \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Debug-only launch arguments used by the test suites (and handy for manual testing):

- `--reset-for-testing` — wipes UserDefaults and saved check-in history
- `--skip-onboarding` — pre-fills user/contact settings so the app opens on Home
- `--debug-contact-picker` — jumps straight to the onboarding contact step and opens the contact picker

Note: the contact picker may render blank on some simulators (a known limitation of out-of-process pickers); verify it on a real device.

## Localization

All user-facing strings — including the generated email report — are localized in English and Japanese via `en.lproj`/`ja.lproj`. Switch the device or simulator language to Japanese to test.

## Status

Feature-complete for v1. See [PLAN.md](PLAN.md) for the full design document, remaining polish items, and the App Store publishing checklist.
