import SwiftUI
import NeteaseCloudMusicAPI

struct PlaylistView: View {
    @ObservedObject var vm: DemoViewModel
    @State private var showCreate = false
    @State private var newName = ""
    @State private var message = ""

    var body: some View {
        List {
            if !message.isEmpty {
                Text(message).font(.caption).foregroundColor(.secondary)
            }

            ForEach(Array(vm.userPlaylists.enumerated()), id: \.offset) { _, playlist in
                NavigationLink(
                    destination: PlaylistDetailView(
                        vm: vm,
                        playlistId: intValue(playlist["id"]),
                        playlistName: playlist["name"] as? String ?? ""
                    )
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist["name"] as? String ?? "未知歌单")
                        if let count = intOptional(playlist["trackCount"]) {
                            Text("\(count) 首").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deletePlaylist(intValue(playlist["id"]))
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("我的歌单")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("新建歌单", isPresented: $showCreate) {
            TextField("歌单名称", text: $newName)
            Button("取消", role: .cancel) {}
            Button("创建") { createPlaylist() }
        }
        .task {
            await vm.zMusicSyncLibrary()
        }
    }

    private func createPlaylist() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Task {
            do {
                _ = try await vm.client.playlistCreate(name: name)
                newName = ""
                await vm.zMusicSyncLibrary()
                message = "已创建歌单"
            } catch {
                message = "创建失败：\(error.localizedDescription)"
            }
        }
    }

    private func deletePlaylist(_ id: Int) {
        guard id > 0 else { return }
        Task {
            do {
                _ = try await vm.client.playlistDelete(ids: [id])
                await vm.zMusicSyncLibrary()
                message = "已删除歌单"
            } catch {
                message = "删除失败：\(error.localizedDescription)"
            }
        }
    }

    private func intValue(_ value: Any?) -> Int {
        intOptional(value) ?? 0
    }

    private func intOptional(_ value: Any?) -> Int? {
        if let v = value as? Int { return v }
        if let v = value as? NSNumber { return v.intValue }
        if let v = value as? String { return Int(v) }
        return nil
    }
}

struct PlaylistDetailView: View {
    @ObservedObject var vm: DemoViewModel
    let playlistId: Int
    let playlistName: String

    @State private var showRename = false
    @State private var newName = ""
    @State private var showAddSong = false
    @State private var songIdText = ""
    @State private var message = ""
    @State private var subscribed = false

    var body: some View {
        List {
            if !message.isEmpty {
                Text(message).font(.caption).foregroundColor(.secondary)
            }

            ForEach(Array(vm.playlistTracks.enumerated()), id: \.offset) { index, track in
                Button(action: { play(track) }) {
                    HStack {
                        Text("\(index + 1)")
                            .foregroundColor(.secondary)
                            .frame(width: 28, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(track["name"] as? String ?? "未知歌曲")
                                .foregroundColor(.primary)
                            Text(DemoViewModel.artistNames(from: track))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Menu {
                            Button {
                                vm.zMusicEnqueueCurrentSong(track)
                            } label: {
                                Label("加入播放队列", systemImage: "text.badge.plus")
                            }

                            Button(role: .destructive) {
                                removeTrack(track)
                            } label: {
                                Label("从歌单移除", systemImage: "minus.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.secondary)
                                .frame(width: 36, height: 36)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle(playlistName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button { showRename = true } label: {
                        Label("重命名", systemImage: "pencil")
                    }

                    Button { showAddSong = true } label: {
                        Label("添加歌曲", systemImage: "plus")
                    }

                    Button {
                        toggleSubscribe()
                    } label: {
                        Label(
                            subscribed ? "取消收藏" : "收藏歌单",
                            systemImage: subscribed ? "star.slash" : "star"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("重命名歌单", isPresented: $showRename) {
            TextField("新名称", text: $newName)
            Button("取消", role: .cancel) {}
            Button("保存") { renamePlaylist() }
        }
        .alert("添加歌曲", isPresented: $showAddSong) {
            TextField("歌曲 ID", text: $songIdText)
                .keyboardType(.numberPad)
            Button("取消", role: .cancel) {}
            Button("添加") { addSongById() }
        }
        .task { await vm.fetchPlaylistDetail(id: playlistId, name: playlistName) }
    }

    private func play(_ song: [String: Any]) {
        let id = intValue(song["id"])
        guard id > 0 else { return }
        vm.testSongId = String(id)
        vm.zMusicEnqueueCurrentSong(song)
        Task { await vm.testPlaySong() }
    }

    private func removeTrack(_ track: [String: Any]) {
        let id = intValue(track["id"])
        guard id > 0 else { return }
        Task {
            do {
                _ = try await vm.client.playlistTracks(op: "del", pid: playlistId, trackIds: [id])
                await vm.fetchPlaylistDetail(id: playlistId, name: playlistName)
                message = "已从歌单移除"
            } catch {
                message = "移除失败：\(error.localizedDescription)"
            }
        }
    }

    private func addSongById() {
        let songId = Int(songIdText) ?? 0
        guard songId > 0 else { return }
        Task {
            do {
                _ = try await vm.client.playlistTracks(op: "add", pid: playlistId, trackIds: [songId])
                songIdText = ""
                await vm.fetchPlaylistDetail(id: playlistId, name: playlistName)
                message = "已添加歌曲"
            } catch {
                message = "添加失败：\(error.localizedDescription)"
            }
        }
    }

    private func renamePlaylist() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Task {
            do {
                _ = try await vm.client.playlistNameUpdate(id: playlistId, name: name)
                newName = ""
                message = "歌单已重命名"
            } catch {
                message = "重命名失败：\(error.localizedDescription)"
            }
        }
    }

    private func toggleSubscribe() {
        Task {
            do {
                let action: SubAction = subscribed ? .unsub : .sub
                _ = try await vm.client.playlistSubscribe(id: playlistId, action: action)
                subscribed.toggle()
                message = subscribed ? "已收藏歌单" : "已取消收藏"
            } catch {
                message = "操作失败：\(error.localizedDescription)"
            }
        }
    }

    private func intValue(_ value: Any?) -> Int {
        if let v = value as? Int { return v }
        if let v = value as? NSNumber { return v.intValue }
        if let v = value as? String { return Int(v) ?? 0 }
        return 0
    }
}

struct ZMusicArtistDetailView: View {
    @ObservedObject var vm: DemoViewModel
    let artistId: Int
    let artistName: String

    @State private var songs: [[String: Any]] = []
    @State private var descriptionText = ""
    @State private var loading = true
    @State private var followed = false
    @State private var message = ""

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(artistName)
                        .font(.title2.bold())

                    if !descriptionText.isEmpty {
                        Text(descriptionText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(5)
                    }

                    HStack {
                        Button(followed ? "取消收藏" : "收藏歌手") {
                            toggleFollow()
                        }
                        .buttonStyle(.bordered)

                        if !message.isEmpty {
                            Text(message).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section("热门歌曲") {
                if loading {
                    ProgressView()
                }

                ForEach(Array(songs.enumerated()), id: \.offset) { _, song in
                    Button {
                        play(song)
                    } label: {
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
            }
        }
        .navigationTitle("歌手")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard artistId > 0 else { loading = false; return }

        do {
            let songsResp = try await vm.client.artistTopSong(id: artistId)
            songs = songsResp.body["songs"] as? [[String: Any]] ?? []

            let descResp = try await vm.client.artistDesc(id: artistId)
            if let brief = descResp.body["briefDesc"] as? String {
                descriptionText = brief
            }
        } catch {
            message = "加载失败"
        }

        loading = false
    }

    private func toggleFollow() {
        Task {
            do {
                let action: SubAction = followed ? .unsub : .sub
                _ = try await vm.client.artistSub(id: artistId, action: action)
                followed.toggle()
                message = followed ? "已收藏" : "已取消"
            } catch {
                message = "操作失败"
            }
        }
    }

    private func play(_ song: [String: Any]) {
        let id: Int
        if let v = song["id"] as? Int { id = v }
        else if let v = song["id"] as? NSNumber { id = v.intValue }
        else { id = 0 }

        guard id > 0 else { return }
        vm.testSongId = String(id)
        vm.zMusicEnqueueCurrentSong(song)
        Task { await vm.testPlaySong() }
    }
}
