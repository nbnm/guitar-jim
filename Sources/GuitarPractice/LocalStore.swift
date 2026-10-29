import Foundation
import GuitarPracticeCore

@MainActor
final class LocalStore: ObservableObject {
    @Published var songs: [SongArrangement] = []
    @Published var sessions: [CaptureSession] = []
    @Published var error: String?
    let root: URL
    let encoder: JSONEncoder = {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return encoder
    }()
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GuitarJim", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.root.appendingPathComponent("Arrangements"), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: self.root.appendingPathComponent("Sessions"), withIntermediateDirectories: true)
            let files = try FileManager.default.contentsOfDirectory(at: self.root.appendingPathComponent("Arrangements"), includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
            for file in files {
                do { songs.append(try JSONDecoder().decode(SongArrangement.self, from: Data(contentsOf: file))) }
                catch { self.error = "An arrangement could not be opened. Its file has been preserved: \(file.lastPathComponent)." }
            }
            for builtIn in PracticeCatalog.songs + [RequestedSongs.withOrWithoutYou] + PopularSongCatalog.songs {
                // Preserve existing arrangements and edits; attach level metadata to
                // the original prototype study rather than creating a duplicate.
                if let existing = songs.firstIndex(where: { $0.title == builtIn.title && $0.artist == builtIn.artist }) {
                    if songs[existing].difficulty == nil && songs[existing].revision == 1 {
                        var updated = songs[existing]; updated.difficulty = builtIn.difficulty
                        try saveSong(updated)
                    }
                } else if !songs.contains(where: { $0.id == builtIn.id }) { try saveSong(builtIn) }
            }
            songs.sort {
                let left = $0.difficulty?.level ?? 99, right = $1.difficulty?.level ?? 99
                return left == right ? $0.title.localizedStandardCompare($1.title) == .orderedAscending : left < right
            }
            reloadSessions()
        } catch { self.error = "Local storage could not be opened: \(error.localizedDescription)" }
    }
    func saveSong(_ song: SongArrangement) throws {
        guard song.sources.allSatisfy(\.permitsOfflineStorage) else {
            throw NSError(domain: "GuitarJim", code: 1, userInfo: [NSLocalizedDescriptionKey: "Confirm permission to store this material locally before saving."])
        }
        let path = root.appendingPathComponent("Arrangements/\(song.id).json")
        try encoder.encode(song).write(to: path, options: .atomic)
        if let index = songs.firstIndex(where: { $0.id == song.id }) { songs[index] = song }
        else { songs.append(song) }
    }
    func sessionDirectory(_ id: UUID) -> URL { root.appendingPathComponent("Sessions/\(id)", isDirectory: true) }
    func reloadSessions() {
        do {
            let directories = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Sessions"), includingPropertiesForKeys: nil)
            var loaded: [CaptureSession] = []
            for directory in directories {
                let manifest = directory.appendingPathComponent("session.json")
                guard FileManager.default.fileExists(atPath: manifest.path) else { continue }
                do {
                    var session = try JSONDecoder().decode(CaptureSession.self, from: Data(contentsOf: manifest))
                    if session.state == "recording" {
                        session.state = "recovered"
                        session.fault = "Capture was interrupted. Finalized chunks are preserved; the last unfinished chunk may be unavailable. Restart the mic explicitly."
                        try encoder.encode(session).write(to: manifest, options: .atomic)
                    }
                    loaded.append(session)
                } catch { self.error = "A recording manifest could not be read. The audio is preserved in \(directory.lastPathComponent)." }
            }
            sessions = loaded.sorted { $0.startedAt > $1.startedAt }
        } catch { self.error = "Could not list recordings: \(error.localizedDescription)" }
    }
    func updateSession(_ session: CaptureSession) throws {
        try encoder.encode(session).write(to: sessionDirectory(session.id).appendingPathComponent("session.json"), options: .atomic)
        if let i = sessions.firstIndex(where: { $0.id == session.id }) { sessions[i] = session }
    }
    func deleteSession(_ session: CaptureSession) throws {
        try FileManager.default.removeItem(at: sessionDirectory(session.id))
        sessions.removeAll { $0.id == session.id }
    }
    var storageDescription: String {
        let bytes = sessions.flatMap(\.segments).reduce(0.0) { $0 + Double($1.sampleCount) * 4 }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
