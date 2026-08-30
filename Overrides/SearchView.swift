import SwiftUI
import NeteaseCloudMusicAPI

struct SearchView: View {
    @ObservedObject var vm: DemoViewModel

    @State private var selectedType: SearchType = .single
    @State private var hotSearches: [[String: Any]] = []
    @State private var localResults: [[String: Any]] = []
    @State private var history: [String] = []
    @State private var loading = false
    @State private var message = ""

    private let types: [(SearchType, String)] = [
        (.single, "歌曲"),
        (.playlist, "歌单"),
        (.artist, "歌手")
    ]

    var body: some View {
        ZStack {
            Color(red: 10/255, green: 10/255, blue: 10/255).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if vm.searchKeyword.isEmpty {
                        historySection
                        hotSection
                    } else {
                        typePicker
                        resultSection
                    }

                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
            }
        }
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $vm.searchKeyword, prompt: "歌曲、歌单、歌手、MV")
        .onSubmit(of: .search) { performSearch() }
        .onChange(of: selectedType) { _ in
            if !vm.searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                performSearch()
            }
        }
        .task {
            loadHistory()
            await loadHot()
        }
    }

    private var typePicker: some View {
        HStack(spacing: 8) {
            ForEach(types, id: \.0.rawValue) { item in
                Button {
                    selectedType = item.0
                } label: {
                    Text(item.1)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selectedType == item.0 ? .black : .white)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(selectedType == item.0 ? Color.white : Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("搜索历史").font(.headline).foregroundColor(.white)
                Spacer()
                if !history.isEmpty {
                    Button("清空") {
                        history = []
                        UserDefaults.standard.removeObject(forKey: "ZMusicSearchHistory")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            if history.isEmpty {
                Text("还没有搜索记录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                FlexibleHistoryView(items: history) { keyword in
                    vm.searchKeyword = keyword
                    performSearch()
                }
            }
        }
    }

    private var hotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热搜榜").font(.headline).foregroundColor(.white)

            if hotSearches.isEmpty {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(hotSearches.prefix(20).enumerated()), id: \.offset) { index, item in
                        Button {
                            let word = hotWord(item)
                            guard !word.isEmpty else { return }
                            vm.searchKeyword = word
                            performSearch()
                        } label: {
                            HStack(spacing: 14) {
                                Text("\(index + 1)")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundColor(index < 3 ? .red : .secondary)
                                    .frame(width: 26, alignment: .leading)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(hotWord(item))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    if let content = item["content"] as? String, !content.isEmpty {
                                        Text(content).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                    }
                                }

                                Spacer()
                            }
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 14)
                .background(Color.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if loading {
                HStack {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("正在搜索").foregroundColor(.secondary)
                }
            } else if !message.isEmpty {
                Text(message).foregroundColor(.secondary)
            }

            ForEach(Array(localResults.enumerated()), id: \.offset) { _, item in
                resultRow(item)
            }
        }
    }

    @ViewBuilder
    private func resultRow(_ item: [String: Any]) -> some View {
        switch selectedType {
        case .single:
            Button { play(item) } label: {
                commonRow(
                    title: item["name"] as? String ?? "未知歌曲",
                    subtitle: DemoViewModel.artistNames(from: item),
                    icon: "music.note"
                )
            }
            .buttonStyle(PlainButtonStyle())

        case .playlist:
            NavigationLink(
                destination: PlaylistDetailView(
                    vm: vm,
                    playlistId: intValue(item["id"]),
                    playlistName: item["name"] as? String ?? "歌单"
                )
            ) {
                commonRow(
                    title: item["name"] as? String ?? "未知歌单",
                    subtitle: playlistSubtitle(item),
                    icon: "music.note.list"
                )
            }
            .buttonStyle(PlainButtonStyle())

        case .artist:
            NavigationLink(
                destination: ZMusicArtistDetailView(
                    vm: vm,
                    artistId: intValue(item["id"]),
                    artistName: item["name"] as? String ?? "歌手"
                )
            ) {
                commonRow(
                    title: item["name"] as? String ?? "未知歌手",
                    subtitle: "歌手",
                    icon: "person.wave.2"
                )
            }
            .buttonStyle(PlainButtonStyle())

        default:
            commonRow(title: item["name"] as? String ?? "结果", subtitle: "", icon: "magnifyingglass")
        }
    }

    private func commonRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 48, height: 48)
                Image(systemName: icon).foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }

            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.vertical, 4)
    }

    private func performSearch() {
        let keyword = vm.searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }

        saveHistory(keyword)
        loading = true
        message = ""

        Task {
            do {
                let response = try await vm.client.cloudsearch(
                    keywords: keyword,
                    type: selectedType,
                    limit: 50,
                    offset: 0
                )
                let result = response.body["result"] as? [String: Any] ?? [:]

                switch selectedType {
                case .single:
                    localResults = result["songs"] as? [[String: Any]] ?? []
                    vm.searchResults = localResults
                case .playlist:
                    localResults = result["playlists"] as? [[String: Any]] ?? []
                case .artist:
                    localResults = result["artists"] as? [[String: Any]] ?? []
                default:
                    localResults = []
                }

                if localResults.isEmpty {
                    message = "没有找到相关结果"
                }
            } catch {
                message = "搜索失败：\(error.localizedDescription)"
                localResults = []
            }
            loading = false
        }
    }

    private func loadHot() async {
        do {
            let response = try await vm.client.searchHotDetail()
            hotSearches = response.body["data"] as? [[String: Any]] ?? []
        } catch {
            hotSearches = []
        }
    }

    private func loadHistory() {
        history = UserDefaults.standard.stringArray(forKey: "ZMusicSearchHistory") ?? []
    }

    private func saveHistory(_ keyword: String) {
        var newHistory = history.filter { $0 != keyword }
        newHistory.insert(keyword, at: 0)
        history = Array(newHistory.prefix(15))
        UserDefaults.standard.set(history, forKey: "ZMusicSearchHistory")
    }

    private func hotWord(_ item: [String: Any]) -> String {
        item["searchWord"] as? String
            ?? item["first"] as? String
            ?? ""
    }

    private func playlistSubtitle(_ item: [String: Any]) -> String {
        if let count = item["trackCount"] as? Int { return "\(count) 首" }
        if let count = item["trackCount"] as? NSNumber { return "\(count.intValue) 首" }
        return "歌单"
    }


    private func intValue(_ value: Any?) -> Int {
        if let v = value as? Int { return v }
        if let v = value as? NSNumber { return v.intValue }
        if let v = value as? String { return Int(v) ?? 0 }
        return 0
    }

    private func play(_ song: [String: Any]) {
        let id = intValue(song["id"])
        guard id > 0 else { return }
        vm.testSongId = String(id)
        Task { await vm.testPlaySong() }
    }
}

private struct FlexibleHistoryView: View {
    let items: [String]
    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    action(item)
                } label: {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text(item)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color.white.opacity(0.055))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
