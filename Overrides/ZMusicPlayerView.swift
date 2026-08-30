import SwiftUI
import UIKit

private let zMusicAccent = Color(red: 1.0, green: 59.0 / 255.0, blue: 48.0 / 255.0)

struct MiniPlayerView: View {
    @ObservedObject var vm: DemoViewModel
    let openPlayer: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                zMusicHaptic(.light)
                openPlayer()
            }) {
                HStack(spacing: 12) {
                    ZMusicArtworkView(urlString: vm.playArtworkURL, cornerRadius: 8)
                        .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.playSongName.isEmpty ? "未播放歌曲" : vm.playSongName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(vm.playArtistName.isEmpty ? "ZMusic" : vm.playArtistName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(ZMusicSpringButtonStyle())

            Spacer()

            if vm.isPlayLoading {
                ProgressView()
            } else {
                Button {
                    zMusicHaptic(.medium)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.66)) {
                        vm.togglePlayback()
                    }
                } label: {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 38, height: 38)
                        .foregroundColor(.primary)
                }
                .buttonStyle(ZMusicSpringButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemBackground)))
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
    }
}

struct NowPlayingView: View {
    @ObservedObject var vm: DemoViewModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var showLyrics = false
    @State private var contentDrag: CGFloat = 0
    @State private var seekingValue: Double = 0
    @State private var isSeeking = false
    @State private var showQueue = false

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                header.padding(.top, 6)
                Spacer(minLength: 10)
                mainContent.frame(maxHeight: 430)
                Spacer(minLength: 18)
                trackInfo
                progressSection.padding(.top, 18)
                controls.padding(.top, 18).padding(.bottom, 22)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
        .onAppear { seekingValue = vm.playCurrentTime }
        .onChange(of: vm.playCurrentTime) { value in
            if !isSeeking { seekingValue = value }
        }
        .sheet(isPresented: $showQueue) {
            NavigationView {
                List {
                    if vm.playQueue.isEmpty {
                        Text("播放队列为空")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(vm.playQueue.enumerated()), id: \.offset) { index, song in
                            Button {
                                vm.zMusicPlayQueueItem(at: index)
                                showQueue = false
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(song["name"] as? String ?? "未知歌曲")
                                        .foregroundColor(.primary)
                                    Text(DemoViewModel.artistNames(from: song))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("播放队列")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") { showQueue = false }
                    }
                }
            }
        }
    }

    private var background: some View {
        ZStack {
            Color.black
            LinearGradient(
                gradient: Gradient(colors: [zMusicAccent.opacity(0.28), Color.black.opacity(0.2), Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )
            if !vm.playArtworkURL.isEmpty, let url = URL(string: vm.playArtworkURL) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill().blur(radius: 70).opacity(0.20).scaleEffect(1.35)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            circleButton("chevron.down") {
                zMusicHaptic(.light)
                presentationMode.wrappedValue.dismiss()
            }
            Spacer()
            VStack(spacing: 2) {
                Text("正在播放").font(.caption2).foregroundColor(.white.opacity(0.55))
                Text(vm.playSongName.isEmpty ? "ZMusic" : vm.playSongName)
                    .font(.caption.weight(.semibold)).foregroundColor(.white).lineLimit(1).frame(maxWidth: 180)
            }
            Spacer()
            circleButton(playModeIcon) { zMusicHaptic(.light); vm.zMusicCyclePlayMode() }
        }
    }

    private var mainContent: some View {
        GeometryReader { proxy in
            ZStack {
                artworkContent.opacity(showLyrics ? 0 : 1).offset(y: showLyrics ? -90 : contentDrag).scaleEffect(showLyrics ? 0.92 : 1)
                lyricsContent.opacity(showLyrics ? 1 : 0).offset(y: showLyrics ? contentDrag : 100)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in contentDrag = value.translation.height * 0.28 }
                    .onEnded { value in
                        if value.translation.height < -45 && !showLyrics {
                            zMusicHaptic(.light)
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) { showLyrics = true }
                        } else if value.translation.height > 45 && showLyrics {
                            zMusicHaptic(.light)
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) { showLyrics = false }
                        }
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { contentDrag = 0 }
                    }
            )
        }
    }

    private var artworkContent: some View {
        ZStack {
            ZMusicArtworkView(urlString: vm.playArtworkURL, cornerRadius: 30)
                .blur(radius: 32).opacity(0.42).scaleEffect(1.06)
            ZMusicArtworkView(urlString: vm.playArtworkURL, cornerRadius: 26)
                .shadow(color: zMusicAccent.opacity(0.35), radius: 36, y: 14)
        }
        .padding(.horizontal, 10)
    }

    private var lyricsContent: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if vm.playLyricTimeline.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 42, weight: .light))
                                .foregroundColor(.white.opacity(0.5))
                            Text("暂无歌词")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                    } else {
                        ForEach(Array(vm.playLyricTimeline.enumerated()), id: \.element.id) { index, line in
                            Button {
                                vm.seek(to: line.time)
                                zMusicHaptic(.light)
                            } label: {
                                Text(line.text)
                                    .font(.system(size: activeLyricIndex == index ? 22 : 18,
                                                  weight: activeLyricIndex == index ? .bold : .regular))
                                    .foregroundColor(activeLyricIndex == index ? .white : .white.opacity(0.38))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .animation(.easeInOut(duration: 0.22), value: activeLyricIndex)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .id(index)
                        }
                    }
                }
                .padding(.vertical, 150)
            }
            .onChange(of: activeLyricIndex) { index in
                guard showLyrics, index >= 0 else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
        .mask(
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black, .black, .clear]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var activeLyricIndex: Int {
        guard !vm.playLyricTimeline.isEmpty else { return -1 }
        var result = 0
        for (index, line) in vm.playLyricTimeline.enumerated() {
            if line.time <= vm.playCurrentTime + 0.15 {
                result = index
            } else {
                break
            }
        }
        return result
    }

    private var trackInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(vm.playSongName.isEmpty ? "未播放歌曲" : vm.playSongName).font(.title2.bold()).foregroundColor(.white).lineLimit(1)
                Text(vm.playArtistName.isEmpty ? "ZMusic" : vm.playArtistName).font(.subheadline).foregroundColor(.white.opacity(0.55)).lineLimit(1)
            }
            Spacer()
            Button { zMusicHaptic(.light) } label: {
                Image(systemName: "heart").font(.title3).foregroundColor(.white)
            }
            .buttonStyle(ZMusicSpringButtonStyle())
        }
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let total = max(vm.playDuration, 0.01)
                let value = min(max(isSeeking ? seekingValue : vm.playCurrentTime, 0), total)
                let ratio = value / total
                let knobX = max(0, min(proxy.size.width - 16, proxy.size.width * ratio - 8))

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.16)).frame(height: 4)
                    Capsule().fill(zMusicAccent).frame(width: max(0, proxy.size.width * ratio), height: 4)
                    Circle().fill(Color.white).frame(width: isSeeking ? 18 : 12, height: isSeeking ? 18 : 12).shadow(color: zMusicAccent.opacity(0.6), radius: 8).offset(x: knobX)
                    if isSeeking {
                        Text(timeString(value)).font(.caption2.monospacedDigit()).foregroundColor(.black)
                            .padding(.horizontal, 8).padding(.vertical, 5).background(Capsule().fill(Color.white))
                            .offset(x: max(0, min(proxy.size.width - 52, knobX - 18)), y: -34)
                    }
                }
                .frame(height: 22)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            isSeeking = true
                            let ratio = min(max(gesture.location.x / max(proxy.size.width, 1), 0), 1)
                            seekingValue = ratio * total
                        }
                        .onEnded { _ in
                            vm.seek(to: seekingValue)
                            zMusicHaptic(.light)
                            isSeeking = false
                        }
                )
            }
            .frame(height: 22)

            HStack {
                Text(timeString(isSeeking ? seekingValue : vm.playCurrentTime))
                Spacer()
                Text("-" + timeString(max(0, vm.playDuration - (isSeeking ? seekingValue : vm.playCurrentTime))))
            }
            .font(.caption2.monospacedDigit())
            .foregroundColor(.white.opacity(0.48))
        }
    }

    private var controls: some View {
        HStack {
            controlButton("list.bullet") { zMusicHaptic(.light); showQueue = true }
            Spacer()
            controlButton("backward.fill", size: 25) { zMusicHaptic(.light); vm.zMusicPreviousTrack() }
            Spacer()
            Button {
                zMusicHaptic(.medium)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) { vm.togglePlayback() }
            } label: {
                ZStack {
                    Circle().fill(zMusicAccent).frame(width: 72, height: 72).shadow(color: zMusicAccent.opacity(0.42), radius: 18, y: 8)
                    if vm.isPlayLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 28, weight: .bold)).foregroundColor(.white).offset(x: vm.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(ZMusicSpringButtonStyle())
            Spacer()
            controlButton("forward.fill", size: 25) { zMusicHaptic(.light); vm.zMusicNextTrack() }
            Spacer()
            controlButton(showLyrics ? "square.stack.fill" : "quote.bubble") {
                zMusicHaptic(.light)
                withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) { showLyrics.toggle() }
            }
        }
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                .frame(width: 42, height: 42).background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(ZMusicSpringButtonStyle())
    }

    private func controlButton(_ icon: String, size: CGFloat = 20, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: size, weight: .semibold)).foregroundColor(.white).frame(width: 44, height: 44)
        }
        .buttonStyle(ZMusicSpringButtonStyle())
    }

    private var playModeIcon: String {
        switch vm.playMode {
        case 1: return "repeat.1"
        case 2: return "shuffle"
        default: return "repeat"
        }
    }

    private func timeString(_ value: Double) -> String {
        guard value.isFinite else { return "0:00" }
        let seconds = max(0, Int(value))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct ZMusicArtworkView: View {
    let urlString: String
    let cornerRadius: CGFloat
    var body: some View {
        Group {
            if let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: placeholder
                    }
                }
            } else { placeholder }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    private var placeholder: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [zMusicAccent, zMusicAccent.opacity(0.55), Color.black]), startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "music.note").font(.system(size: 76, weight: .light)).foregroundColor(.white)
        }
    }
}

private struct ZMusicSpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.76 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

private func zMusicHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}
