import SwiftUI

struct ContentView: View {
    @StateObject private var vm = DemoViewModel()
    @State private var showPlayer = false

    var body: some View {
        TabView {
            NavigationStack {
                RecommendView(vm: vm)
            }
            .tabItem { Label("首页", systemImage: "house.fill") }

            NavigationStack {
                SearchView(vm: vm)
            }
            .tabItem { Label("搜索", systemImage: "magnifyingglass") }

            NavigationStack {
                ToplistView(vm: vm)
            }
            .tabItem { Label("排行榜", systemImage: "chart.bar.fill") }

            NavigationStack {
                SettingsView(vm: vm)
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .overlay(alignment: .bottom) {
            if !vm.playSongName.isEmpty || vm.isPlayLoading {
                MiniPlayerView(vm: vm) {
                    showPlayer = true
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 52)
            }
        }
        .sheet(isPresented: $showPlayer) {
            NowPlayingView(vm: vm)
        }
    }
}
