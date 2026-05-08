import SwiftUI

// MARK: - PhotoPreviewView
// 拍照/选照片后展示预览，确认后进入分析流程
struct PhotoPreviewView: View {
    let image: UIImage
    let onConfirm: () -> Void
    let onRetake: () -> Void

    @State private var showToast = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 照片预览
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 底部操作栏
                actionBar
                    .background(Color.black)
            }

            // Toast
            if showToast {
                toastView
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear { triggerToast() }
    }

    // MARK: - 底部操作栏
    private var actionBar: some View {
        HStack(spacing: 24) {
            // 重拍
            Button {
                onRetake()
                dismiss()
            } label: {
                Label("重拍", systemImage: "arrow.counterclockwise")
                    .font(.appBody)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
            }

            // 开始分析
            Button {
                onConfirm()
                dismiss()
            } label: {
                Label("开始分析", systemImage: "sparkles")
                    .font(.appBody)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - Toast
    private var toastView: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("照片已保存")
                    .font(.appBody)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.75))
            .cornerRadius(24)
            .padding(.bottom, 120)
        }
    }

    private func triggerToast() {
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showToast = false }
        }
    }
}
