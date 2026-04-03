import UIKit

@available(iOS 26.0, *)
public struct FabBarAppearance: Sendable {
    /// Colors used by FabBar's UIKit-backed rendering.
    public struct Colors: Sendable {
        /// Background tint applied to the floating action button container.
        public var fabBackgroundTint: UIColor

        /// Icon tint color for the floating action button.
        public var fabIconTint: UIColor

        /// Tint applied to tab icons/labels.
        public var tabItemTint: UIColor

        /// Tint applied to the segment selection indicator.
        public var segmentIndicatorTint: UIColor

        public init(
            fabBackgroundTint: UIColor,
            fabIconTint: UIColor,
            tabItemTint: UIColor,
            segmentIndicatorTint: UIColor
        ) {
            self.fabBackgroundTint = fabBackgroundTint
            self.fabIconTint = fabIconTint
            self.tabItemTint = tabItemTint
            self.segmentIndicatorTint = segmentIndicatorTint
        }
    }

    public var colors: Colors

    public init(colors: Colors) {
        self.colors = colors
    }

    public static var `default`: FabBarAppearance {
        FabBarAppearance(
            colors: Colors(
                fabBackgroundTint: .systemBlue,
                fabIconTint: .white,
                tabItemTint: .label,
                segmentIndicatorTint: UIColor.label.withAlphaComponent(0.12)
            )
        )
    }
}
