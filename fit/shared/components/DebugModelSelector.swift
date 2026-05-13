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
    @State private var dragOffset = CGSize(width: -60, height: 0)

    var body: some View {
        VStack(alignment: .trailing, spacing: DSSpacing.xs) {
            if expanded {
                ForEach(AIModel.allCases) { model in
                    Button {
                        selectedModel = model
                        expanded = false
                    } label: {
                        Text(model.rawValue)
                            .dsTextStyle(.caption1)
                            .foregroundColor(.white)
                            .padding(.horizontal, DSSpacing.xs)
                            .padding(.vertical, DSSpacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: DSCornerRadius.small)
                                    .fill(selectedModel == model ? Color.dsPrimary : Color.dsLabelTertiary)
                            )
                    }
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "xmark.circle.fill" : "wrench.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.dsPrimary.opacity(0.8)))
                    .dsShadow(.subtle)
            }
        }
        .padding(DSSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.dsBackground.opacity(expanded ? 0.6 : 0))
        )
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { dragOffset = CGSize(width: $0.translation.width - 60, height: $0.translation.height) }
        )
    }
}
