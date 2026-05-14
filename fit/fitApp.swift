import SwiftUI
import SwiftData

@available(iOS 17.0, *)
@main
struct fitApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(DataContainer.shared.container)
        }
    }
}
