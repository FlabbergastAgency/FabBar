import SwiftUI

/// View modifier that positions a FabBar at the bottom of the view.
///
/// This modifier handles all the layout details:
/// - Wraps in `.safeAreaBar(edge: .bottom)`
/// - Applies appropriate padding
/// - Ignores bottom safe area for manual positioning
/// - Hides automatically on regular horizontal size class (iPad)
/// - Injects calculated safe area padding into the environment
@available(iOS 26.0, *)
struct FabBarModifier<Value: Hashable>: ViewModifier {
    @Binding var selection: Value
    let tabs: [FabBarTab<Value>]
    let actions: [FabBarAction]
    let appearance: FabBarAppearance
    let isVisible: Bool

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var bottomSafeAreaInset: CGFloat = 0

    /// Whether the FabBar should be displayed.
    /// Only shows on compact horizontal size class (iPhone) when visible.
    private var showsFabBar: Bool {
        horizontalSizeClass == .compact && isVisible
    }

    /// Total content margin needed to clear the FabBar.
    private var bottomContentMargin: CGFloat {
        Constants.barHeight + Constants.bottomPadding
    }

    /// The padding to inject into the environment.
    /// This is the total content margin minus the device's safe area inset,
    /// because `safeAreaPadding` adds to the existing safe area.
    /// Returns 0 when the FabBar is not showing.
    private var calculatedPadding: CGFloat {
        showsFabBar ? bottomContentMargin - bottomSafeAreaInset : 0
    }

    func body(content: Content) -> some View {
        content
            .safeAreaBar(edge: .bottom) {
                if showsFabBar {
                    FabBar(selection: $selection, tabs: tabs, actions: actions, appearance: appearance)
                        .padding(.horizontal, Constants.horizontalPadding)
                        .padding(.bottom, Constants.bottomPadding)
                }
            }
            .ignoresSafeArea(.all, edges: showsFabBar ? [.bottom] : [])
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.safeAreaInsets.bottom
            } action: { newValue in
                bottomSafeAreaInset = newValue
            }
            .environment(\.fabBarBottomSafeAreaPadding, calculatedPadding)
    }
}

@available(iOS 26.0, *)
public extension View {
    /// Adds a FabBar to the bottom of the view.
    ///
    /// This is the recommended way to use FabBar. It handles positioning,
    /// safe area management, and automatically hides on iPad.
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
    /// .fabBar(selection: $selectedTab, tabs: tabs, actions: actions)
    /// ```
    ///
    /// - Parameters:
    ///   - selection: A binding to the currently selected tab.
    ///   - tabs: The tabs to display.
    ///   - actions: FAB actions (empty hides the +; one tap; multiple opens a menu from +).
    ///   - appearance: Styling (FAB + content tint for light/dark).
    ///   - isVisible: Whether the FabBar is visible. Defaults to `true`.
    func fabBar<Value: Hashable>(
        selection: Binding<Value>,
        tabs: [FabBarTab<Value>],
        actions: [FabBarAction] = [],
        appearance: FabBarAppearance = .default,
        isVisible: Bool = true
    ) -> some View {
        modifier(FabBarModifier(selection: selection, tabs: tabs, actions: actions, appearance: appearance, isVisible: isVisible))
    }

    /// Single FAB action or none (nil hides the + control).
    func fabBar<Value: Hashable>(
        selection: Binding<Value>,
        tabs: [FabBarTab<Value>],
        action: FabBarAction?,
        appearance: FabBarAppearance = .default,
        isVisible: Bool = true
    ) -> some View {
        fabBar(selection: selection, tabs: tabs, actions: action.map { [$0] } ?? [], appearance: appearance, isVisible: isVisible)
    }
}
