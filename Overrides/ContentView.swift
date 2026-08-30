import SwiftUI
import UIKit

private let studioBG = Color(red: 10.0 / 255.0, green: 10.0 / 255.0, blue: 10.0 / 255.0)
private let studioCard = Color(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 30.0 / 255.0)
private let studioSecondary = Color(red: 174.0 / 255.0, green: 174.0 / 255.0, blue: 178.0 / 255.0)
private let studioTertiary = Color(red: 99.0 / 255.0, green: 99.0 / 255.0, blue: 102.0 / 255.0)
private let studioRed = Color(red: 1.0, green: 59.0 / 255.0, blue: 48.0 / 255.0)

struct ContentView: View {
    @StateObject private var vm = DemoViewModel()
    @State private var showPlayer = false

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 10.0 / 255.0, green: 10.0 / 255.0, blue: 10.0 / 255.0, alpha: 0.96)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.05)

        let normal = UIColor(red: 99.0 / 255.0, green: 99.0 / 255.0, blue: 102.0 / 255.0, alpha: 1)
        let selected = UIColor.white

        appearance.stackedLayoutAppearance.normal.iconColor = normal
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normal]
        appearance.stackedLayoutAppearance.selected.iconColor = selected
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selected]

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some View {
        TabView {
            NavigationView {
                ZMusicHomeView(vm: vm)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "house.fill")
            }

            NavigationView {
                SearchView(vm: vm)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "magnifyingglass")
            }

            NavigationView {
                ToplistView(vm: vm)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "chart.bar.fill")
            }

            NavigationView {
                SettingsView(vm: vm)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "person.crop.circle")
            }
        }
        .accentColor(.white)
        .overlay(
            VStack {
                Spacer()

                if !vm.playSongName.isEmpty || vm.isPlayLoading {
                    MiniPlayerView(vm: vm) {
                        showPlayer = true
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 52)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: vm.playSongName)
        )
        .sheet(isPresented: $showPlayer) {
            NowPlayingView(vm: vm)
        }
        .preferredColorScheme(.dark)
    }
}

private struct ZMusicHomeView: View {
    @ObservedObject var vm: DemoViewModel
    @State private var loaded = false

    private let playlistColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            studioBG.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    fmCard
                    dailySection
                    playlistSection
                    chartShortcut

                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }
        }
        .navigationBarHidden(true)
        .task {
            guard !loaded else { return }
            loaded = true

            if vm.personalizedPlaylists.isEmpty {
                await vm.fetchPersonalized()
            }

            if vm.isLoggedIn && vm.dailyRecommendSongs.isEmpty {
                await vm.fetchDailyRecommendSongs()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)

                Text(vm.isLoggedIn ? "今日推荐已为你准备好" : "发现今天值得听的声音")
                    .font(.system(size: 14))
                    .foregroundColor(studioSecondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(studioCard)
                    .frame(width: 44, height: 44)

                Image(systemName: vm.isLoggedIn ? "person.fill" : "person")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    private var fmCard: some View {
        Button {
            Task {
                await vm.fetchPersonalFm()
                if let first = vm.personalFmSongs.first {
                    play(first)
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                studioRed.opacity(0.28),
                                Color.white.opacity(0.06),
                                studioCard
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(studioRed.opacity(0.18))
                            .frame(width: 64, height: 64)

                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 27, weight: .medium))
                            .foregroundColor(studioRed)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("私人 FM")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        Text(vm.isLoggedIn ? "根据你的口味实时推荐" : "登录后开启专属推荐")
                            .font(.system(size: 13))
                            .foregroundColor(studioSecondary)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(studioRed)
                            .frame(width: 44, height: 44)

                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    }
                }
                .padding(20)
            }
            .frame(height: 108)
        }
        .buttonStyle(StudioPressStyle())
    }

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("今日推荐")

            if vm.dailyRecommendSongs.isEmpty {
                emptyDaily
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.dailyRecommendSongs.prefix(5).enumerated()), id: \.offset) { index, song in
                        Button {
                            play(song)
                        } label: {
                            songRow(song, index: index)
                        }
                        .buttonStyle(StudioPressStyle())

                        if index < min(4, vm.dailyRecommendSongs.count - 1) {
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.leading, 46)
                        }
                    }
                }
            }
        }
    }

    private var emptyDaily: some View {
        Button {
            Task { await vm.fetchDailyRecommendSongs() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: vm.isLoggedIn ? "calendar" : "lock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(studioRed)

                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.isLoggedIn ? "加载每日推荐" : "登录后查看每日推荐")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(vm.isLoggedIn ? "网易云为你生成的今日歌单" : "在「我的」中完成扫码登录")
                        .font(.system(size: 13))
                        .foregroundColor(studioSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(studioTertiary)
            }
            .padding(16)
            .background(studioCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(StudioPressStyle())
        .disabled(!vm.isLoggedIn)
    }

    private func songRow(_ song: [String: Any], index: Int) -> some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundColor(studioTertiary)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(song["name"] as? String ?? "未知歌曲")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(DemoViewModel.artistNames(from: song))
                    .font(.system(size: 13))
                    .foregroundColor(studioSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "play.circle")
                .font(.system(size: 21))
                .foregroundColor(studioSecondary)
        }
        .frame(height: 64)
        .contentShape(Rectangle())
    }

    private var playlistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("为你推荐")
                Spacer()

                Button {
                    Task { await vm.fetchPersonalized() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(studioSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(StudioPressStyle())
            }

            if vm.personalizedPlaylists.isEmpty {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(studioCard)
                    .frame(height: 150)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            } else {
                LazyVGrid(columns: playlistColumns, spacing: 18) {
                    ForEach(Array(vm.personalizedPlaylists.prefix(6).enumerated()), id: \.offset) { _, playlist in
                        NavigationLink(
                            destination: PlaylistDetailView(
                                vm: vm,
                                playlistId: intValue(playlist["id"]),
                                playlistName: playlist["name"] as? String ?? "歌单"
                            )
                        ) {
                            playlistCard(playlist)
                        }
                        .buttonStyle(StudioPressStyle())
                    }
                }
            }
        }
    }

    private func playlistCard(_ playlist: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HomeArtwork(urlString: coverURL(playlist))
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.32), radius: 8, y: 4)

            Text(playlist["name"] as? String ?? "未知歌单")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)

            if let count = playCount(playlist), count > 0 {
                Text("▶ \(compactCount(count))")
                    .font(.system(size: 12))
                    .foregroundColor(studioTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chartShortcut: some View {
        NavigationLink(destination: ToplistView(vm: vm)) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 50, height: 50)

                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 20))
                        .foregroundColor(studioRed)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("排行榜")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("看看现在大家都在听什么")
                        .font(.system(size: 13))
                        .foregroundColor(studioSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(studioTertiary)
            }
            .padding(16)
            .background(studioCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(StudioPressStyle())
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .tracking(1.5)
            .foregroundColor(studioTertiary)
    }

    private var greeting: String {
        if vm.isLoggedIn && !vm.loginNickname.isEmpty {
            return "你好，\(vm.loginNickname)"
        }

        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:
            return "早上好"
        case 11..<14:
            return "中午好"
        case 14..<18:
            return "下午好"
        default:
            return "晚上好"
        }
    }

    private func play(_ song: [String: Any]) {
        let id = intValue(song["id"])
        guard id > 0 else { return }

        vm.testSongId = String(id)
        Task { await vm.testPlaySong() }
    }

    private func intValue(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) ?? 0 }
        return 0
    }

    private func coverURL(_ item: [String: Any]) -> String {
        if let url = item["picUrl"] as? String { return url }
        if let url = item["coverImgUrl"] as? String { return url }
        if let url = item["coverImgUrl"] as? NSString { return url as String }
        return ""
    }

    private func playCount(_ item: [String: Any]) -> Int? {
        if let value = item["playCount"] as? Int { return value }
        if let value = item["playcount"] as? Int { return value }
        if let value = item["playCount"] as? NSNumber { return value.intValue }
        return nil
    }

    private func compactCount(_ value: Int) -> String {
        if value >= 100_000_000 {
            return String(format: "%.1f亿", Double(value) / 100_000_000.0)
        }
        if value >= 10_000 {
            return String(format: "%.1f万", Double(value) / 10_000.0)
        }
        return "\(value)"
    }
}

private struct HomeArtwork: View {
    let urlString: String

    var body: some View {
        ZStack {
            studioCard

            if let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
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
                gradient: Gradient(colors: [studioRed.opacity(0.6), studioCard]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "music.note")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.white.opacity(0.75))
        }
    }
}

private struct StudioPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
