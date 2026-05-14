import SwiftUI

enum AIModel: String, CaseIterable, Identifiable {
    case deepseek = "DeepSeek (文本)"
    case minimax = "MiniMax (多模态)"
    case zhipu = "智谱 GLM-4V (多模态)"

    var id: String { rawValue }
}

private struct ModelSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<AIModel> = .constant(.deepseek)
}

extension EnvironmentValues {
    var selectedAIModel: Binding<AIModel> {
        get { self[ModelSelectionKey.self] }
        set { self[ModelSelectionKey.self] = newValue }
    }
}

struct DebugModelButton: View {
    @Binding var selectedModel: AIModel
    @State private var expanded = false
    @State private var showDesignSystem = false
    @State private var showSpeechTest = false
    @State private var position = CGPoint(x: -60, y: 0)
    @State private var dragStart: CGPoint?

    var body: some View {
        VStack(alignment: .trailing, spacing: DSSpacing.xs) {
            if expanded {
                ForEach(AIModel.allCases) { model in
                    Text(model.rawValue)
                        .dsTextStyle(.caption1)
                        .foregroundColor(.white)
                        .padding(.horizontal, DSSpacing.xs)
                        .padding(.vertical, DSSpacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: DSCornerRadius.small)
                                .fill(selectedModel == model ? Color.dsPrimary : Color.dsLabelTertiary)
                        )
                        .onTapGesture {
                            selectedModel = model
                            withAnimation(.easeInOut(duration: 0.2)) { expanded = false }
                        }
                }

                Divider()
                    .frame(width: 40)
                    .background(Color.white.opacity(0.3))

                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: DSCornerRadius.small)
                            .fill(Color.dsSecondary)
                    )
                    .onTapGesture {
                        showDesignSystem = true
                        withAnimation(.easeInOut(duration: 0.2)) { expanded = false }
                    }

                Divider()
                    .frame(width: 40)
                    .background(Color.white.opacity(0.3))

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: DSCornerRadius.small)
                            .fill(Color.dsSuccess)
                    )
                    .onTapGesture {
                        showSpeechTest = true
                        withAnimation(.easeInOut(duration: 0.2)) { expanded = false }
                    }
            }

            Image(systemName: expanded ? "xmark.circle.fill" : "wrench.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.dsPrimary.opacity(0.8)))
                .dsShadow(.subtle)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                }
        }
        .padding(DSSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.dsBackground.opacity(expanded ? 0.6 : 0))
        )
        .offset(x: position.x, y: position.y)
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if dragStart == nil { dragStart = position }
                    let start = dragStart!
                    position = CGPoint(
                        x: start.x + value.translation.width,
                        y: start.y + value.translation.height
                    )
                }
                .onEnded { _ in dragStart = nil }
        )
        .sheet(isPresented: $showDesignSystem) {
            NavigationView {
                DesignSystemPreview()
                    .navigationTitle("Design System")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showDesignSystem = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showSpeechTest) {
            SpeechTestView()
        }
    }
}
