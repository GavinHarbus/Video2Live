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
}