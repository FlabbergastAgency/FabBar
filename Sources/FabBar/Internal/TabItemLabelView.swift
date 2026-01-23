import UIKit

/// A UIView that displays a single tab item with an icon and title stacked vertically.
@available(iOS 26.0, *)
final class TabItemLabelView<Tab: Hashable>: UIView {
    private let imageView: UIImageView
    private let titleLabel: UILabel
    private var baseImage: UIImage?

    var inactiveTintColor: UIColor = .label {
        didSet { updateColors() }
    }

    var isHighlighted: Bool = false

    init(tabItem: FabBarItem<Tab>) {
        imageView = UIImageView()
        titleLabel = UILabel()

        super.init(frame: .zero)

        setupViews(tabItem: tabItem)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews(tabItem: FabBarItem<Tab>) {
        // Configure image view
        let config = UIImage.SymbolConfiguration(
            pointSize: Constants.tabIconPointSize,
            weight: .medium,
            scale: .large
        )

        if let imageName = tabItem.image {
            let bundle = tabItem.imageBundle ?? .main
            baseImage = UIImage(named: imageName, in: bundle, with: config)
            if baseImage == nil {
                fabBarLogger.warning("Failed to load image '\(imageName)' from bundle for tab '\(tabItem.title)'")
            }
        } else if let systemImageName = tabItem.systemImage {
            baseImage = UIImage(systemName: systemImageName, withConfiguration: config)
            if baseImage == nil {
                fabBarLogger.warning("Failed to load SF Symbol '\(systemImageName)' for tab '\(tabItem.title)'")
            }
        }

        imageView.image = baseImage?.withRenderingMode(.alwaysTemplate)
        imageView.contentMode = .center
        imageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = tabItem.title
        titleLabel.font = .systemFont(ofSize: Constants.tabTitleFontSize, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView(arrangedSubviews: [imageView, titleLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: Constants.iconViewSize),
            imageView.heightAnchor.constraint(equalToConstant: Constants.iconViewSize),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        updateColors()
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        updateColors()
    }

    func updateColors(animated: Bool = false) {
        // Use self.tintColor (inherited UIView property) for active state
        // to leverage UIKit's tint color system directly
        let color = isHighlighted ? tintColor : inactiveTintColor

        if animated {
            UIView.transition(with: imageView, duration: Constants.colorTransitionDuration, options: .transitionCrossDissolve) {
                self.imageView.tintColor = color
                self.titleLabel.textColor = color
            }
        } else {
            imageView.tintColor = color
            titleLabel.textColor = color
        }
    }
}
