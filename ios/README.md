# reresearch iPhone design prototype

A native SwiftUI baseline of the existing web app, intended for visual design exploration with Tom and review by Mike. The initial layout preserves the current web header, top tabs, topic chips, feed cards, thread structure, Settings sections, login, welcome, tour, and Privacy page. The web implementation remains the reference.

Open `Reresearch.xcodeproj`, select the shared `reresearch` scheme, and run on an iPhone simulator. The initial deployment target is iOS 18. The project has no external package dependencies and no signing team configured. Routine builds run locally on the Mac; there are no GitHub Actions workflows.

The app uses bundled, fictional research records to exercise the existing product UI. Names, institutions, findings, statistics, model costs, and publication identifiers in these fixtures are sample content, not research claims. Font files are Geist and Geist Mono from Google Fonts, with their SIL Open Font License notices included alongside them.

All interactions are local simulations. Feed filtering, likes, saves, hiding, read state, topic choices, reading levels, provider/model choices, the Settings tour, and thread-version switching are interactive. Some reader state persists in the simulator's local defaults. Fetching, summaries, invitations, key verification, and sign-in do not call any external service. Key forms retain only a last-four-character hint in memory; no provider credential is transmitted or saved.

To inspect otherwise hidden product states, the scheme accepts optional launch arguments:

- `--login`: show the existing sign-in/request-access layout.
- `--welcome`: show the existing welcome dialog above the feed.
- `--empty`: show the native empty-feed state.

These arguments are not visible controls in the product. There are no prototype labels, demo badges, extra app navigation, or preview-only explanatory text in the UI.

For an embedded live preview in Codex, the Build iOS Apps plugin can build/run the project and mirror the selected simulator using its `ios-simulator-browser` workflow. Keep that simulator's `serve-sim` terminal alive while using the mirror. Use only the specific simulator UDID when cleaning up its helper.

Physical-device signing, Apple account configuration, TestFlight, live backend integration, and distribution are later steps. The local bundle identifier `design.reresearch.prototype` is provisional and has not been registered with Apple.
