from pathlib import Path
import re

p = Path("upstream/Example/Sources/DemoViewModel.swift")
s = p.read_text(encoding="utf-8")

if "import MediaPlayer" not in s:
    s = s.replace("import AVFoundation", "import AVFoundation\nimport MediaPlayer", 1)

def must_replace(old, new, label):
    global s
    if old not in s:
        raise SystemExit(f"[v0.3] target not found: {label}")
    s = s.replace(old, new, 1)

must_replace(
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
        if let lastId = UserDefaults.standard.string(forKey: "ZMusicLastSongId"), !lastId.isEmpty {
            self.testSongId = lastId
        }
        setupRemoteCommands()
        print("[NCMDemo] 客户端初始化完成")
    }''',
"init"
)

must_replace(
'''                    print("[NCMDemo] 📋 Cookie: \\(currentCookies.prefix(100))...")
                    // 自动获取用户信息
                    await fetchLoginStatus()''',
'''                    print("[NCMDemo] 📋 Cookie: \\(currentCookies.prefix(100))...")
                    if !currentCookies.isEmpty {
                        ZMusicSessionStore.save(currentCookies)
                        cookie = currentCookies
                    }
                    await fetchLoginStatus()''',
"qr"
)

must_replace(
'''            isLoggedIn = false
            loginNickname = ""
            qrImage = nil''',
'''            isLoggedIn = false
            loginNickname = ""
            qrImage = nil
            cookie = ""
            ZMusicSessionStore.delete()''',
"logout"
)

must_replace(
'''    @Published var isPlaying: Bool = false
    @Published var isPlayLoading: Bool = false
    private var audioPlayer: AVPlayer?''',
'''    @Published var isPlaying: Bool = false
    @Published var isPlayLoading: Bool = false
    @Published var playArtistName: String = ""
    @Published var playArtworkURL: String = ""
    @Published var playCurrentTime: Double = 0
    @Published var playDuration: Double = 0
    struct ZMusicLyricLine: Identifiable {
        let id = UUID()
        let time: Double
        let text: String
    }

    @Published var playLyricLines: [String] = []
    @Published var playLyricTimeline: [ZMusicLyricLine] = []
    @Published var playQueue: [[String: Any]] = []
    @Published var playMode: Int = UserDefaults.standard.integer(forKey: "ZMusicPlayMode")
    @Published var downloadStatus: String = ""
    private var audioPlayer: AVPlayer?
    private var playTimeObserver: Any?''',
"player props"
)

s, n = re.subn(r'''    func testPlaySong\(\) async \{.*?\n    \}\n\n    func stopPlaying\(\)''', lambda _match: r'''    func testPlaySong() async {
        guard let songId = Int(testSongId) else { return }
        isPlayLoading = true
        playStatus = "正在获取播放地址..."
        playUrl = ""
        do {
            let detail = try await client.songDetail(ids: [songId])
            if let songs = detail.body["songs"] as? [[String: Any]], let song = songs.first {
                playSongName = song["name"] as? String ?? "未知歌曲"
                playArtistName = DemoViewModel.artistNames(from: song)
                if let album = song["al"] as? [String: Any] {
                    playArtworkURL = album["picUrl"] as? String ?? ""
                }
                zMusicEnqueueCurrentSong(song)
            }
            var urlString: String?
            let high = try await client.songUrlV1(ids: [songId], level: .exhigh)
            if let data = high.body["data"] as? [[String: Any]], let url = data.first?["url"] as? String, !url.isEmpty { urlString = url }
            if urlString == nil {
                let standard = try await client.songUrlV1(ids: [songId], level: .standard)
                if let data = standard.body["data"] as? [[String: Any]], let url = data.first?["url"] as? String, !url.isEmpty { urlString = url }
            }
            if urlString == nil {
                let legacy = try await client.songUrl(ids: [songId], br: 320000)
                if let data = legacy.body["data"] as? [[String: Any]], let url = data.first?["url"] as? String, !url.isEmpty { urlString = url }
            }
            guard let u = urlString, let url = URL(string: u) else {
                playStatus = "没有可用播放地址"; isPlayLoading = false; return
            }
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            if let observer = playTimeObserver { audioPlayer?.removeTimeObserver(observer); playTimeObserver = nil }
            audioPlayer?.pause()
            let player = AVPlayer(playerItem: AVPlayerItem(url: url))
            audioPlayer = player
            let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
            playTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                guard let self = self else { return }
                if time.seconds.isFinite { self.playCurrentTime = max(0, time.seconds) }
                let duration = player.currentItem?.duration.seconds ?? 0
                if duration.isFinite && duration > 0 { self.playDuration = duration }
                self.updateNowPlayingInfo()
            }
            player.play()
            playUrl = u
            isPlaying = true
            playStatus = "正在播放"
            playCurrentTime = 0
            UserDefaults.standard.set(testSongId, forKey: "ZMusicLastSongId")
            updateNowPlayingInfo()
            do {
                let lyricResp = try await client.lyric(id: songId)
                let raw =
                    (lyricResp.body["lrc"] as? [String: Any])?["lyric"] as? String
                    ?? (lyricResp.body["klyric"] as? [String: Any])?["lyric"] as? String
                    ?? ""

                var timeline: [ZMusicLyricLine] = []
                let timeRegex = try NSRegularExpression(
                    pattern: #"\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]"#
                )

                for sourceLine in raw.components(separatedBy: .newlines) {
                    let nsRange = NSRange(sourceLine.startIndex..<sourceLine.endIndex, in: sourceLine)
                    let matches = timeRegex.matches(in: sourceLine, range: nsRange)
                    guard !matches.isEmpty else { continue }

                    let lyricText = timeRegex
                        .stringByReplacingMatches(
                            in: sourceLine,
                            range: nsRange,
                            withTemplate: ""
                        )
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !lyricText.isEmpty else { continue }

                    for match in matches {
                        guard
                            let minuteRange = Range(match.range(at: 1), in: sourceLine),
                            let secondRange = Range(match.range(at: 2), in: sourceLine)
                        else { continue }

                        let minutes = Double(sourceLine[minuteRange]) ?? 0
                        let seconds = Double(sourceLine[secondRange]) ?? 0

                        var fraction = 0.0
                        if match.range(at: 3).location != NSNotFound,
                           let fractionRange = Range(match.range(at: 3), in: sourceLine) {
                            let rawFraction = String(sourceLine[fractionRange])
                            let value = Double(rawFraction) ?? 0
                            switch rawFraction.count {
                            case 1: fraction = value / 10
                            case 2: fraction = value / 100
                            default: fraction = value / 1000
                            }
                        }

                        timeline.append(
                            ZMusicLyricLine(
                                time: minutes * 60 + seconds + fraction,
                                text: lyricText
                            )
                        )
                    }
                }

                playLyricTimeline = timeline.sorted { $0.time < $1.time }
                playLyricLines = playLyricTimeline.map { $0.text }

                if playLyricTimeline.isEmpty {
                    playLyricLines = raw.components(separatedBy: .newlines).compactMap { line in
                        let cleaned = line
                            .replacingOccurrences(
                                of: #"\[[^\]]+\]"#,
                                with: "",
                                options: .regularExpression
                            )
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        return cleaned.isEmpty ? nil : cleaned
                    }
                }
            } catch {
                playLyricLines = []
                playLyricTimeline = []
            }
        } catch {
            playStatus = "播放失败: \\(error.localizedDescription)"
            isPlaying = false
        }
        isPlayLoading = false
    }

    func togglePlayback() {
        guard let player = audioPlayer else { Task { await testPlaySong() }; return }
        if isPlaying { player.pause(); isPlaying = false; playStatus = "已暂停" }
        else { player.play(); isPlaying = true; playStatus = "正在播放" }
        updateNowPlayingInfo()
    }

    func seek(to seconds: Double) {
        guard let player = audioPlayer else { return }
        let maxValue = playDuration > 0 ? playDuration : seconds
        let safe = max(0, min(seconds, maxValue))
        player.seek(to: CMTime(seconds: safe, preferredTimescale: 600))
        playCurrentTime = safe
        updateNowPlayingInfo()
    }

    func restartCurrentTrack() {
        seek(to: 0)
        if !isPlaying { audioPlayer?.play(); isPlaying = true; playStatus = "正在播放" }
    }

    func zMusicEnqueueCurrentSong(_ song: [String: Any]) {
        guard let id = song["id"] as? Int ?? (song["id"] as? NSNumber)?.intValue else { return }
        if !playQueue.contains(where: {
            (($0["id"] as? Int) ?? ($0["id"] as? NSNumber)?.intValue) == id
        }) {
            playQueue.append(song)
        }
    }

    func zMusicPlayQueueItem(at index: Int) {
        guard !playQueue.isEmpty else { return }
        let safe = max(0, min(index, playQueue.count - 1))
        let song = playQueue[safe]
        let id = (song["id"] as? Int) ?? (song["id"] as? NSNumber)?.intValue ?? 0
        guard id > 0 else { return }
        testSongId = String(id)
        Task { await testPlaySong() }
    }

    func zMusicNextTrack() {
        guard !playQueue.isEmpty else { return }
        let current = Int(testSongId) ?? 0
        let index = playQueue.firstIndex {
            (($0["id"] as? Int) ?? ($0["id"] as? NSNumber)?.intValue ?? 0) == current
        } ?? 0

        if playMode == 1 {
            zMusicPlayQueueItem(at: index)
        } else if playMode == 2 {
            zMusicPlayQueueItem(at: Int.random(in: 0..<playQueue.count))
        } else {
            zMusicPlayQueueItem(at: (index + 1) % playQueue.count)
        }
    }

    func zMusicPreviousTrack() {
        guard !playQueue.isEmpty else { restartCurrentTrack(); return }
        let current = Int(testSongId) ?? 0
        let index = playQueue.firstIndex {
            (($0["id"] as? Int) ?? ($0["id"] as? NSNumber)?.intValue ?? 0) == current
        } ?? 0
        zMusicPlayQueueItem(at: (index - 1 + playQueue.count) % playQueue.count)
    }

    func zMusicCyclePlayMode() {
        playMode = (playMode + 1) % 3
        UserDefaults.standard.set(playMode, forKey: "ZMusicPlayMode")
    }

    func updateNowPlayingInfo() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = playSongName
        info[MPMediaItemPropertyArtist] = playArtistName
        info[MPMediaItemPropertyPlaybackDuration] = playDuration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playCurrentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if !self.isPlaying { self.togglePlayback() }
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.isPlaying { self.togglePlayback() }
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.zMusicNextTrack() }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.zMusicPreviousTrack() }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in self?.seek(to: positionEvent.positionTime) }
            return .success
        }
    }

    func zMusicDownloadCurrentSong() async {
        guard let url = URL(string: playUrl), !playUrl.isEmpty else {
            downloadStatus = "当前歌曲没有可下载地址"
            return
        }

        downloadStatus = "正在下载..."
        do {
            let (temporaryURL, _) = try await URLSession.shared.download(from: url)
            let fm = FileManager.default
            let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let folder = documents.appendingPathComponent("ZMusic Downloads", isDirectory: true)

            if !fm.fileExists(atPath: folder.path) {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            }

            let safeName = playSongName
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let filename = safeName.isEmpty ? "ZMusic-\(testSongId).m4a" : "\(safeName).m4a"
            let target = folder.appendingPathComponent(filename)

            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
            try fm.moveItem(at: temporaryURL, to: target)
            downloadStatus = "已保存：\(filename)"
        } catch {
            downloadStatus = "下载失败：\(error.localizedDescription)"
        }
    }

    func stopPlaying()''', s, count=1, flags=re.S)
if n != 1:
    raise SystemExit("[v0.3] playback target not found")

p.write_text(s, encoding="utf-8")
print("[v0.3] patched")
