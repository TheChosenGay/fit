import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            AppNavigationStack {
                    CameraView()
                }
                .tabItem {
                    Label("分析", systemImage: "camera")
                }

            AppNavigationStack {
                    HistoryView()
                }
                .tabItem {
                    Label("历史", systemImage: "clock")
                }
        }
    }
}
