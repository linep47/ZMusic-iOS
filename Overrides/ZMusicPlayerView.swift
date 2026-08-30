import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var vm: DemoViewModel
    let openPlayer: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: openPlayer) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.secondary)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.playSongName.isEmpty ? "正在加载…" : vm.playSongName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(vm.playStatus.isEmpty ? "ZMusic" : vm.playStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            if vm.isPlayLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: vm.isPlaying ? "stop.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(radius: 6, y: 2)
    }

    private func togglePlayback() {
        if vm.isPlaying {
            vm.stopPlaying()
        } else {
            Task { await vm.testPlaySong() }
        }
    }
}

struct NowPlayingView: View {
    @ObservedObject var vm: DemoViewModel
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 28) {
                Spacer()

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 72, weight: .light))
                            .foregroundColor(.secondary)
                    )
                    .padding(.horizontal, 28)

                VStack(spacing: 8) {
                    Text(vm.playSongName.isEmpty ? "未播放歌曲" : vm.playSongName)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(vm.playStatus.isEmpty ? "ZMusic" : vm.playStatus)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                HStack(spacing: 52) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.5))

                    Button {
                        if vm.isPlaying {
                            vm.stopPlaying()
                        } else {
                            Task { await vm.testPlaySong() }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.primary)
                                .frame(width: 72, height: 72)

                            if vm.isPlayLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(.systemBackground)))
                            } else {
                                Image(systemName: vm.isPlaying ? "stop.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundColor(Color(.systemBackground))
                            }
                        }
                    }

                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.5))
                }

                if !vm.playUrl.isEmpty {
                    Text("歌曲 ID：\(vm.testSongId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .navigationBarTitle("正在播放", displayMode: .inline)
            .navigationBarItems(
                leading: Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
