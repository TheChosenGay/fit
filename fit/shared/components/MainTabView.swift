import SwiftUI

struct MainTabView: View {
    @State private var selectedModel: AIModel = .deepseek

    var body: some View {
        TabView {
            AppNavigationStack {
                    CameraView()
                }
                .tabItem {
                    Image(uiImage: DSIconName.camera.uiImage()).renderingMode(.template)
                    Text("分析")
                }

            AppNavigationStack {
                    HistoryView()
                }
                .tabItem {
                    Image(uiImage: DSIconName.history.uiImage()).renderingMode(.template)
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
