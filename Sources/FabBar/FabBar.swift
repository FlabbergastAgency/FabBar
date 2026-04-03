import SwiftUI

/// A customizable iOS 26 glass tab bar with a floating action button.
///
/// FabBar provides a native-looking iOS 26 tab bar where you control what goes in it,
/// including a FAB that morphs with the glass effect.
///
/// ## Usage
///
/// The recommended way to use FabBar is with the `.fabBar()` modifier:
///
/// ```swift
/// TabView(selection: $selectedTab) {
///     Tab(value: .home) {
///         HomeView()
///             .fabBarSafeAreaPadding()
///             .toolbarVisibility(.hidden, for: .tabBar)
///     }
///     // more tabs...
/// }
/// .fabBar(
///     selection: $selectedTab,
///     tabs: [
///         FabBarTab(value: .home, title: "Home", systemImage: "house.fill"),
///         FabBarTab(value: .explore, title: "Explore", systemImage: "compass"),
///         FabBarTab(value: .profile, title: "Profile", systemImage: "person.fill"),
///     ],
///     action: FabBarAction(systemImage: "plus", accessibilityLabel: "Add Item") {
///         // Handle tap
///     }
///     appearance: .init(colors: .init(
///         fabBackgroundTint: .systemBlue,
///         fabIconTint: .white,
///         tabItemTint: .label,
///         segmentIndicatorTint: UIColor.label.withAlphaComponent(0.12)
///     ))
/// )
/// ```
///
/// For more control over positioning, you can use the `FabBar` view directly.

@available(iOS 26.0, *)
public struct FabBar<Value: Hashable>: View {
    /// The currently selected tab.
    @Binding public var selection: Value

    /// The tabs to display.
    public let tabs: [FabBarTab<Value>]

    /// The floating action button configuration.
    public var action: FabBarAction?

    /// Optional appearance override applied when this FabBar appears.
    public var appearance: FabBarAppearance

    /// Creates a FabBar with the specified configuration.
    ///
    /// - Parameters:
    ///   - selection: A binding to the currently selected tab.
    ///   - tabs: The tabs to display.
    ///   - action: The floating action button configuration.
    ///   - colors: Optional appearance override applied when the FabBar appears.
    public init(
        selection: Binding<Value>,
        tabs: [FabBarTab<Value>],
        action: FabBarAction?,
        appearance: FabBarAppearance = .default
    ) {
        self._selection = selection
        self.tabs = tabs
        self.action = action
        self.appearance = appearance
    }

    public var body: some View {
        if tabs.isEmpty {
            Color.clear
                .frame(height: Constants.barHeight)
                .onAppear {
                    fabBarLogger.warning("FabBar initialized with empty tabs array - nothing will be displayed")
                }
        } else {
            FabBarRepresentable(
                tabs: tabs,
                action: action,
                appearance: appearance,
                activeTab: $selection
            )
            .frame(height: Constants.barHeight)
        }
    }
}
