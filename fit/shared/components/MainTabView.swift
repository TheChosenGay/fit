import SwiftUI

struct MainTabView: View {
    @State private var selectedModel: AIModel = .deepseek

    var body: some View {
        if #available(iOS 17.0, *) {
            newTabLayout
        } else {
            legacyTabLayout
        }
    }

    // MARK: - iOS 17+ Layout

    @available(iOS 17.0, *)
    private var newTabLayout: some View {
        TabView {
            // Tab 0: 首页
            AppNavigationStack {
                DashboardView()
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("首页")
            }

            // Tab 1: 训练
            AppNavigationStack {
                TrainingTabView()
            }
            .tabItem {
                Image(uiImage: DSIconName.activity.uiImage(size: 28, weight: .bold))
                Text("训练")
            }

            // Tab 2: 饮食
            AppNavigationStack {
                DietTabView()
            }
            .tabItem {
                Image(systemName: "fork.knife")
                Text("饮食")
            }

            // Tab 3: 我的
            AppNavigationStack {
                ProfileTabView()
            }
            .tabItem {
                Image(uiImage: DSIconName.user.uiImage(size: 28, weight: .bold))
                Text("我的")
            }
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor(Color.dsBackgroundSecondary)
            appearance.shadowColor = UIColor.black.withAlphaComponent(0.3)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        .overlay(alignment: .topTrailing) {
            DebugModelButton(selectedModel: $selectedModel)
                .padding(.top, DSSpacing.huge)
                .padding(.trailing, DSSpacing.md)
        }
        .environment(\.selectedAIModel, $selectedModel)
    }

    // MARK: - iOS 16 Fallback

    private var legacyTabLayout: some View {
        TabView {
            AppNavigationStack {
                CameraView()
            }
            .tabItem {
                Image(uiImage: DSIconName.camera.uiImage(size: 28, weight: .bold))
                Text("分析")
            }

            AppNavigationStack {
                RealTimeCameraEntryView()
            }
            .tabItem {
                Image(uiImage: DSIconName.activity.uiImage(size: 28, weight: .bold))
                Text("训练")
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
