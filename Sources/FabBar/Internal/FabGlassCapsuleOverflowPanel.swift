import UIKit

@available(iOS 26.0, *) @MainActor
enum FabGlassCapsuleOverflowPanel {

    struct Session {
        let dimmingView: UIView
        let stackContainer: UIView
        let stackView: UIStackView
        let stackWidthConstraint: NSLayoutConstraint
    }

    static let rowSpacing: CGFloat = 8
    static let capsuleHorizontalPadding: CGFloat = 14
    static let capsuleVerticalPadding: CGFloat = 10
    static let gapAboveFab: CGFloat = 10

    private static func emergenceTransform(capsule: FabOverflowCapsuleContainerView, anchorView: UIView) -> CGAffineTransform {
        let anchorLocal = capsule.convert(CGPoint(x: anchorView.bounds.midX, y: anchorView.bounds.midY), from: anchorView)
        let centerLocal = CGPoint(x: capsule.bounds.midX, y: capsule.bounds.midY)
        let dx = (anchorLocal.x - centerLocal.x) * 0.92
        let dy = (anchorLocal.y - centerLocal.y) * 0.92
        return CGAffineTransform(translationX: dx, y: dy).scaledBy(x: 0.26, y: 0.26)
    }

    static func prepareCellsEmerging(stackView: UIStackView, anchorView: UIView) {
        stackView.layoutIfNeeded()
        for cell in stackView.arrangedSubviews {
            guard let capsule = cell as? FabOverflowCapsuleContainerView else { continue }
            let emergence = emergenceTransform(capsule: capsule, anchorView: anchorView)
            capsule.emergenceTransform = emergence
            capsule.contentWrapper.alpha = 0
            capsule.contentWrapper.transform = emergence
            capsule.alpha = 1
            capsule.layer.allowsEdgeAntialiasing = true
        }
    }

    static func refreshEmergenceTransformsForDismiss(stackView: UIStackView, anchorView: UIView) {
        stackView.layoutIfNeeded()
        for cell in stackView.arrangedSubviews {
            guard let capsule = cell as? FabOverflowCapsuleContainerView else { continue }
            capsule.emergenceTransform = emergenceTransform(capsule: capsule, anchorView: anchorView)
        }
    }

    static func makeSession(
        actions: [FabBarAction],
        appearance: FabBarAppearance,
        onSelect: @escaping (FabBarAction) -> Void,
        onDismissRequest: @escaping () -> Void
    ) -> Session {
        let dim = FabOverflowDimmingControl(onDismiss: onDismissRequest)
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        dim.isAccessibilityElement = false

        let stackContainer = UIView()
        stackContainer.clipsToBounds = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = rowSpacing
        stack.alignment = .trailing
        stack.distribution = .equalSpacing

        for action in actions {
            stack.addArrangedSubview(
                capsuleView(for: action, appearance: appearance) {
                    onSelect(action)
                }
            )
        }

        stack.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.addSubview(stack)

        let widthConstraint = stack.widthAnchor.constraint(equalToConstant: 200)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: stackContainer.topAnchor),
            stack.trailingAnchor.constraint(equalTo: stackContainer.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: stackContainer.bottomAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: stackContainer.leadingAnchor),
            widthConstraint,
        ])

        return Session(
            dimmingView: dim,
            stackContainer: stackContainer,
            stackView: stack,
            stackWidthConstraint: widthConstraint
        )
    }

    private static func capsuleView(
        for action: FabBarAction,
        appearance: FabBarAppearance,
        onActivate: @escaping () -> Void
    ) -> UIView {
        let container = FabOverflowCapsuleContainerView()

        let effect = UIGlassEffect()
        effect.isInteractive = true
        effect.tintColor = appearance.colors.fabBackgroundTint

        let wrap = UIVisualEffectView(effect: effect)
        wrap.clipsToBounds = true

        var cfg = UIButton.Configuration.plain()
        cfg.title = action.accessibilityLabel
        cfg.image = UIImage(systemName: action.systemImage)
        cfg.imagePlacement = .leading
        cfg.imagePadding = 10
        cfg.contentInsets = NSDirectionalEdgeInsets(
            top: capsuleVerticalPadding,
            leading: capsuleHorizontalPadding,
            bottom: capsuleVerticalPadding,
            trailing: capsuleHorizontalPadding
        )
        cfg.baseForegroundColor = appearance.colors.fabIconTint
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 15, weight: .semibold)
            return out
        }

        let button = UIButton(configuration: cfg)
        button.tintColor = appearance.colors.fabIconTint
        button.addAction(UIAction { _ in onActivate() }, for: .touchUpInside)

        wrap.contentView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: wrap.contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: wrap.contentView.trailingAnchor),
            button.topAnchor.constraint(equalTo: wrap.contentView.topAnchor),
            button.bottomAnchor.constraint(equalTo: wrap.contentView.bottomAnchor),
        ])

        wrap.translatesAutoresizingMaskIntoConstraints = false
        container.contentWrapper.addSubview(wrap)
        container.glassEffectView = wrap
        NSLayoutConstraint.activate([
            wrap.leadingAnchor.constraint(equalTo: container.contentWrapper.leadingAnchor),
            wrap.trailingAnchor.constraint(equalTo: container.contentWrapper.trailingAnchor),
            wrap.topAnchor.constraint(equalTo: container.contentWrapper.topAnchor),
            wrap.bottomAnchor.constraint(equalTo: container.contentWrapper.bottomAnchor),
        ])

        return container
    }

    static func layout(
        session: Session,
        anchorView: UIView,
        in window: UIWindow
    ) {
        let fabFrame = anchorView.convert(anchorView.bounds, to: window)
        let barTop = fabFrame.minY

        session.dimmingView.frame = CGRect(
            x: 0,
            y: 0,
            width: window.bounds.width,
            height: max(0, barTop)
        )

        let targetWidth = min(window.bounds.width - 24, 340)
        let widthLimit = targetWidth
        var widestRow: CGFloat = 0
        for cell in session.stackView.arrangedSubviews {
            guard let container = cell as? FabOverflowCapsuleContainerView else { continue }
            let rowSize = container.systemLayoutSizeFitting(
                CGSize(width: widthLimit, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .fittingSizeLevel,
                verticalFittingPriority: .fittingSizeLevel
            )
            widestRow = max(widestRow, rowSize.width)
        }
        let width = min(max(widestRow, 44), widthLimit)
        session.stackWidthConstraint.constant = width

        session.stackContainer.layoutIfNeeded()
        let height = session.stackView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        var y = fabFrame.minY - gapAboveFab - height
        let minY = window.safeAreaInsets.top + 6
        if y < minY {
            y = minY
        }

        let x = fabFrame.maxX - width
        session.stackContainer.frame = CGRect(x: x, y: y, width: width, height: height)
        session.stackContainer.layoutIfNeeded()

        applyCapsuleCorners(stackView: session.stackView)
    }

    static func applyCapsuleCorners(stackView: UIStackView) {
        stackView.layoutIfNeeded()
        for cell in stackView.arrangedSubviews {
            guard let capsule = cell as? FabOverflowCapsuleContainerView else { continue }
            guard let effect = capsule.glassEffectView else { continue }
            if #available(iOS 26.0, *) {
                effect.cornerConfiguration = .capsule()
            } else {
                let r = max(8, min(effect.bounds.width, effect.bounds.height) * 0.5)
                effect.layer.cornerRadius = r
                effect.contentView.layer.cornerRadius = r
                effect.layer.masksToBounds = true
            }
        }
    }
}

@available(iOS 26.0, *)
final class FabOverflowCapsuleContainerView: UIView {

    let contentWrapper = UIView()
    weak var glassEffectView: UIVisualEffectView?
    var emergenceTransform = CGAffineTransform.identity

    init() {
        super.init(frame: .zero)
        clipsToBounds = false
        addSubview(contentWrapper)
        contentWrapper.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentWrapper.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentWrapper.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentWrapper.topAnchor.constraint(equalTo: topAnchor),
            contentWrapper.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        contentWrapper.clipsToBounds = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@available(iOS 26.0, *)
private final class FabOverflowDimmingControl: UIControl {
    private let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        super.init(frame: .zero)
        addTarget(self, action: #selector(fire), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func fire() {
        onDismiss()
    }
}
