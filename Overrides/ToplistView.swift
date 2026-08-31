import SwiftUI

struct ToplistView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        ZStack {
            Color(red: 10/255, green: 10/255, blue: 10/255)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(Array(vm.toplists.enumerated()), id: \.offset) { index, item in
                        NavigationLink(
                            destination: PlaylistDetailView(
                                vm: vm,
                                playlistId: intValue(item["id"]),
                                playlistName: item["name"] as? String ?? "排行榜"
                            )
                        ) {
                            MuseToplistCard(
                                vm: vm,
                                item: item,
                                rank: index + 1
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
        }
        .navigationTitle("热榜")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.fetchToplists() }
    }

    private func intValue(_ value: Any?) -> Int {
        if let v = value as? Int { return v }
        if let v = value as? NSNumber { return v.intValue }
        if let v = value as? String { return Int(v) ?? 0 }
        return 0
    }
}

private struct MuseToplistCard: View {
    @ObservedObject var vm: DemoViewModel
    let item: [String: Any]
    let rank: Int

    @State private var previewSongs: [[String: Any]] = []

    var body: some View {
        HStack(spacing: 15) {
            ZStack(alignment: .topLeading) {
                artwork
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(String(format: "%02d", rank))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Color.black.opacity(0.62))
                    .clipShape(Capsule())
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(item["name"] as? String ?? "未知榜单")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(item["updateFrequency"] as? String ?? "实时更新")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)

                if previewSongs.isEmpty {
                    Text("点击查看完整榜单")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(previewSongs.prefix(3).enumerated()), id: \.offset) { index, song in
                        Text("\(index + 1). \(song["name"] as? String ?? "未知歌曲") · \(DemoViewModel.artistNames(from: song))")
                            .font(.system(size: 12))
                            .foregroundColor(index == 0 ? .white : .secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(height: 136)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        )
        .task {
            let id = intValue(item["id"])
            guard id > 0, previewSongs.isEmpty else { return }
            do {
                let response = try await vm.client.playlistTrackAll(id: id, limit: 3, offset: 0)
                previewSongs = response.body["songs"] as? [[String: Any]] ?? []
            } catch {
                previewSongs = []
            }
        }
    }

    private var artwork: some View {
        Group {
            if let urlString = coverURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.red.opacity(0.55),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 34))
                .foregroundColor(.white.opacity(0.86))
        }
    }

    private var coverURL: String? {
        item["coverImgUrl"] as? String
            ?? item["coverUrl"] as? String
            ?? item["picUrl"] as? String
    }

    private func intValue(_ value: Any?) -> Int {
        if let v = value as? Int { return v }
        if let v = value as? NSNumber { return v.intValue }
        if let v = value as? String { return Int(v) ?? 0 }
        return 0
    }
}
