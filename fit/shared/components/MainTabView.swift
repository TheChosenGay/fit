import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            CameraView()
                .tabItem {
                    Label("分析", systemImage: "camera")
                }

            HistoryView()
                .tabItem {
                    Label("历史", systemImage: "clock")
                }
        }
    }
}
