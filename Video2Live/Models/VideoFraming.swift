import CoreGraphics

enum OutputAspectRatio: String, CaseIterable, Identifiable {
    case original
    case portrait
    case square

    var id: Self { self }

    var title: String {
        switch self {
        case .original:
            return "Original"
        case .portrait:
            return "9:16"
        case .square:
            return "1:1"
        }
    }

    fileprivate var components: CGSize? {
        switch self {
        case .original:
            return nil
        case .portrait:
            return CGSize(width: 9, height: 16)
        case .square:
            return CGSize(width: 1, height: 1)
        }
    }
}

enum CropAxis: Equatable {
    case none
    case horizontal
    case vertical
}

struct VideoFraming: Equatable {
    var aspectRatio: OutputAspectRatio = .original
    var position: Double = 0

    func cropAxis(in sourceSize: CGSize) -> CropAxis {
        guard let components = aspectRatio.components,
              sourceSize.width > 0,
              sourceSize.height > 0 else {
            return .none
        }

        let sourceRatio = sourceSize.width / sourceSize.height
        let targetRatio = components.width / components.height
        if abs(sourceRatio - targetRatio) < 0.0001 {
            return .none
        }
        return sourceRatio > targetRatio ? .horizontal : .vertical
    }

    func cropRect(in sourceSize: CGSize) -> CGRect {
        let fullRect = CGRect(origin: .zero, size: sourceSize)
        guard let components = aspectRatio.components,
              sourceSize.width > 0,
              sourceSize.height > 0 else {
            return fullRect
        }

        let targetRatio = components.width / components.height
        let unitPosition = CGFloat(min(max(position, -1), 1) + 1) / 2

        switch cropAxis(in: sourceSize) {
        case .horizontal:
            let cropWidth = sourceSize.height * targetRatio
            let originX = (sourceSize.width - cropWidth) * unitPosition
            return CGRect(x: originX, y: 0, width: cropWidth, height: sourceSize.height)
        case .vertical:
            let cropHeight = sourceSize.width / targetRatio
            let originY = (sourceSize.height - cropHeight) * unitPosition
            return CGRect(x: 0, y: originY, width: sourceSize.width, height: cropHeight)
        case .none:
            return fullRect
        }
    }

    func renderSize(for sourceSize: CGSize) -> CGSize {
        let cropSize = cropRect(in: sourceSize).size
        guard let components = aspectRatio.components else {
            return CGSize(
                width: evenPixelValue(cropSize.width),
                height: evenPixelValue(cropSize.height)
            )
        }

        let unit = max(
            1,
            floor(min(
                cropSize.width / (components.width * 2),
                cropSize.height / (components.height * 2)
            ))
        )
        return CGSize(
            width: components.width * 2 * unit,
            height: components.height * 2 * unit
        )
    }

    func renderGeometry(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform
    ) -> VideoRenderGeometry {
        let encodedRect = CGRect(origin: .zero, size: naturalSize)
        let transformedRect = encodedRect.applying(preferredTransform).standardized
        let orientedSize = transformedRect.size
        let cropRect = cropRect(in: orientedSize)
        let outputSize = renderSize(for: orientedSize)

        let normalizeTransform = preferredTransform.concatenating(
            CGAffineTransform(
                translationX: -transformedRect.minX,
                y: -transformedRect.minY
            )
        )
        let cropTransform = CGAffineTransform(
            translationX: -cropRect.minX,
            y: -cropRect.minY
        )
        let scaleTransform = CGAffineTransform(
            scaleX: outputSize.width / cropRect.width,
            y: outputSize.height / cropRect.height
        )

        return VideoRenderGeometry(
            orientedSize: orientedSize,
            cropRect: cropRect,
            renderSize: outputSize,
            transform: normalizeTransform
                .concatenating(cropTransform)
                .concatenating(scaleTransform)
        )
    }

    func position(
        afterDragging translation: CGSize,
        from startingPosition: Double,
        previewSize: CGSize,
        sourceSize: CGSize
    ) -> Double {
        let component: CGFloat
        let previewLength: CGFloat

        switch cropAxis(in: sourceSize) {
        case .horizontal:
            component = translation.width
            previewLength = previewSize.width
        case .vertical:
            component = translation.height
            previewLength = previewSize.height
        case .none:
            return 0
        }

        guard previewLength > 0 else { return startingPosition }
        let delta = -Double(component / previewLength) * 2
        return min(max(startingPosition + delta, -1), 1)
    }

    private func evenPixelValue(_ value: CGFloat) -> CGFloat {
        max(2, floor(value / 2) * 2)
    }
}

struct VideoRenderGeometry {
    let orientedSize: CGSize
    let cropRect: CGRect
    let renderSize: CGSize
    let transform: CGAffineTransform
}