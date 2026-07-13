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
    private var layoutSignature: LayoutSignature?

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
        layoutSignature = nil
        updateGrid()
    }

    func update(offset: CGSize, scale: CGFloat, gridOpacity: Double, colorScheme: ColorScheme) {
        configuration = Configuration(
            offset: offset,
            scale: scale,
            gridOpacity: gridOpacity,
            colorScheme: colorScheme
        )
        updateGrid()
    }

    private func updateGrid() {
        let bounds = self.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let newLayoutSignature = LayoutSignature(
            bounds: bounds,
            scale: configuration.scale,
            gridOpacity: configuration.gridOpacity,
            colorScheme: configuration.colorScheme
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if layoutSignature != newLayoutSignature {
            configureLayout(in: bounds)
            layoutSignature = newLayoutSignature
        }

        updateOrigins()

        CATransaction.commit()
    }

    private func configureLayout(in bounds: CGRect) {

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

        sparseLevel.configureLayout(
            in: bounds,
            scale: configuration.scale,
            spacing: dotSpacing * 4,
            dotSize: dotSize,
            alpha: sparseAlpha,
            color: dotColor
        )
        mediumLevel.configureLayout(
            in: bounds,
            scale: configuration.scale,
            spacing: dotSpacing * 2,
            dotSize: dotSize,
            alpha: mediumAlpha,
            color: dotColor
        )
        denseLevel.configureLayout(
            in: bounds,
            scale: configuration.scale,
            spacing: dotSpacing,
            dotSize: dotSize,
            alpha: denseAlpha,
            color: dotColor
        )

    }

    private func updateOrigins() {
        sparseLevel.updateOrigin(offset: configuration.offset)
        mediumLevel.updateOrigin(offset: configuration.offset)
        denseLevel.updateOrigin(offset: configuration.offset)
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

    private struct LayoutSignature: Equatable {
        let bounds: CGRect
        let scale: CGFloat
        let gridOpacity: Double
        let colorScheme: ColorScheme
    }
}

private final class DottedGridLevel {
    let layer = CAReplicatorLayer()
    private let rowReplicator = CAReplicatorLayer()
    private let dotLayer = CALayer()
    private var layout: Layout?

    init(name: String) {
        layer.name = "caocap.dottedGrid.\(name)"
        layer.masksToBounds = false

        rowReplicator.masksToBounds = false
        dotLayer.cornerRadius = 1
        dotLayer.masksToBounds = true

        rowReplicator.addSublayer(dotLayer)
        layer.addSublayer(rowReplicator)
    }

    func configureLayout(
        in bounds: CGRect,
        scale: CGFloat,
        spacing: CGFloat,
        dotSize: CGFloat,
        alpha: CGFloat,
        color: UIColor
    ) {
        let scaledSpacing = spacing * scale
        guard alpha > 0, scaledSpacing > 0 else {
            layer.isHidden = true
            layout = nil
            return
        }

        layer.isHidden = false
        layer.frame = bounds
        layer.opacity = Float(alpha)
        rowReplicator.frame = bounds
        rowReplicator.instanceTransform = CATransform3DMakeTranslation(scaledSpacing, 0, 0)
        layer.instanceTransform = CATransform3DMakeTranslation(0, scaledSpacing, 0)
        rowReplicator.instanceCount = instanceCount(for: bounds.width, spacing: scaledSpacing)
        layer.instanceCount = instanceCount(for: bounds.height, spacing: scaledSpacing)
        dotLayer.bounds = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
        dotLayer.cornerRadius = dotSize / 2
        dotLayer.backgroundColor = color.cgColor

        layout = Layout(bounds: bounds, scaledSpacing: scaledSpacing, dotSize: dotSize)
    }

    func updateOrigin(offset: CGSize) {
        guard let layout else { return }

        let centerX = layout.bounds.width / 2
        let centerY = layout.bounds.height / 2
        let startX = (offset.width + centerX).truncatingRemainder(dividingBy: layout.scaledSpacing) - layout.scaledSpacing
        let startY = (offset.height + centerY).truncatingRemainder(dividingBy: layout.scaledSpacing) - layout.scaledSpacing

        dotLayer.position = CGPoint(
            x: startX + layout.dotSize / 2,
            y: startY + layout.dotSize / 2
        )
    }

    private func instanceCount(for length: CGFloat, spacing: CGFloat) -> Int {
        // The origin may be almost one spacing before the layer bounds. Reserve the
        // extra replicas once so panning only changes the dot phase.
        max(1, Int(ceil(length / spacing)) + 3)
    }

    private struct Layout {
        let bounds: CGRect
        let scaledSpacing: CGFloat
        let dotSize: CGFloat
    }
}
