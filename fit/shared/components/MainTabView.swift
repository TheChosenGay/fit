import SwiftUI

struct MainTabView: View {
    @State private var selectedModel: AIModel = .deepseek

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
        .overlay(alignment: .topTrailing) {
            DebugModelButton(selectedModel: $selectedModel)
                .padding(.top, DSSpacing.huge)
                .padding(.trailing, DSSpacing.md)
        }
        .environment(\.selectedAIModel, $selectedModel)
    }
}
