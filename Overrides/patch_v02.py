from pathlib import Path
import re

p = Path("upstream/Example/Sources/DemoViewModel.swift")
s = p.read_text(encoding="utf-8")

s = s.replace(
'''    init() {
        self.client = NCMClient()
        print("[NCMDemo] 客户端初始化完成")
    }''',
'''    init() {
        self.client = NCMClient()
        if let saved = ZMusicSessionStore.load(), !saved.isEmpty {
            self.client.setCookie(saved)
            self.cookie = saved
            Task { await self.fetchLoginStatus() }
        }
        print("[NCMDemo] 客户端初始化完成")
    }'''
)

s = s.replace(
'''                    print("[NCMDemo] 📋 Cookie: \(currentCookies.prefix(100))...")
                    // 自动获取用户信息
                    await fetchLoginStatus()''',
'''                    print("[NCMDemo] 📋 Cookie: \(currentCookies.prefix(100))...")
                    if !currentCookies.isEmpty {
                        ZMusicSessionStore.save(currentCookies)
                        cookie = currentCookies
                    }
                    await fetchLoginStatus()'''
)

s = s.replace(
'''            isLoggedIn = false
            loginNickname = ""
            qrImage = nil''',
'''            isLoggedIn = false
            loginNickname = ""
            qrImage = nil
            cookie = ""
            ZMusicSessionStore.delete()'''
)

s = re.sub(
r'''    func searchSongs\(\) async \{.*?\n    \}\n\n    func fetchLyric''',
'''    func searchSongs() async {
        let keyword = searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        searchResults = []

        do {
            let cloud = try await client.cloudsearch(keywords: keyword, type: .single, limit: 30)
            if let result = cloud.body["result"] as? [String: Any],
               let songs = result["songs"] as? [[String: Any]], !songs.isEmpty {
                searchResults = songs
            } else {
                let normal = try await client.search(keywords: keyword, type: .single, limit: 30)
                if let result = normal.body["result"] as? [String: Any],
                   let songs = result["songs"] as? [[String: Any]] {
                    searchResults = songs
                } else {
                    errorMessage = "未找到结果"
                }
            }
        } catch {
            do {
                let normal = try await client.search(keywords: keyword, type: .single, limit: 30)
                if let result = normal.body["result"] as? [String: Any],
                   let songs = result["songs"] as? [[String: Any]] {
                    searchResults = songs
                }
            } catch {
                errorMessage = "搜索失败: \(error.localizedDescription)"
            }
        }
        isLoading = false
    }

    func fetchLyric''',
s, count=1, flags=re.S)

s = re.sub(
r'''    func testPlaySong\(\) async \{.*?\n    \}\n\n    func stopPlaying\(\)''',
'''    func testPlaySong() async {
        guard let songId = Int(testSongId) else { return }
        isPlayLoading = true
        playStatus = "正在获取播放地址..."
        playUrl = ""

        do {
            let detail = try await client.songDetail(ids: [songId])
            if let songs = detail.body["songs"] as? [[String: Any]],
               let song = songs.first {
                let name = song["name"] as? String ?? "未知歌曲"
                let artist = DemoViewModel.artistNames(from: song)
                playSongName = artist.isEmpty ? name : "\(name) - \(artist)"
            }

            var urlString: String?

            let high = try await client.songUrlV1(ids: [songId], level: .exhigh)
            if let data = high.body["data"] as? [[String: Any]],
               let url = data.first?["url"] as? String, !url.isEmpty {
                urlString = url
            }

            if urlString == nil {
                let standard = try await client.songUrlV1(ids: [songId], level: .standard)
                if let data = standard.body["data"] as? [[String: Any]],
                   let url = data.first?["url"] as? String, !url.isEmpty {
                    urlString = url
                }
            }

            if urlString == nil {
                let legacy = try await client.songUrl(ids: [songId], br: 320000)
                if let data = legacy.body["data"] as? [[String: Any]],
                   let url = data.first?["url"] as? String, !url.isEmpty {
                    urlString = url
                }
            }

            guard let u = urlString, let url = URL(string: u) else {
                playStatus = "没有可用播放地址"
                isPlayLoading = false
                return
            }

            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer?.pause()
            audioPlayer = AVPlayer(playerItem: AVPlayerItem(url: url))
            audioPlayer?.play()
            playUrl = u
            isPlaying = true
            playStatus = "正在播放"
        } catch {
            playStatus = "播放失败: \(error.localizedDescription)"
            isPlaying = false
        }

        isPlayLoading = false
    }

    func stopPlaying()''',
s, count=1, flags=re.S)

p.write_text(s, encoding="utf-8")
print("patched")
