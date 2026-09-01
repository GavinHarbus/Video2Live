import Foundation
import XCTest
@testable import Video2Live

final class LivePhotoExporterTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
    }

    func testExportsBothFilesWithMatchingBaseName() throws {
        let sources = try makeSourcePair()

        let result = try LivePhotoExporter().exportPair(
            heicURL: sources.heic,
            movURL: sources.mov,
            suggestedName: "Holiday",
            to: temporaryDirectory
        )

        XCTAssertEqual(result.heicURL.lastPathComponent, "Holiday Live Photo.heic")
        XCTAssertEqual(result.movURL.lastPathComponent, "Holiday Live Photo.mov")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.heicURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.movURL.path))
    }

    func testUsesSuffixWhenEitherDestinationFileExists() throws {
        let sources = try makeSourcePair()
        let existingURL = temporaryDirectory.appendingPathComponent("Holiday Live Photo.mov")
        try Data("existing".utf8).write(to: existingURL)

        let result = try LivePhotoExporter().exportPair(
            heicURL: sources.heic,
            movURL: sources.mov,
            suggestedName: "Holiday",
            to: temporaryDirectory
        )

        XCTAssertEqual(result.heicURL.lastPathComponent, "Holiday Live Photo 2.heic")
        XCTAssertEqual(result.movURL.lastPathComponent, "Holiday Live Photo 2.mov")
    }

    func testRemovesCopiedPhotoWhenVideoCopyFails() throws {
        let sources = try makeSourcePair()
        try FileManager.default.removeItem(at: sources.mov)

        XCTAssertThrowsError(
            try LivePhotoExporter().exportPair(
                heicURL: sources.heic,
                movURL: sources.mov,
                suggestedName: "Holiday",
                to: temporaryDirectory
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: temporaryDirectory.appendingPathComponent("Holiday Live Photo.heic").path
            )
        )
    }

    private func makeSourcePair() throws -> (heic: URL, mov: URL) {
        let sourceDirectory = temporaryDirectory.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(
            at: sourceDirectory,
            withIntermediateDirectories: true
        )
        let heicURL = sourceDirectory.appendingPathComponent("live.heic")
        let movURL = sourceDirectory.appendingPathComponent("live.mov")
        try Data("photo".utf8).write(to: heicURL)
        try Data("video".utf8).write(to: movURL)
        return (heicURL, movURL)
    }
}