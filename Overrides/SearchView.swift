import SwiftUI

struct SearchView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            if vm.searchResults.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    "搜索歌曲",
                    systemImage: "magnifyingglass",
                    description: Text("输入关键词开始搜索")
                )
            }

            ForEach(Array(vm.searchResults.enumerated()), id: \.offset) { _, song in
                Button {
                    play(song)
                } label: {
                    HStack(spacing: 12) {
                        SongRow(song: song)

                        Spacer()

                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle("搜索")
        .searchable(text: $vm.searchKeyword, prompt: "搜索歌曲、歌手...")
        .onSubmit(of: .search) {
            Task { await vm.searchSongs() }
        }
        .overlay {
            if vm.isLoading && vm.searchResults.isEmpty {
                ProgressView("搜索中...")
            }
        }
    }

    private func play(_ song: [String: Any]) {
        guard let id = song["id"] as? Int else { return }
        vm.testSongId = String(id)
        Task {
            await vm.testPlaySong()
        }
    }
}

struct SongRow: View {
    let song: [String: Any]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(song["name"] as? String ?? "未知歌曲")
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(DemoViewModel.artistNames(from: song))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let album = DemoViewModel.albumName(from: song)
                if !album.isEmpty {
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
