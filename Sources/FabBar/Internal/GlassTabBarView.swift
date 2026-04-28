import UIKit

/// The root UIKit view that assembles the tab bar with glass effects.
/// Uses UIGlassContainerEffect to enable morphing between the segmented control and FAB.
@available(iOS 26.0, *)
final class GlassTabBarView: UIView {
    let containerEffectView: UIVisualEffectView
    let segmentedGlassView: UIVisualEffectView
    let segmentedControl: TabBarSegmentedControl
    let fabGlassView: UIVisualEffectView
    private var appearance: FabBarAppearance
    private var fabButton: UIButton?
    private var actions: [FabBarAction]
    private var fabConstraints: [NSLayoutConstraint] = []
    private var fabGlassViewConstraints: [NSLayoutConstraint] = []
    private var segmentedLeadingConstraint: NSLayoutConstraint?
    private var segmentedCenterXConstraint: NSLayoutConstraint?
    private var segmentedHiddenWidthConstraint: NSLayoutConstraint?
    private var actionTransitionID: UInt = 0

    private let spacing: CGFloat = Constants.fabSpacing
    private let contentPadding: CGFloat = Constants.contentPadding

    private(set) var tabCount: Int
    private var segmentedTrailingConstraint: NSLayoutConstraint?

    private var capsuleOverflowSession: FabGlassCapsuleOverflowPanel.Session?

    private enum LegacyPlusButtonMotion {
        static let hiddenTransform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        static let duration: TimeInterval = 0.24
        static let springDamping: CGFloat = 0.9
        static let springVelocity: CGFloat = 0.15
        static let options: UIView.AnimationOptions = [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
    }

    private enum OverflowMotion {
        static let rowDuration: TimeInterval = 0.46
        static let rowDamping: CGFloat = 0.84
        static let rowVelocity: CGFloat = 0.28
        static let stagger: TimeInterval = 0.048
        static let fabRotationDuration: TimeInterval = 0.36
        static let fabRotationDamping: CGFloat = 0.88
        static let fabRotationVelocity: CGFloat = 0.22
    }

    init(
        segmentedControl: TabBarSegmentedControl,
        tabCount: Int,
        actions: [FabBarAction],
        appearance: FabBarAppearance
    ) {
        self.segmentedControl = segmentedControl
        self.tabCount = tabCount
        self.actions = actions
        self.appearance = appearance

        // Create glass container effect for morphing
        let containerEffect = UIGlassContainerEffect()
        containerEffect.spacing = Constants.fabSpacing
        containerEffectView = UIVisualEffectView(effect: containerEffect)

        // Create segmented control glass effect
        let segmentedGlassEffect = UIGlassEffect()
        segmentedGlassEffect.isInteractive = true
        segmentedGlassView = UIVisualEffectView(effect: segmentedGlassEffect)

        // Create FAB button
        let fabGlassEffect = UIGlassEffect()
        fabGlassEffect.isInteractive = true
        fabGlassEffect.tintColor = appearance.colors.fabBackgroundTint
        fabGlassView = UIVisualEffectView(effect: fabGlassEffect)

        super.init(frame: .zero)

        // Ensure tint adjustment mode is automatic so views dim when sheets are presented
        tintAdjustmentMode = .automatic
        fabGlassView.tintAdjustmentMode = .automatic

        setupViews()

        // Ensure deterministic initial appearance (no “missing plus” on first render).
        // `updateActions` may be called before the view is in a window, so we avoid starting at alpha 0.
        fabGlassView.alpha = 1
        fabGlassView.isHidden = actions.isEmpty
        fabGlassView.isUserInteractionEnabled = !actions.isEmpty
        applyFabTintEffect()

        updateActions(actions)
    }

    private func applyFabTintEffect() {
        // Recreate the effect to ensure tint is applied immediately/reliably.
        fabGlassView.tintColor = appearance.colors.fabBackgroundTint
        // Clearing the effect first makes UIKit reliably re-render the tint
        // when toggling hidden/shown quickly.
        fabGlassView.effect = nil
        let effect = UIGlassEffect()
        effect.isInteractive = true
        effect.tintColor = fabGlassView.tintColor
        fabGlassView.effect = effect
    }

    func updateAppearance(_ appearance: FabBarAppearance) {
        self.appearance = appearance
        applyFabTintEffect()
        applyFabButtonConfiguration(actions)
    }

    private func setupViews() {
        // Add container effect view
        addSubview(containerEffectView)
        containerEffectView.translatesAutoresizingMaskIntoConstraints = false

        // Add segmented glass view to container's contentView
        containerEffectView.contentView.addSubview(segmentedGlassView)
        segmentedGlassView.translatesAutoresizingMaskIntoConstraints = false

        // Add segmented control to segmented glass view's contentView
        segmentedGlassView.contentView.addSubview(segmentedControl)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        // Always add the FAB glass view so the segmented control keeps a stable width
        // whether the button is shown or hidden.
        containerEffectView.contentView.addSubview(fabGlassView)
        fabGlassView.translatesAutoresizingMaskIntoConstraints = false

        // Extra bottom inset compensates for UISegmentedControl's internal padding,
        // visually centering the content within the glass container.
        let segmentedControlBottomInsetAdjustment: CGFloat = 1

        let segmentedLeading = segmentedGlassView.leadingAnchor.constraint(equalTo: containerEffectView.contentView.leadingAnchor)
        segmentedLeadingConstraint = segmentedLeading

        let segmentedCenterX = segmentedGlassView.centerXAnchor.constraint(equalTo: containerEffectView.contentView.centerXAnchor)
        segmentedCenterXConstraint = segmentedCenterX
        segmentedCenterX.isActive = false

        // When the FAB is hidden we still want the segmented capsule to be the same width
        // as when the FAB is shown (i.e. reserve FAB width + spacing).
        let segmentedHiddenWidth = segmentedGlassView.widthAnchor.constraint(
            equalTo: containerEffectView.contentView.widthAnchor,
            constant: -(Constants.barHeight + Constants.fabSpacing)
        )
        segmentedHiddenWidthConstraint = segmentedHiddenWidth
        segmentedHiddenWidth.isActive = false

        let constraints: [NSLayoutConstraint] = [
            containerEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerEffectView.topAnchor.constraint(equalTo: topAnchor),
            containerEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            segmentedGlassView.topAnchor.constraint(equalTo: containerEffectView.contentView.topAnchor),
            segmentedGlassView.bottomAnchor.constraint(equalTo: containerEffectView.contentView.bottomAnchor),
            segmentedLeading,

            segmentedControl.leadingAnchor.constraint(equalTo: segmentedGlassView.contentView.leadingAnchor, constant: contentPadding),
            segmentedControl.trailingAnchor.constraint(equalTo: segmentedGlassView.contentView.trailingAnchor, constant: -contentPadding),
            segmentedControl.topAnchor.constraint(equalTo: segmentedGlassView.contentView.topAnchor, constant: contentPadding),
            segmentedControl.bottomAnchor.constraint(equalTo: segmentedGlassView.contentView.bottomAnchor, constant: -contentPadding - segmentedControlBottomInsetAdjustment),
        ]

        NSLayoutConstraint.activate(constraints)

        // FAB glass view constraints are always active (space reservation).
        fabGlassViewConstraints = [
            fabGlassView.trailingAnchor.constraint(equalTo: containerEffectView.contentView.trailingAnchor),
            fabGlassView.topAnchor.constraint(equalTo: containerEffectView.contentView.topAnchor),
            fabGlassView.bottomAnchor.constraint(equalTo: containerEffectView.contentView.bottomAnchor),
            fabGlassView.widthAnchor.constraint(equalTo: fabGlassView.heightAnchor),
        ]
        NSLayoutConstraint.activate(fabGlassViewConstraints)

        // Set up the trailing constraint based on tab count
        segmentedTrailingConstraint = makeSegmentedTrailingConstraint()
        segmentedTrailingConstraint?.isActive = true
    }

    func updateActions(_ newActions: [FabBarAction]) {
        actionTransitionID &+= 1
        let transitionID = actionTransitionID

        let wasShowing = !actions.isEmpty
        let willShow = !newActions.isEmpty

        // Stay visible: refresh taps/menu wiring without running FAB hide-show choreography.
        if wasShowing, willShow {
            actions = newActions
            if newActions.count <= 1 {
                dismissCapsuleOverflowIfNeeded(animated: false)
            }
            ensureFabButtonInstalledIfNeeded()
            applyFabButtonConfiguration(actions)

            fabGlassView.isHidden = false
            fabGlassView.isUserInteractionEnabled = true
            fabGlassView.alpha = 1
            segmentedLeadingConstraint?.isActive = true
            segmentedCenterXConstraint?.isActive = false
            segmentedHiddenWidthConstraint?.isActive = false
            return
        }

        actions = newActions
        if newActions.count <= 1 || newActions.isEmpty {
            dismissCapsuleOverflowIfNeeded(animated: false)
        }

        // Only clear layer animations when the FAB is actually crossing hidden ↔ visible.
        // `updateUIView` often runs again while a hide fade is still running (same empty
        // actions); `removeAllAnimations()` would cancel `fabFade` and snap the + away.
        if wasShowing != willShow {
            fabGlassView.layer.removeAllAnimations()
            segmentedGlassView.layer.removeAllAnimations()
        }

        if willShow {
            applyFabTintEffect()
            ensureFabButtonInstalledIfNeeded()
            applyFabButtonConfiguration(actions)
            fabButton?.accessibilityTraits = .button
            fabButton?.tintAdjustmentMode = .automatic
        }

        let shouldAnimateFabOpacity = (wasShowing != willShow) && window != nil
        if willShow {
            fabGlassView.isHidden = false
            fabGlassView.isUserInteractionEnabled = false
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard transitionID == self.actionTransitionID else { return }
                guard !self.actions.isEmpty, self.fabGlassView.isHidden == false else { return }
                self.applyFabTintEffect()
                self.applyFabButtonConfiguration(self.actions)
            }
        } else {
            fabGlassView.isUserInteractionEnabled = false
        }

        let shouldAnimateTabs = (wasShowing != willShow) && window != nil

        if willShow {
            segmentedLeadingConstraint?.isActive = true
            segmentedCenterXConstraint?.isActive = false
            segmentedHiddenWidthConstraint?.isActive = false
        } else {
            segmentedLeadingConstraint?.isActive = false
            segmentedCenterXConstraint?.isActive = true
            segmentedHiddenWidthConstraint?.isActive = true
        }

        if shouldAnimateTabs {
            UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
                self.layoutIfNeeded()
            }
        } else {
            setNeedsLayout()
            layoutIfNeeded()
        }

        if shouldAnimateFabOpacity {
            fabGlassView.layer.removeAnimation(forKey: "fabFade")
            fabGlassView.layer.opacity = 1
            fabGlassView.layer.transform = CATransform3DIdentity

            runFabShowHideAnimationLikeLegacyTabBar(willShow: willShow)
        } else if window != nil, !willShow, !fabGlassView.isHidden {
            // Redundant empty `updateActions` while the hide spring runs — let completion settle visibility.
        } else {
            fabGlassView.layer.opacity = 1
            fabGlassView.layer.transform = CATransform3DIdentity
            fabGlassView.transform = .identity
            if willShow {
                fabGlassView.isHidden = false
                fabGlassView.isUserInteractionEnabled = true
            } else {
                fabGlassView.isUserInteractionEnabled = false
                fabGlassView.isHidden = true
            }
        }
    }

    private func animateStep(animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(
            withDuration: LegacyPlusButtonMotion.duration,
            delay: 0,
            usingSpringWithDamping: LegacyPlusButtonMotion.springDamping,
            initialSpringVelocity: LegacyPlusButtonMotion.springVelocity,
            options: LegacyPlusButtonMotion.options,
            animations: animations,
            completion: completion
        )
    }

    private func runFabShowHideAnimationLikeLegacyTabBar(willShow: Bool) {
        let hiddenTransform = LegacyPlusButtonMotion.hiddenTransform

        if willShow {
            fabGlassView.isHidden = false
            fabGlassView.alpha = 0
            fabGlassView.transform = hiddenTransform
            animateStep(animations: {
                self.fabGlassView.alpha = 1
                self.fabGlassView.transform = .identity
            }, completion: { [weak self] finished in
                guard let self else { return }
                guard finished else { return }
                if self.actions.isEmpty {
                    self.fabGlassView.isUserInteractionEnabled = false
                    self.fabGlassView.isHidden = true
                    self.fabGlassView.alpha = 1
                    self.fabGlassView.transform = .identity
                    return
                }
                self.fabGlassView.isHidden = false
                self.fabGlassView.isUserInteractionEnabled = true
                self.fabGlassView.alpha = 1
                self.fabGlassView.transform = .identity
            })
        } else {
            guard !fabGlassView.isHidden else {
                return
            }

            animateStep(animations: {
                self.fabGlassView.alpha = 0
                self.fabGlassView.transform = hiddenTransform
            }, completion: { [weak self] finished in
                guard let self else { return }
                guard finished else { return }
                self.fabGlassView.isUserInteractionEnabled = false
                animateStep(animations: {
                    self.fabGlassView.isHidden = true
                    self.fabGlassView.transform = .identity
                    self.fabGlassView.alpha = 1
                }, completion: { [weak self] finished in
                    guard let self else { return }
                    guard finished else { return }
                    guard self.actions.isEmpty else {
                        self.fabGlassView.isHidden = false
                        self.fabGlassView.isUserInteractionEnabled = true
                        self.fabGlassView.alpha = 1
                        self.fabGlassView.transform = .identity
                        return
                    }
                    self.fabGlassView.transform = .identity
                    self.fabGlassView.alpha = 1
                })
            })
        }
    }

    private func ensureFabButtonInstalledIfNeeded() {
        guard fabButton == nil else { return }
        let button = UIButton(type: .system)
        fabButton = button
        fabGlassView.contentView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        fabConstraints = [
            button.leadingAnchor.constraint(equalTo: fabGlassView.contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: fabGlassView.contentView.trailingAnchor),
            button.topAnchor.constraint(equalTo: fabGlassView.contentView.topAnchor),
            button.bottomAnchor.constraint(equalTo: fabGlassView.contentView.bottomAnchor),
        ]
        NSLayoutConstraint.activate(fabConstraints)
    }

    private func applyFabButtonConfiguration(_ actions: [FabBarAction]) {
        guard let fabButton, !actions.isEmpty else { return }

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: Constants.fabIconPointSize, weight: .medium)
        fabButton.removeTarget(nil, action: nil, for: .allEvents)

        if actions.count == 1 {
            fabButton.menu = nil
            fabButton.showsMenuAsPrimaryAction = false
            fabButton.adjustsImageWhenHighlighted = true
            fabButton.tintColor = appearance.colors.fabIconTint
            let single = actions[0]
            fabButton.setImage(UIImage(systemName: single.systemImage, withConfiguration: symbolConfig), for: .normal)
            fabButton.accessibilityLabel = single.accessibilityLabel
            fabButton.addAction(UIAction { _ in single.action() }, for: .touchUpInside)
            animateFabOverflowExpanded(false, animated: false)
        } else {
            fabButton.menu = nil
            fabButton.showsMenuAsPrimaryAction = false
            fabButton.adjustsImageWhenHighlighted = false
            fabButton.tintColor = appearance.colors.fabBackgroundTint
            let whitePlus = UIImage(systemName: "plus", withConfiguration: symbolConfig)?
                .withTintColor(appearance.colors.fabIconTint, renderingMode: .alwaysOriginal)
            fabButton.setImage(whitePlus, for: .normal)
            fabButton.imageView?.contentMode = .center
            fabButton.addAction(UIAction { [weak self] _ in
                self?.toggleCapsuleOverflow()
            }, for: .touchUpInside)
        }
    }

    private func animateFabOverflowExpanded(_ expanded: Bool, animated: Bool) {
        guard fabButton != nil else { return }

        let angle: CGFloat = expanded ? .pi * 3 / 4 : 0
        let apply = {
            self.fabGlassView.transform = CGAffineTransform(rotationAngle: angle)
        }

        if animated {
            UIView.animate(
                withDuration: OverflowMotion.fabRotationDuration,
                delay: 0,
                usingSpringWithDamping: OverflowMotion.fabRotationDamping,
                initialSpringVelocity: OverflowMotion.fabRotationVelocity,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: apply
            )
        } else {
            apply()
        }
    }

    private func toggleCapsuleOverflow() {
        if capsuleOverflowSession != nil {
            dismissCapsuleOverflowIfNeeded(animated: true)
        } else {
            presentCapsuleOverflow()
        }
    }

    private func withUnrotatedFabGlassView<T>(_ work: () -> T) -> T {
        let transform = fabGlassView.transform
        fabGlassView.transform = .identity
        defer { fabGlassView.transform = transform }
        return work()
    }

    private func presentCapsuleOverflow() {
        guard actions.count > 1, let window else { return }

        dismissCapsuleOverflowIfNeeded(animated: false)

        let session = FabGlassCapsuleOverflowPanel.makeSession(
            actions: actions,
            appearance: appearance,
            onSelect: { [weak self] action in
                self?.dismissCapsuleOverflowIfNeeded(animated: true)
                action.action()
            },
            onDismissRequest: { [weak self] in
                self?.dismissCapsuleOverflowIfNeeded(animated: true)
            }
        )

        session.dimmingView.alpha = 0
        session.stackContainer.alpha = 1

        window.addSubview(session.dimmingView)
        window.addSubview(session.stackContainer)
        withUnrotatedFabGlassView {
            FabGlassCapsuleOverflowPanel.layout(session: session, anchorView: fabGlassView, in: window)
            FabGlassCapsuleOverflowPanel.prepareCellsEmerging(stackView: session.stackView, anchorView: fabGlassView)
        }

        capsuleOverflowSession = session

        fabButton?.layoutIfNeeded()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseOut]) {
            session.dimmingView.alpha = 1
        }

        animateFabOverflowExpanded(true, animated: true)

        let cells = session.stackView.arrangedSubviews
        let indicesFromBottomUp = Array((0..<cells.count).reversed())
        for (step, idx) in indicesFromBottomUp.enumerated() {
            guard let cap = cells[idx] as? FabOverflowCapsuleContainerView else { continue }
            UIView.animate(
                withDuration: OverflowMotion.rowDuration,
                delay: OverflowMotion.stagger * Double(step),
                usingSpringWithDamping: OverflowMotion.rowDamping,
                initialSpringVelocity: OverflowMotion.rowVelocity,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                cap.contentWrapper.alpha = 1
                cap.contentWrapper.transform = .identity
            }
        }

        let settleDelay = OverflowMotion.stagger * Double(max(0, cells.count - 1)) + 0.12
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) { [weak self] in
            guard self?.capsuleOverflowSession != nil else { return }
            if #available(iOS 17.0, *) {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func dismissCapsuleOverflowIfNeeded(animated: Bool) {
        guard let session = capsuleOverflowSession else {
            if !animated {
                animateFabOverflowExpanded(false, animated: false)
            }
            return
        }
        capsuleOverflowSession = nil

        if !animated {
            animateFabOverflowExpanded(false, animated: false)
            session.dimmingView.removeFromSuperview()
            session.stackContainer.removeFromSuperview()
            return
        }

        if let window = session.stackContainer.window ?? fabGlassView.window {
            withUnrotatedFabGlassView {
                FabGlassCapsuleOverflowPanel.layout(session: session, anchorView: fabGlassView, in: window)
                FabGlassCapsuleOverflowPanel.refreshEmergenceTransformsForDismiss(stackView: session.stackView, anchorView: fabGlassView)
            }
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        animateFabOverflowExpanded(false, animated: true)

        UIView.animate(withDuration: 0.26, delay: 0, options: [.curveEaseIn]) {
            session.dimmingView.alpha = 0
        }

        let cells = session.stackView.arrangedSubviews
        let indicesFromBottomUp = Array((0..<cells.count).reversed())
        for (step, idx) in indicesFromBottomUp.enumerated() {
            guard let cap = cells[idx] as? FabOverflowCapsuleContainerView else { continue }
            UIView.animate(
                withDuration: OverflowMotion.rowDuration,
                delay: OverflowMotion.stagger * Double(step),
                usingSpringWithDamping: OverflowMotion.rowDamping,
                initialSpringVelocity: OverflowMotion.rowVelocity * 0.85,
                options: [.beginFromCurrentState, .curveEaseIn]
            ) {
                cap.contentWrapper.alpha = 0
                cap.contentWrapper.transform = cap.emergenceTransform
            }
        }

        let lastDelay = OverflowMotion.stagger * Double(max(0, cells.count - 1)) + OverflowMotion.rowDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + lastDelay) {
            session.dimmingView.removeFromSuperview()
            session.stackContainer.removeFromSuperview()
        }
    }

    /// Creates the appropriate trailing constraint for the segmented glass view.
    /// For 3+ tabs, fills to the FAB. For fewer tabs, floats leading-aligned.
    private func makeSegmentedTrailingConstraint() -> NSLayoutConstraint {
        if tabCount >= 3 {
            return segmentedGlassView.trailingAnchor.constraint(equalTo: fabGlassView.leadingAnchor, constant: -spacing)
        } else {
            return segmentedGlassView.trailingAnchor.constraint(lessThanOrEqualTo: fabGlassView.leadingAnchor, constant: -spacing)
        }
    }

    /// Updates the tab count and swaps the trailing constraint to match.
    func updateTabCount(_ newCount: Int) {
        guard newCount != tabCount else { return }
        tabCount = newCount
        segmentedTrailingConstraint?.isActive = false
        segmentedTrailingConstraint = makeSegmentedTrailingConstraint()
        segmentedTrailingConstraint?.isActive = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Capsule shape for segmented control
        segmentedGlassView.cornerConfiguration = .capsule()

        // Circle shape for FAB button (capsule with equal width/height = circle)
        fabGlassView.cornerConfiguration = .capsule()

        if let session = capsuleOverflowSession, let window {
            withUnrotatedFabGlassView {
                FabGlassCapsuleOverflowPanel.layout(session: session, anchorView: fabGlassView, in: window)
            }
            window.bringSubviewToFront(session.dimmingView)
            window.bringSubviewToFront(session.stackContainer)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            dismissCapsuleOverflowIfNeeded(animated: false)
        }
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        guard fabGlassView.superview != nil else { return }
        applyFabTintEffect()
    }
}
