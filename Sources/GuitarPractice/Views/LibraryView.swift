import SwiftUI
import GuitarPracticeCore

struct LibraryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: LocalStore
    @State private var search = ""
    private var filteredSongs: [SongArrangement] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? store.songs : store.songs.filter { "\($0.title) \($0.artist)".localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Song library").font(Theme.title(38))
                    Text("Choose your level. Build your groove.").font(Theme.body()).foregroundStyle(Theme.muted)
                }
                Spacer()
                Button { model.showImporter = true } label: { Label("Add a song", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle()).disabled(model.isRecording)
            }
            Divider().overlay(Theme.line)
            HStack {
                TextField("Search songs or artists", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 330)
                Spacer()
                Text("\(filteredSongs.count) SONGS").font(Theme.strong(10)).tracking(1).foregroundStyle(Theme.muted)
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredSongs) { song in
                        Button { model.selectSong(song) } label: {
                            HStack(spacing: 22) {
                                Text(song.difficulty.map { String(format: "%02d", $0.level) } ?? "♪").font(Theme.title(34)).foregroundStyle(Theme.accent).frame(width: 54, height: 54).background(Theme.sidebar, in: RoundedRectangle(cornerRadius: 5))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(song.title).font(Theme.strong(17))
                                    Text(song.artist).font(Theme.strong(11)).foregroundStyle(Theme.accent)
                                    Text((song.version.localizedCaseInsensitiveContains("simplified") ? "Study · " : "") + song.practiceDescription).font(Theme.body(12)).foregroundStyle(Theme.muted)
                                    Text("\(Int(song.practiceBPM)) BPM  ·  \(song.bars.count) bars  ·  \(song.readiness.rawValue)").font(Theme.body(11)).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                if let level = song.difficulty {
                                    HStack(spacing: 3) { ForEach(1...5, id: \.self) { i in Image(systemName: i <= level.level ? "star.fill" : "star").font(.system(size: 10)).foregroundStyle(i <= level.level ? Theme.accent : Theme.line) } }
                                }
                                Image(systemName: "arrow.up.right").foregroundStyle(Theme.accent)
                            }.padding(.vertical, 6).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider().overlay(Theme.line)
                    }
                }
                if filteredSongs.isEmpty { Text("No songs match. Try a title or artist.").font(Theme.body()).foregroundStyle(Theme.muted).padding(30) }
            }
            Text("Five originals, U2 and \(PopularSongCatalog.songs.count) popular-song studies. Popular studies are simplified chord-only loops with source links; open the editor to inspect their versions and strumming.")
                .font(Theme.body(12)).foregroundStyle(Theme.muted).frame(maxWidth: 640, alignment: .leading)
        }.padding(.horizontal, 36).padding(.bottom, 32)
    }
}
