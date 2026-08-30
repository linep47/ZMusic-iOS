import SwiftUI

struct PlaylistView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            ForEach(Array(vm.hotPlaylists.enumerated()), id: \.offset) { _, playlist in
                NavigationLink(
                    destination: PlaylistDetailView(
                        vm: vm,
                        playlistId: intValue(playlist["id"]),
                        playlistName: playlist["name"] as? String ?? ""
                    )
                ) {
                    Text(playlist["name"] as? String ?? "未知歌单")
                }
            }
        }
        .navigationTitle("歌单")
        .task { await vm.fetchHotPlaylists() }
    }

    private func intValue(_ value: Any?) -> Int {
        if let v = value as? Int { return v }
        if let v = value as? NSNumber { return v.intValue }
        if let v = value as? String { return Int(v) ?? 0 }
        return 0
    }
}

struct PlaylistDetailView: View {
    @ObservedObject var vm: DemoViewModel
    let playlistId: Int
    let playlistName: String

    var body: some View {
        List(Array(vm.playlistTracks.enumerated()), id: \.offset) { index, track in
            Button(action: { play(track) }) {
                HStack {
                    Text("\(index + 1)")
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading) {
                        Text(track["name"] as? String ?? "未知歌曲")
                            .foregroundColor(.primary)
                        Text(DemoViewModel.artistNames(from: track))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "play.circle")
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .navigationTitle(playlistName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.fetchPlaylistDetail(id: playlistId, name: playlistName) }
    }

    private func play(_ song: [String: Any]) {
        var id = 0
        if let v = song["id"] as? Int { id = v }
        else if let v = song["id"] as? NSNumber { id = v.intValue }
        else if let v = song["id"] as? String { id = Int(v) ?? 0 }
        guard id > 0 else { return }
        vm.testSongId = String(id)
        Task { await vm.testPlaySong() }
    }
}
