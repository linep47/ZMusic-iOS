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
        appearance.backgroundColor = UIColor(
            red: 10.0 / 255.0,
            green: 10.0 / 255.0,
            blue: 10.0 / 255.0,
            alpha: 0.96
        )
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.05)

        let normal = UIColor(
            red: 99.0 / 255.0,
            green: 99.0 / 255.0,
            blue: 102.0 / 255.0,
            alpha: 1
        )
        let selected = UIColor.white

        appearance.stackedLayoutAppearance.normal.iconColor = normal
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normal
        ]
        appearance.stackedLayoutAppearance.selected.iconColor = selected
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selected
        ]

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some View {
        Group {
            if vm.isLoggedIn {
                mainInterface
                    .transition(.opacity)
            } else {
                ZMusicLoginGateView(vm: vm)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: vm.isLoggedIn)
        .preferredColorScheme(.dark)
    }

    private var mainInterface: some View {
        TabView {
            NavigationView {
                ZMusicHomeView(vm: vm)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("首页", systemImage: "house.fill")
            }

            NavigationView {
                SearchView(vm: vm)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("搜索", systemImage: "magnifyingglass")
            }

            NavigationView {
                ToplistView(vm: vm)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("热榜", systemImage: "chart.bar.fill")
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
            .animation(
                .spring(response: 0.42, dampingFraction: 0.82),
                value: vm.playSongName
            )
        )
        .sheet(isPresented: $showPlayer) {
            NowPlayingView(vm: vm)
        }
    }
}

// MARK: - 登录与账号同步

private enum ZMusicLoginMode: String, CaseIterable {
    case qr = "扫码"
    case captcha = "验证码"
    case password = "密码"
}

extension DemoViewModel {
    /// 登录成功后保存当前会话，并同步登录状态和账号歌单。
    func zMusicFinishLogin() async {
        let savedCookie = currentCookies
        if !savedCookie.isEmpty {
            ZMusicSessionStore.save(savedCookie)
            cookie = savedCookie
        }
        await fetchLoginStatus()
        if isLoggedIn {
            await zMusicSyncLibrary()
        }
    }

    /// 同步账号歌单；其中包括账号创建/收藏的歌单以及“我喜欢的音乐”。
    func zMusicSyncLibrary() async {
        do {
            let status = try await client.loginStatus()
            let profile = status.body["profile"] as? [String: Any]
            let account = status.body["account"] as? [String: Any]

            let uid =
                Self.zMusicInt(profile?["userId"]) ??
                Self.zMusicInt(profile?["userID"]) ??
                Self.zMusicInt(profile?["id"]) ??
                Self.zMusicInt(account?["id"])

            guard let uid = uid, uid > 0 else { return }

            userIdInput = String(uid)
            let response = try await client.userPlaylist(uid: uid, limit: 100, offset: 0)
            if let playlists = response.body["playlist"] as? [[String: Any]] {
                userPlaylists = playlists
            }
        } catch {
            print("[ZMusic] 同步账号歌单失败: \(error)")
        }
    }

    private static func zMusicInt(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}

private struct ZMusicLoginGateView: View {
    @ObservedObject var vm: DemoViewModel

    @State private var mode: ZMusicLoginMode = .qr
    @State private var countryCode = "86"
    @State private var phone = ""
    @State private var password = ""
    @State private var captcha = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var isSendingCaptcha = false

    var body: some View {
        ZStack {
            studioBG.ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    studioRed.opacity(0.16),
                    Color.clear
                ]),
                center: .top,
                startRadius: 20,
                endRadius: 360
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 42)

                    brand
                    loginModePicker

                    Group {
                        switch mode {
                        case .qr:
                            qrLogin
                        case .captcha:
                            captchaLogin
                        case .password:
                            passwordLogin
                        }
                    }
                    .transition(.opacity)

                    if !message.isEmpty {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(studioSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }

                    Text("登录凭据不会保存；应用仅将登录成功后的网易云会话 Cookie 存入系统 Keychain。")
                        .font(.system(size: 12))
                        .foregroundColor(studioTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 26)
            }
        }
        .onChange(of: mode) { newMode in
            message = ""
            if newMode == .qr && vm.qrImage == nil && !vm.qrPolling {
                Task { await vm.startQrLogin() }
            }
        }
        .onChange(of: vm.isLoggedIn) { loggedIn in
            if loggedIn {
                Task { await vm.zMusicSyncLibrary() }
            }
        }
        .task {
            if !vm.isLoggedIn && mode == .qr && vm.qrImage == nil && !vm.qrPolling {
                await vm.startQrLogin()
            }
        }
    }

    private var brand: some View {
        VStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(studioRed.opacity(0.16))
                    .frame(width: 78, height: 78)

                Image(systemName: "music.note")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(studioRed)
            }

            Text("ZMusic")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)

            Text("登录网易云音乐")
                .font(.system(size: 14))
                .foregroundColor(studioSecondary)
        }
    }

    private var loginModePicker: some View {
        HStack(spacing: 4) {
            ForEach(ZMusicLoginMode.allCases, id: \.self) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = item
                    }
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(mode == item ? .white : studioTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(mode == item ? Color.white.opacity(0.09) : Color.clear)
                        )
                }
                .buttonStyle(StudioPressStyle())
            }
        }
        .padding(4)
        .background(studioCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var qrLogin: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 246, height: 246)
                    .shadow(color: studioRed.opacity(0.18), radius: 30, y: 10)

                if let image = vm.qrImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 210, height: 210)
                } else {
                    VStack(spacing: 15) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: studioRed))
                            .scaleEffect(1.15)

                        Text("正在生成二维码")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.65))
                    }
                }
            }

            Text(vm.qrStatusText.isEmpty ? "请使用网易云音乐 App 扫码" : vm.qrStatusText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(studioSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    vm.qrPolling = false
                    vm.qrImage = nil
                    await vm.startQrLogin()
                }
            } label: {
                secondaryButtonLabel("刷新二维码", icon: "arrow.clockwise")
            }
            .buttonStyle(StudioPressStyle())
        }
    }

    private var captchaLogin: some View {
        VStack(spacing: 14) {
            phoneFields

            HStack(spacing: 10) {
                TextField("短信验证码", text: $captcha)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .foregroundColor(.white)
                    .padding(.horizontal, 15)
                    .frame(height: 50)
                    .background(studioCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    sendCaptcha()
                } label: {
                    Text(isSendingCaptcha ? "发送中" : "获取验证码")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 100, height: 50)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(StudioPressStyle())
                .disabled(isSendingCaptcha || phone.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Button {
                loginWithCaptcha()
            } label: {
                primaryButtonLabel(isSubmitting ? "正在登录" : "验证码登录")
            }
            .buttonStyle(StudioPressStyle())
            .disabled(isSubmitting || phone.isEmpty || captcha.isEmpty)
        }
    }

    private var passwordLogin: some View {
        VStack(spacing: 14) {
            phoneFields

            SecureField("网易云密码", text: $password)
                .textContentType(.password)
                .foregroundColor(.white)
                .padding(.horizontal, 15)
                .frame(height: 50)
                .background(studioCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                loginWithPassword()
            } label: {
                primaryButtonLabel(isSubmitting ? "正在登录" : "密码登录")
            }
            .buttonStyle(StudioPressStyle())
            .disabled(isSubmitting || phone.isEmpty || password.isEmpty)
        }
    }

    private var phoneFields: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                Text("+")
                    .foregroundColor(studioSecondary)

                TextField("86", text: $countryCode)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .frame(width: 78, height: 50)
            .background(studioCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            TextField("手机号", text: $phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .foregroundColor(.white)
                .padding(.horizontal, 15)
                .frame(height: 50)
                .background(studioCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func primaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(studioRed)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func secondaryButtonLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(studioCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sendCaptcha() {
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPhone.isEmpty else { return }

        isSendingCaptcha = true
        message = ""

        Task {
            do {
                let response = try await vm.client.captchaSent(
                    phone: cleanPhone,
                    ctcode: cleanCode.isEmpty ? "86" : cleanCode
                )
                let code = response.body["code"] as? Int ?? 0
                message = code == 200 ? "验证码已发送" : "验证码发送失败（\(code)）"
            } catch {
                message = "验证码发送失败：\(error.localizedDescription)"
            }
            isSendingCaptcha = false
        }
    }

    private func loginWithCaptcha() {
        login(password: "", captchaValue: captcha)
    }

    private func loginWithPassword() {
        login(password: password, captchaValue: nil)
    }

    private func login(password: String, captchaValue: String?) {
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPhone.isEmpty else { return }

        isSubmitting = true
        message = ""

        Task {
            do {
                let response = try await vm.client.loginCellphone(
                    phone: cleanPhone,
                    password: password,
                    countrycode: cleanCode.isEmpty ? "86" : cleanCode,
                    captcha: captchaValue
                )

                let code = response.body["code"] as? Int ?? 0
                if code == 200 || !vm.currentCookies.isEmpty {
                    await vm.zMusicFinishLogin()
                    if !vm.isLoggedIn {
                        message = "登录请求成功，但暂未读取到账号状态，请稍后重试。"
                    }
                } else {
                    message =
                        response.body["message"] as? String ??
                        "登录失败（\(code)）"
                }
            } catch {
                message = "登录失败：\(error.localizedDescription)"
            }
            self.password = ""
            isSubmitting = false
        }
    }
}

// MARK: - 首页

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
                    librarySection
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

            if vm.dailyRecommendSongs.isEmpty {
                await vm.fetchDailyRecommendSongs()
            }

            if vm.userPlaylists.isEmpty {
                await vm.zMusicSyncLibrary()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("你好，\(vm.loginNickname.isEmpty ? "音乐收藏家" : vm.loginNickname)")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("今日推荐已为你准备好")
                    .font(.system(size: 14))
                    .foregroundColor(studioSecondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(studioCard)
                    .frame(width: 44, height: 44)

                Image(systemName: "person.fill")
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

                        Text("根据你的口味实时推荐")
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
                HStack(spacing: 14) {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: studioRed)
                        )

                    Text("正在加载每日推荐")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(studioSecondary)

                    Spacer()
                }
                .padding(16)
                .background(studioCard)
                .clipShape(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(
                        Array(vm.dailyRecommendSongs.prefix(5).enumerated()),
                        id: \.offset
                    ) { index, song in
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

    private func songRow(
        _ song: [String: Any],
        index: Int
    ) -> some View {
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

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("我的音乐")

                Spacer()

                Button {
                    Task { await vm.zMusicSyncLibrary() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(studioSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(StudioPressStyle())
            }

            if vm.userPlaylists.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: studioRed))

                    Text("正在同步你的歌单")
                        .font(.system(size: 14))
                        .foregroundColor(studioSecondary)

                    Spacer()
                }
                .padding(16)
                .background(studioCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(vm.userPlaylists.prefix(4).enumerated()), id: \.offset) { _, playlist in
                        NavigationLink(
                            destination: PlaylistDetailView(
                                vm: vm,
                                playlistId: intValue(playlist["id"]),
                                playlistName: playlist["name"] as? String ?? "歌单"
                            )
                        ) {
                            HStack(spacing: 13) {
                                HomeArtwork(urlString: coverURL(playlist))
                                    .frame(width: 54, height: 54)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        if isLikedPlaylist(playlist) {
                                            Image(systemName: "heart.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(studioRed)
                                        }

                                        Text(playlist["name"] as? String ?? "未知歌单")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                    }

                                    Text(trackCountText(playlist))
                                        .font(.system(size: 12))
                                        .foregroundColor(studioTertiary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(studioTertiary)
                            }
                            .padding(10)
                            .background(studioCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(StudioPressStyle())
                    }
                }
            }
        }
    }

    private func isLikedPlaylist(_ playlist: [String: Any]) -> Bool {
        let name = playlist["name"] as? String ?? ""
        if name.contains("我喜欢") { return true }

        if let special = playlist["specialType"] as? Int, special == 5 {
            return true
        }
        if let special = playlist["specialType"] as? NSNumber, special.intValue == 5 {
            return true
        }
        return false
    }

    private func trackCountText(_ playlist: [String: Any]) -> String {
        if let count = playlist["trackCount"] as? Int {
            return "\(count) 首"
        }
        if let count = playlist["trackCount"] as? NSNumber {
            return "\(count.intValue) 首"
        }
        return "网易云歌单"
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
                            .progressViewStyle(
                                CircularProgressViewStyle(tint: .white)
                            )
                    )
            } else {
                LazyVGrid(columns: playlistColumns, spacing: 18) {
                    ForEach(
                        Array(vm.personalizedPlaylists.prefix(6).enumerated()),
                        id: \.offset
                    ) { _, playlist in
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

    private func playlistCard(
        _ playlist: [String: Any]
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HomeArtwork(urlString: coverURL(playlist))
                .aspectRatio(1, contentMode: .fit)
                .clipShape(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
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
                    Text("热榜")
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
            .clipShape(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(StudioPressStyle())
    }

    private func sectionTitle(
        _ title: String
    ) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .tracking(1.5)
            .foregroundColor(studioTertiary)
    }

    private func play(
        _ song: [String: Any]
    ) {
        let id = intValue(song["id"])
        guard id > 0 else { return }

        vm.testSongId = String(id)
        Task { await vm.testPlaySong() }
    }

    private func intValue(
        _ value: Any?
    ) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) ?? 0 }
        return 0
    }

    private func coverURL(
        _ item: [String: Any]
    ) -> String {
        if let url = item["picUrl"] as? String { return url }
        if let url = item["coverImgUrl"] as? String { return url }
        return ""
    }

    private func playCount(
        _ item: [String: Any]
    ) -> Int? {
        if let value = item["playCount"] as? Int { return value }
        if let value = item["playcount"] as? Int { return value }
        if let value = item["playCount"] as? NSNumber {
            return value.intValue
        }
        return nil
    }

    private func compactCount(
        _ value: Int
    ) -> String {
        if value >= 100_000_000 {
            return String(
                format: "%.1f亿",
                Double(value) / 100_000_000.0
            )
        }

        if value >= 10_000 {
            return String(
                format: "%.1f万",
                Double(value) / 10_000.0
            )
        }

        return "\(value)"
    }
}

private struct HomeArtwork: View {
    let urlString: String

    var body: some View {
        ZStack {
            studioCard

            if let url = URL(string: urlString),
               !urlString.isEmpty {
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
                gradient: Gradient(colors: [
                    studioRed.opacity(0.6),
                    studioCard
                ]),
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
            .animation(
                .spring(response: 0.28, dampingFraction: 0.72),
                value: configuration.isPressed
            )
    }
}
