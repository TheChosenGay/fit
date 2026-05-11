import SwiftUI

struct AppNavigationStack<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            content
        }
        .navigationBarHidden(true)
    }
}
