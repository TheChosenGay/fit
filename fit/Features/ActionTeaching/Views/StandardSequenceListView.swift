import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct StandardSequenceListView: View {

    @Query(sort: \StandardSequenceCatalog.exerciseName) private var sequences: [StandardSequenceCatalog]
    @State private var selectedSequence: StandardSequenceCatalog?
    @State private var showTeaching = false
    @State private var showComparison = false

    var body: some View {
        VStack(spacing: 0) {
            if sequences.isEmpty {
                emptyState
            } else {
                sequenceList
            }
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .navigationTitle("标准动作库")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    StandardSequenceGeneratorView()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.3))
            Text("暂无标准动作")
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
            Text("点击右上角 + 导入标准视频生成")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List

    private var sequenceList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(sequences) { seq in
                    sequenceCard(seq)
                }
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.vertical, DSSpacing.md)
        }
    }

    private func sequenceCard(_ seq: StandardSequenceCatalog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(seq.exerciseName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(seq.exerciseId)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Text("v\(seq.version)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
            }

            HStack(spacing: 12) {
                Button {
                    selectedSequence = seq
                    showTeaching = true
                } label: {
                    Label("教学演示", systemImage: "play.circle")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }

                Button {
                    selectedSequence = seq
                    showComparison = true
                } label: {
                    Label("实时对比", systemImage: "person.2")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
            }
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.white.opacity(0.08))
        )
        .navigationDestination(isPresented: $showTeaching) {
            if let seq = selectedSequence {
                ActionTeachingView(exerciseId: seq.exerciseId)
            }
        }
        .navigationDestination(isPresented: $showComparison) {
            if let seq = selectedSequence {
                ComparisonSessionView(exerciseId: seq.exerciseId)
            }
        }
    }
}
