import SwiftUI

enum AIModel: String, CaseIterable, Identifiable {
    case deepseek = "DeepSeek (文本)"
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
        VStack(alignment: .trailing, spacing: 6) {
            if expanded {
                ForEach(AIModel.allCases) { model in
                    Button {
                        selectedModel = model
                        expanded = false
                    } label: {
                        Text(model.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedModel == model ? Color.blue : Color.gray.opacity(0.7))
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
                    .background(Circle().fill(Color.blue.opacity(0.8)))
                    .shadow(radius: 4)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(expanded ? 0.6 : 0))
        )
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { dragOffset = CGSize(width: $0.translation.width - 60, height: $0.translation.height) }
        )
    }
}
