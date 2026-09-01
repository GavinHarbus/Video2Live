import Foundation

struct ExportedLivePhoto: Equatable {
    let heicURL: URL
    let movURL: URL
}

struct LivePhotoExporter {
    func exportPair(
        heicURL: URL,
        movURL: URL,
        suggestedName: String,
        to directoryURL: URL
    ) throws -> ExportedLivePhoto {
        let accessedSecurityScope = directoryURL.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                directoryURL.stopAccessingSecurityScopedResource()
            }
        }

        let baseName = uniqueBaseName(suggestedName: suggestedName, in: directoryURL)
        let destinationHEIC = directoryURL
            .appendingPathComponent(baseName)
            .appendingPathExtension("heic")
        let destinationMOV = directoryURL
            .appendingPathComponent(baseName)
            .appendingPathExtension("mov")

        do {
            try FileManager.default.copyItem(at: heicURL, to: destinationHEIC)
            do {
                try FileManager.default.copyItem(at: movURL, to: destinationMOV)
            } catch {
                try? FileManager.default.removeItem(at: destinationHEIC)
                throw error
            }
        } catch {
            throw V2LError.exportFailed(error.localizedDescription)
        }

        return ExportedLivePhoto(heicURL: destinationHEIC, movURL: destinationMOV)
    }

    private func uniqueBaseName(suggestedName: String, in directoryURL: URL) -> String {
        let trimmedName = suggestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let initialName = trimmedName.isEmpty ? "Live Photo" : "\(trimmedName) Live Photo"
        var candidate = initialName
        var suffix = 2

        while pairExists(named: candidate, in: directoryURL) {
            candidate = "\(initialName) \(suffix)"
            suffix += 1
        }
        return candidate
    }

    private func pairExists(named baseName: String, in directoryURL: URL) -> Bool {
        let heicURL = directoryURL.appendingPathComponent(baseName).appendingPathExtension("heic")
        let movURL = directoryURL.appendingPathComponent(baseName).appendingPathExtension("mov")
        return FileManager.default.fileExists(atPath: heicURL.path)
            || FileManager.default.fileExists(atPath: movURL.path)
    }
}