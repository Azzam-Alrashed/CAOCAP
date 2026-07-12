import SwiftUI
import UIKit

/// A nested dotted grid backed by three reusable Core Animation replicator layers.
///
/// The grid moves by updating a small set of layer properties rather than rebuilding
/// every visible dot in SwiftUI's `Canvas` for each pan or pinch update.
struct DottedBackground: View {
    @AppStorage("grid_opacity") private var gridOpacity: Double = 0.1
    @Environment(\.colorScheme) private var colorScheme

    let offset: CGSize
    let scale: CGFloat

    var body: some View {
        ReplicatorDottedGrid(
            offset: offset,
            scale: scale,
            gridOpacity: gridOpacity,
            colorScheme: colorScheme
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ReplicatorDottedGrid: UIViewRepresentable {
    let offset: CGSize
    let scale: CGFloat
    let gridOpacity: Double
    let colorScheme: ColorScheme

    func makeUIView(context: Context) -> DottedGridView {
        DottedGridView(frame: .zero)
    }

    func updateUIView(_ gridView: DottedGridView, context: Context) {
        gridView.update(
            offset: offset,
            scale: scale,
            gridOpacity: gridOpacity,
            colorScheme: colorScheme
        )
    }
}

private final class DottedGridView: UIView {
    private let dotSpacing: CGFloat = 30
    private let dotSize: CGFloat = 2
    private let sparseLevel = DottedGridLevel(name: "sparse")
    private let mediumLevel = DottedGridLevel(name: "medium")
    private let denseLevel = DottedGridLevel(name: "dense")

    private var configuration = Configuration(
        offset: .zero,
        scale: 1,
        gridOpacity: 0.1,
        colorScheme: .light
    )

    override init(frame: CGRect) {
        super.init(frame: frame)

        isOpaque = false
        backgroundColor = .clear
        isAccessibilityElement = false

        layer.addSublayer(sparseLevel.layer)
        layer.addSublayer(mediumLevel.layer)
        layer.addSublayer(denseLevel.layer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        render()
    }

    func update(offset: CGSize, scale: CGFloat, gridOpacity: Double, colorScheme: ColorScheme) {
        configuration = Configuration(
            offset: offset,
            scale: scale,
            gridOpacity: gridOpacity,
            colorScheme: colorScheme
        )
        render()
    }

    private func render() {
        let bounds = self.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let maxAlpha = CGFloat(configuration.gridOpacity * 5)
        let sparseAlpha = fade(
            value: (configuration.scale - 0.05) / 0.1,
            maxAlpha: maxAlpha
        )
        let mediumAlpha = fade(
            value: (configuration.scale - 0.15) / 0.25,
            maxAlpha: maxAlpha
        )
        let denseAlpha = fade(
            value: (configuration.scale - 0.4) / 0.4,
            maxAlpha: maxAlpha
        )
        let dotColor: UIColor = configuration.colorScheme == .dark ? .white : .black

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        sparseLevel.update(
            in: bounds,
            offset: configuration.offset,
            scale: configuration.scale,
            spacing: dotSpacing * 4,
            dotSize: dotSize,
            alpha: sparseAlpha,
            color: dotColor
        )
        mediumLevel.update(
            in: bounds,
            offset: configuration.offset,
            scale: configuration.scale,
            spacing: dotSpacing * 2,
            dotSize: dotSize,
            alpha: mediumAlpha,
            color: dotColor
        )
        denseLevel.update(
            in: bounds,
            offset: configuration.offset,
            scale: configuration.scale,
            spacing: dotSpacing,
            dotSize: dotSize,
            alpha: denseAlpha,
            color: dotColor
        )

        CATransaction.commit()
    }

    private func fade(value: CGFloat, maxAlpha: CGFloat) -> CGFloat {
        min(1, max(0, value)) * min(1, max(0, maxAlpha))
    }

    private struct Configuration {
        let offset: CGSize
        let scale: CGFloat
        let gridOpacity: Double
        let colorScheme: ColorScheme
    }
}

private final class DottedGridLevel {
    let layer = CAReplicatorLayer()
    private let rowReplicator = CAReplicatorLayer()
    private let dotLayer = CALayer()

    init(name: String) {
        layer.name = "caocap.dottedGrid.\(name)"
        layer.masksToBounds = false

        rowReplicator.masksToBounds = false
        dotLayer.cornerRadius = 1
        dotLayer.masksToBounds = true

        rowReplicator.addSublayer(dotLayer)
        layer.addSublayer(rowReplicator)
    }

    func update(
        in bounds: CGRect,
        offset: CGSize,
        scale: CGFloat,
        spacing: CGFloat,
        dotSize: CGFloat,
        alpha: CGFloat,
        color: UIColor
    ) {
        let scaledSpacing = spacing * scale
        guard alpha > 0, scaledSpacing > 0 else {
            layer.isHidden = true
            return
        }

        let centerX = bounds.width / 2
        let centerY = bounds.height / 2
        let startX = (offset.width + centerX).truncatingRemainder(dividingBy: scaledSpacing) - scaledSpacing
        let startY = (offset.height + centerY).truncatingRemainder(dividingBy: scaledSpacing) - scaledSpacing

        layer.isHidden = false
        layer.frame = bounds
        layer.opacity = Float(alpha)
        rowReplicator.frame = bounds
        rowReplicator.instanceTransform = CATransform3DMakeTranslation(scaledSpacing, 0, 0)
        layer.instanceTransform = CATransform3DMakeTranslation(0, scaledSpacing, 0)
        rowReplicator.instanceCount = instanceCount(
            from: startX,
            through: bounds.width + scaledSpacing,
            spacing: scaledSpacing
        )
        layer.instanceCount = instanceCount(
            from: startY,
            through: bounds.height + scaledSpacing,
            spacing: scaledSpacing
        )
        dotLayer.frame = CGRect(x: startX, y: startY, width: dotSize, height: dotSize)
        dotLayer.cornerRadius = dotSize / 2
        dotLayer.backgroundColor = color.cgColor
    }

    private func instanceCount(from start: CGFloat, through end: CGFloat, spacing: CGFloat) -> Int {
        max(1, Int(ceil((end - start) / spacing)) + 1)
    }
}
