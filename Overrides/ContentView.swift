import SwiftUI

struct ContentView: View {
    @StateObject private var vm = DemoViewModel()
    @State private var showPlayer = false

    var body: some View {
        TabView {
            NavigationView {
                RecommendView(vm: vm)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem { Label("首页", systemImage: "house.fill") }

            NavigationView {
                SearchView(vm: vm)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem { Label("搜索", systemImage: "magnifyingglass") }

            NavigationView {
                ToplistView(vm: vm)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem { Label("排行榜", systemImage: "chart.bar.fill") }

            NavigationView {
                SettingsView(vm: vm)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .overlay(
            VStack {
                Spacer()
                if !vm.playSongName.isEmpty || vm.isPlayLoading {
                    MiniPlayerView(vm: vm) {
                        showPlayer = true
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 52)
                }
            }
        )
        .sheet(isPresented: $showPlayer) {
            NowPlayingView(vm: vm)
        }
    }
}
