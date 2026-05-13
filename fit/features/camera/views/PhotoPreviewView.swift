import SwiftUI

// MARK: - PhotoPreviewView
struct PhotoPreviewView: View {
    let image: UIImage
    let onConfirm: () -> Void
    let onRetake: () -> Void

    @State private var showToast = false
    @State private var showEdgePreview = false
    @State private var edgeImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    if showEdgePreview, let edge = edgeImage {
                        Image(uiImage: edge)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                actionBar
                    .background(Color.black)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation { showEdgePreview.toggle() }
                    } label: {
                        Text(showEdgePreview ? "原图" : "边缘")
                            .dsTextStyle(.caption1)
                            .foregroundColor(.white)
                            .padding(.horizontal, DSSpacing.xs)
                            .padding(.vertical, DSSpacing.xxs)
                            .background(Capsule().fill(Color.dsPrimary.opacity(0.7)))
                    }
                    .padding(.trailing, DSSpacing.md)
                }
                Spacer()
            }

            if showToast {
                toastView
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            triggerToast()
            edgeImage = EdgeDetector.composite(image: image)
        }
    }

    // MARK: - 底部操作栏
    private var actionBar: some View {
        HStack(spacing: DSSpacing.xl) {
            Button {
                onRetake()
                dismiss()
            } label: {
                Label("重拍", systemImage: "arrow.counterclockwise")
                    .dsTextStyle(.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSSpacing.sm)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(DSCornerRadius.medium)
            }

            Button {
                onConfirm()
                dismiss()
            } label: {
                Label("开始分析", systemImage: "sparkles")
                    .dsTextStyle(.body)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSSpacing.sm)
                    .background(Color.white)
                    .cornerRadius(DSCornerRadius.medium)
            }
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.vertical, DSSpacing.lg)
    }

    // MARK: - Toast
    private var toastView: some View {
        VStack {
            Spacer()
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.dsSuccess)
                Text("照片已保存")
                    .dsTextStyle(.body)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.vertical, DSSpacing.sm)
            .background(Color.black.opacity(0.75))
            .cornerRadius(DSCornerRadius.xl)
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
