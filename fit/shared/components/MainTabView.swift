import SwiftUI

struct MainTabView: View {
    @State private var selectedModel: AIModel = .deepseek

    var body: some View {
        TabView {
            AppNavigationStack {
                    CameraView()
                }
                .tabItem {
                    Image(uiImage: DSIconName.camera.uiImage(size: 28, weight: .bold))
                    Text("分析")
                }

            AppNavigationStack {
                    HistoryView()
                }
                .tabItem {
                    Image(uiImage: DSIconName.history.uiImage(size: 28, weight: .bold))
                    Text("历史")
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
