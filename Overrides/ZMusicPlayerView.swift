import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var vm: DemoViewModel
    let openPlayer: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: openPlayer) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .frame(width: 42, height: 42)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.playSongName.isEmpty ? "正在加载…" : vm.playSongName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        Text(vm.playStatus.isEmpty ? "ZMusic" : vm.playStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if vm.isPlayLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: vm.isPlaying ? "stop.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.quaternary)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 72, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28)

                VStack(spacing: 8) {
                    Text(vm.playSongName.isEmpty ? "未播放歌曲" : vm.playSongName)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(vm.playStatus.isEmpty ? "ZMusic" : vm.playStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                HStack(spacing: 52) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundStyle(.tertiary)

                    Button {
                        if vm.isPlaying {
                            vm.stopPlaying()
                        } else {
                            Task { await vm.testPlaySong() }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.primary)
                                .frame(width: 72, height: 72)

                            if vm.isPlayLoading {
                                ProgressView()
                                    .tint(Color(.systemBackground))
                            } else {
                                Image(systemName: vm.isPlaying ? "stop.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color(.systemBackground))
                            }
                        }
                    }

                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }

                if !vm.playUrl.isEmpty {
                    Text("歌曲 ID：\(vm.testSongId)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .navigationTitle("正在播放")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
