import SwiftUI

struct SearchView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            if vm.searchResults.isEmpty && !vm.isLoading {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)

                    Text("搜索歌曲")
                        .font(.headline)

                    Text("输入关键词开始搜索")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)
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
                            .foregroundColor(.primary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("搜索")
        .searchable(text: $vm.searchKeyword, prompt: "搜索歌曲、歌手...")
        .onSubmit(of: .search) {
            Task { await vm.searchSongs() }
        }
        .overlay(
            Group {
                if vm.isLoading && vm.searchResults.isEmpty {
                    ProgressView("搜索中...")
                }
            }
        )
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
                .foregroundColor(.primary)
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(DemoViewModel.artistNames(from: song))
                    .font(.caption)
                    .foregroundColor(.secondary)

                let album = DemoViewModel.albumName(from: song)
                if !album.isEmpty {
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(album)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
