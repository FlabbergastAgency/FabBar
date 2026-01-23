# FabBar

A customizable iOS 26 glass tab bar with a floating action button.

## Why FabBar?

Many apps have a primary action that users perform frequently: composing a social media post, logging a meal, creating a task. Placing this action at the bottom of the screen keeps it in the thumb zone and always visible, reducing friction for the most common user flow.

With iOS 26's tab bar, developers can disguise the search tab as a primary action, but this approach has issues:

- VoiceOver reads it as a tab, not a button
- Requires intercepting tab changes and undoing them, which is brittle and prone to subtle bugs
- Not customizable and not clearly distinguishable from the other tabs

Traditional floating action buttons are also awkward with iOS 26's centered tab bar. With fewer than four tabs, there's negative space on either side of the bar, and placing a FAB on the trailing edge creates unbalanced empty space below it.

FabBar provides one solution: recreate the tab bar entirely for full control.

## How It Works

The key challenge in recreating the tab bar is the interactive glass effect on touch down and drag. This effect is only available to tab bars and one other component: segmented controls. FabBar uses a segmented control as its foundation, hiding the default labels and overlaying custom tab item views.

Why UIKit instead of pure SwiftUI? Layering SwiftUI views on the native segmented control's interactive glass effect causes framerate issues during touch interactions. Only noticeable to keen observers, but noticeable.

This approach requires manipulating view hierarchies, which could be brittle across OS updates. See Known Limitations below for other tradeoffs.

Credit to [Kavsoft](https://youtu.be/wfHIe8GpKAU?si=ASViL-OuhqQwEWzr) for the original idea of using a segmented control to imitate a tab bar.

## Requirements

- iOS 26.0+
- Swift 6.0+

## Installation

Add FabBar as a Swift Package dependency:

```swift
dependencies: [
    .package(url: "https://github.com/ryanashcraft/FabBar.git", from: "1.0.0")
]
```

## Usage

```swift
import FabBar

enum AppTab: Hashable {
    case home, explore, profile
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        VStack {
            // Your tab content here
            switch selectedTab {
            case .home:
                HomeView()
            case .explore:
                ExploreView()
            case .profile:
                ProfileView()
            }

            FabBar(
                selection: $selectedTab,
                items: [
                    FabBarItem(tab: .home, title: "Home", systemImage: "house.fill"),
                    FabBarItem(tab: .explore, title: "Explore", systemImage: "compass"),
                    FabBarItem(tab: .profile, title: "Profile", systemImage: "person.fill"),
                ],
                action: FabAction(
                    systemImage: "plus",
                    accessibilityLabel: "Add Item"
                ) {
                    // Handle FAB tap
                }
            )
            .padding(.horizontal, 21)
            .padding(.bottom, 21)
        }
    }
}
```

### Custom Images

Use custom images from your asset catalog instead of SF Symbols:

```swift
FabBarItem(
    tab: .library,
    title: "Library",
    image: "custom.library.icon",
    imageBundle: .main
)
```

### Tab Reselection

Handle when users tap an already-selected tab (useful for scroll-to-top):

```swift
FabBar(
    selection: $selectedTab,
    items: items,
    onReselect: { tab in
        // User tapped the already-selected tab
        scrollToTop()
    }
)
```

### Layout Considerations

FabBar doesn't dictate how you position it in your layout. Common patterns include:

- **Bottom padding**: Add padding below the bar to clear the home indicator (typically 21 points)
- **Content insets**: Add bottom content margins to scroll views so content clears the tab bar
- **Safe area handling**: Use `.ignoresSafeArea(.container, edges: .bottom)` when placing FabBar at the bottom

## Known Limitations

**Color clipping during drag:** The native iOS 26 tab bar uses the glass bubble as a real-time clipping mask. Icon and text show the active tint inside the bubble and inactive tint outside, even mid-drag. FabBar highlights tabs fully when the bubble moves over them rather than clipping. Most noticeable during slow drags between tabs.

**Accessibility large text mode:** Native tab bars show a full-screen overlay on touch down when using accessibility text sizes. FabBar uses a segmented control internally, which shows a popover instead.

## License

MIT License. See [LICENSE](LICENSE) for details.
