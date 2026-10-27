# Library and component decisions

The client remains SwiftUI-native with no third-party runtime packages. This keeps the offline MVP usable without a network-dependent package resolution step.

| Suggested project | Decision for this MVP |
| --- | --- |
| [SwiftLint](https://github.com/realm/SwiftLint) | Added `.swiftlint.yml` and a macOS CI step. Focused correctness rules prevent forced casts/tries and catch basic source mistakes. |
| [Defaults](https://github.com/sindresorhus/Defaults) | Reviewed its typed settings API. The app currently has one workspace preference, handled by `@AppStorage`; full financial records belong in SwiftData. |
| [InAppSettingsKit](https://github.com/futuretap/InAppSettingsKit) | The supplied link label said Defaults but targeted this project. Reviewed its settings-bundle approach; native SwiftUI settings fit this app. |
| [Alamofire](https://github.com/Alamofire/Alamofire) | No live network feature in the MVP. Future adapters already use URLSession. |
| [RxSwift](https://github.com/ReactiveX/RxSwift) | Observation and SwiftUI state already manage the app's data flow. |
| [Lottie](https://github.com/airbnb/lottie-ios) | No Lottie asset was supplied; native feedback and progress indicators suit the core finance tasks. |
| [SnapKit](https://github.com/SnapKit/SnapKit), [Hero](https://github.com/HeroTransitions/Hero), [MJRefresh](https://github.com/CoderMJLee/MJRefresh), [animated-tab-bar](https://github.com/Ramotion/animated-tab-bar), [FlatUIKit](https://github.com/Grouper/FlatUIKit) | These primarily address UIKit layout, controls or transitions; the app uses native SwiftUI equivalents. |
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | Reviewed. No sign-in credentials are needed for the offline MVP. The future session adapter already uses Apple's Keychain directly. |

No source or artwork from these projects has been copied into the app. Adding SwiftLint as a developer tool does not bundle it in the app.

## EasyUI

The requested https://easyui.site/components page returned an environment proxy 403. Its components and license have not been inspected or copied. The required EasyUI domains were added to the environment configuration draft; runtime access requires the settings change to be applied. Native cards, forms, summaries and navigation currently follow the supplied archive's design. Do not attribute them to EasyUI.

## Dollarwise reference

The requested competitor research is incomplete: general web search and App Store lookup are blocked by the environment proxy, and the exact Dollarwise product URL has not been verified. No Dollarwise screenshots, assets, source code or branding have been copied. Nest’s dashboard is an original implementation: a plum gradient balance card, warm background, pastel account tiles, native budget progress and compact recent activity.
