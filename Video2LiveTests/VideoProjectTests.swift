import AVFoundation
import XCTest
@testable import Video2Live

final class VideoProjectTests: XCTestCase {
    func testConfigureClipCentersThreeSecondSelection() {
        let project = VideoProject()

        project.configureClip(for: 10)

        XCTAssertEqual(project.rangeStart, 3.5, accuracy: 0.001)
        XCTAssertEqual(project.rangeDuration, 3, accuracy: 0.001)
        XCTAssertEqual(project.coverTime, 5, accuracy: 0.001)
    }

    func testConfigureClipUsesEntireShortVideo() {
        let project = VideoProject()

        project.configureClip(for: 2)

        XCTAssertEqual(project.rangeStart, 0, accuracy: 0.001)
        XCTAssertEqual(project.rangeDuration, 2, accuracy: 0.001)
        XCTAssertEqual(project.coverTime, 1, accuracy: 0.001)
    }

    func testMovingSelectionPreservesCoverOffsetAndClampsRange() {
        let project = VideoProject()
        project.configureClip(for: 10)

        project.setRangeStart(20)

        XCTAssertEqual(project.rangeStart, 7, accuracy: 0.001)
        XCTAssertEqual(project.coverTime, 8.5, accuracy: 0.001)
    }

    func testCoverTimeIsClampedInsideSelectedRange() {
        let project = VideoProject()
        project.configureClip(for: 10)

        project.setCoverTime(20)

        XCTAssertEqual(project.coverTime, 6.5 - (1.0 / 30.0), accuracy: 0.001)
    }

    func testAssetTimesIncludeSourceTrackOffset() {
        let project = VideoProject()
        project.sourceTimeRange = CMTimeRange(
            start: CMTime(seconds: 2, preferredTimescale: 600),
            duration: CMTime(seconds: 10, preferredTimescale: 600)
        )
        project.configureClip(for: 10)

        XCTAssertEqual(project.selectedTimeRange.start.seconds, 5.5, accuracy: 0.001)
        XCTAssertEqual(project.keyFrameTime.seconds, 7, accuracy: 0.001)
        XCTAssertEqual(project.stillImageTime.seconds, 1.5, accuracy: 0.001)
    }

    func testPortraitFramingCropsLandscapeVideoHorizontally() {
        let framing = VideoFraming(aspectRatio: .portrait, position: 0)

        let cropRect = framing.cropRect(in: CGSize(width: 1920, height: 1080))

        XCTAssertEqual(framing.cropAxis(in: CGSize(width: 1920, height: 1080)), .horizontal)
        XCTAssertEqual(cropRect.width, 607.5, accuracy: 0.001)
        XCTAssertEqual(cropRect.minX, 656.25, accuracy: 0.001)
        XCTAssertEqual(framing.renderSize(for: cropRect.size), CGSize(width: 594, height: 1056))
    }

    func testCropPositionMovesAcrossAvailableHorizontalRange() {
        let sourceSize = CGSize(width: 1920, height: 1080)

        let leadingRect = VideoFraming(aspectRatio: .portrait, position: -1)
            .cropRect(in: sourceSize)
        let trailingRect = VideoFraming(aspectRatio: .portrait, position: 1)
            .cropRect(in: sourceSize)

        XCTAssertEqual(leadingRect.minX, 0, accuracy: 0.001)
        XCTAssertEqual(trailingRect.maxX, sourceSize.width, accuracy: 0.001)
    }

    func testSquareFramingCropsPortraitVideoVertically() {
        let framing = VideoFraming(aspectRatio: .square, position: 0)

        let cropRect = framing.cropRect(in: CGSize(width: 1080, height: 1920))

        XCTAssertEqual(framing.cropAxis(in: CGSize(width: 1080, height: 1920)), .vertical)
        XCTAssertEqual(cropRect, CGRect(x: 0, y: 420, width: 1080, height: 1080))
        XCTAssertEqual(framing.renderSize(for: cropRect.size), CGSize(width: 1080, height: 1080))
    }

    func testChangingAspectRatioRecentersCrop() {
        let project = VideoProject()
        project.framing = VideoFraming(aspectRatio: .portrait, position: 0.8)

        project.setOutputAspectRatio(.square)

        XCTAssertEqual(project.framing.aspectRatio, .square)
        XCTAssertEqual(project.framing.position, 0)
    }

    func testRenderTransformMapsCropBoundsToOutputBounds() {
        let geometry = VideoFraming(aspectRatio: .portrait, position: 0)
            .renderGeometry(
                naturalSize: CGSize(width: 1920, height: 1080),
                preferredTransform: .identity
            )

        let outputMinimum = geometry.cropRect.origin.applying(geometry.transform)
        let outputMaximum = CGPoint(
            x: geometry.cropRect.maxX,
            y: geometry.cropRect.maxY
        ).applying(geometry.transform)

        XCTAssertEqual(outputMinimum.x, 0, accuracy: 0.001)
        XCTAssertEqual(outputMinimum.y, 0, accuracy: 0.001)
        XCTAssertEqual(outputMaximum.x, geometry.renderSize.width, accuracy: 0.001)
        XCTAssertEqual(outputMaximum.y, geometry.renderSize.height, accuracy: 0.001)
    }

    func testRenderGeometryNormalizesRotatedPortraitVideo() {
        let preferredTransform = CGAffineTransform(
            a: 0,
            b: 1,
            c: -1,
            d: 0,
            tx: 1080,
            ty: 0
        )
        let framing = VideoFraming(aspectRatio: .square, position: 0)
        let naturalSize = CGSize(width: 1920, height: 1080)
        let geometry = framing.renderGeometry(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform
        )
        let transformedRect = CGRect(origin: .zero, size: naturalSize)
            .applying(preferredTransform)
            .standardized
        let normalizedTransform = preferredTransform.concatenating(
            CGAffineTransform(
                translationX: -transformedRect.minX,
                y: -transformedRect.minY
            )
        )
        let sourceMinimum = geometry.cropRect.origin
            .applying(normalizedTransform.inverted())
        let sourceMaximum = CGPoint(
            x: geometry.cropRect.maxX,
            y: geometry.cropRect.maxY
        ).applying(normalizedTransform.inverted())

        XCTAssertEqual(geometry.orientedSize, CGSize(width: 1080, height: 1920))
        XCTAssertEqual(geometry.cropRect, CGRect(x: 0, y: 420, width: 1080, height: 1080))
        XCTAssertEqual(sourceMinimum.applying(geometry.transform).x, 0, accuracy: 0.001)
        XCTAssertEqual(sourceMinimum.applying(geometry.transform).y, 0, accuracy: 0.001)
        XCTAssertEqual(
            sourceMaximum.applying(geometry.transform).x,
            geometry.renderSize.width,
            accuracy: 0.001
        )
        XCTAssertEqual(
            sourceMaximum.applying(geometry.transform).y,
            geometry.renderSize.height,
            accuracy: 0.001
        )
    }

    func testDraggingPreviewMovesHorizontalCropInOppositeDirection() {
        let framing = VideoFraming(aspectRatio: .portrait, position: 0)

        let position = framing.position(
            afterDragging: CGSize(width: -75, height: 20),
            from: 0,
            previewSize: CGSize(width: 150, height: 300),
            sourceSize: CGSize(width: 1920, height: 1080)
        )

        XCTAssertEqual(position, 1, accuracy: 0.001)
    }

    func testDraggingPreviewClampsVerticalCropPosition() {
        let framing = VideoFraming(aspectRatio: .square, position: 0.5)

        let position = framing.position(
            afterDragging: CGSize(width: 20, height: -200),
            from: 0.5,
            previewSize: CGSize(width: 300, height: 200),
            sourceSize: CGSize(width: 1080, height: 1920)
        )

        XCTAssertEqual(position, 1, accuracy: 0.001)
    }
}