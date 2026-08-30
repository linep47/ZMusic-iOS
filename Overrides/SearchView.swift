import SwiftUI

struct SearchView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            ForEach(Array(vm.searchResults.enumerated()), id: \.offset) { _, song in
                Button(action: { play(song) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song["name"] as? String ?? "未知歌曲")
                            .foregroundColor(.primary)
                        Text(DemoViewModel.artistNames(from: song))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            if let error = vm.errorMessage {
                Text(error).foregroundColor(.red)
            }
        }
        .navigationTitle("搜索")
        .searchable(text: $vm.searchKeyword, prompt: "搜索歌曲")
        .onSubmit(of: .search) {
            Task { await vm.searchSongs() }
        }
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
