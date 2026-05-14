import SwiftUI

struct DietTabView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundColor(.dsPrimary)

            Text("饮食记录")
                .dsTextStyle(.title2)
                .foregroundColor(.white)

            Text("饮食分析和营养追踪功能即将上线")
                .dsTextStyle(.caption1)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dsBackground.ignoresSafeArea())
    }
}
