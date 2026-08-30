import SwiftUI

struct ToplistView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(Array(vm.toplists.enumerated()), id: \.offset) { _, item in
                    NavigationLink(
                        destination: PlaylistDetailView(
                            vm: vm,
                            playlistId: intValue(item["id"]),
                            playlistName: item["name"] as? String ?? "排行榜"
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item["name"] as? String ?? "未知榜单")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            Text(item["updateFrequency"] as? String ?? "")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .navigationTitle("排行榜")
        .task { await vm.fetchToplists() }
    }

    private func intValue(_ value: Any?) -> Int {
        if let v = value as? Int { return v }
        if let v = value as? NSNumber { return v.intValue }
        if let v = value as? String { return Int(v) ?? 0 }
        return 0
    }
}
