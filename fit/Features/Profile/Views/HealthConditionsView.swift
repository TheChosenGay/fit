import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct HealthConditionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showAddSheet = false
    @State private var editingCondition: HealthCondition?

    private var conditions: [HealthCondition] {
        profiles.first?.healthConditions ?? []
    }

    private let bodyRegions: [(String, String)] = [
        ("neck", "颈部"),
        ("shoulder", "肩部"),
        ("back", "背部"),
        ("hip", "髋部"),
        ("knee", "膝部"),
        ("ankle", "踝部"),
        ("wrist", "腕部"),
        ("other", "其他"),
    ]

    private let severities: [(String, String)] = [
        ("mild", "轻度"),
        ("moderate", "中度"),
        ("severe", "重度"),
    ]

    var body: some View {
        List {
            if conditions.isEmpty {
                Section {
                    Text("暂无伤病记录")
                        .dsTextStyle(.body)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.white.opacity(0.05))
                }
            } else {
                Section {
                    ForEach(conditions) { condition in
                        conditionRow(condition)
                            .listRowBackground(Color.white.opacity(0.05))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteCondition(condition)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("伤病记录")
                        .foregroundColor(.dsLabelSecondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.dsBackground.ignoresSafeArea())
        .navigationTitle("健康状况")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    editingCondition = nil
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            ConditionEditView(
                bodyRegions: bodyRegions,
                severities: severities,
                onSave: { condition in
                    addOrUpdateCondition(condition)
                }
            )
        }
    }

    // MARK: - Row

    private func conditionRow(_ condition: HealthCondition) -> some View {
        HStack(spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(condition.name)
                    .dsTextStyle(.body)
                    .foregroundColor(.white)
                HStack(spacing: DSSpacing.xs) {
                    Text(regionLabel(condition.bodyRegion ?? "other"))
                        .dsTextStyle(.caption2)
                        .foregroundColor(.dsLabelSecondary)
                    Text("·")
                        .foregroundColor(.white.opacity(0.3))
                    severityBadge(condition.severity ?? "mild")
                }
            }
            Spacer()
            if condition.isActive {
                Text("进行中")
                    .dsTextStyle(.caption2)
                    .foregroundColor(.dsWarning)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingCondition = condition
            showAddSheet = true
        }
    }

    private func severityBadge(_ severity: String) -> some View {
        let color: Color = switch severity {
        case "severe": .dsError
        case "moderate": .dsWarning
        default: .dsWarning.opacity(0.7)
        }
        return Text(severityLabel(severity))
            .dsTextStyle(.caption2)
            .foregroundColor(color)
    }

    // MARK: - Actions

    private func addOrUpdateCondition(_ condition: HealthCondition) {
        guard let profile = profiles.first else { return }
        if let existing = editingCondition, let index = profile.healthConditions?.firstIndex(where: { $0.id == existing.id }) {
            profile.healthConditions?[index] = condition
        } else {
            profile.healthConditions?.append(condition)
        }
        try? modelContext.save()
    }

    private func deleteCondition(_ condition: HealthCondition) {
        guard let profile = profiles.first else { return }
        profile.healthConditions?.removeAll { $0.id == condition.id }
        try? modelContext.save()
    }

    private func regionLabel(_ region: String) -> String {
        bodyRegions.first { $0.0 == region }?.1 ?? region
    }

    private func severityLabel(_ s: String) -> String {
        severities.first { $0.0 == s }?.1 ?? s
    }
}

// MARK: - Edit sheet

@available(iOS 17.0, *)
private struct ConditionEditView: View {
    @Environment(\.dismiss) private var dismiss

    let bodyRegions: [(String, String)]
    let severities: [(String, String)]
    let onSave: (HealthCondition) -> Void

    @State private var name: String = ""
    @State private var bodyRegion: String = "back"
    @State private var severity: String = "mild"
    @State private var notes: String = ""
    @State private var isActive: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("伤病信息") {
                    TextField("名称（如：腰椎间盘突出）", text: $name)

                    Picker("部位", selection: $bodyRegion) {
                        ForEach(bodyRegions, id: \.0) { region in
                            Text(region.1).tag(region.0)
                        }
                    }

                    Picker("程度", selection: $severity) {
                        ForEach(severities, id: \.0) { s in
                            Text(s.1).tag(s.0)
                        }
                    }

                    Toggle("是否影响训练", isOn: $isActive)
                }

                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("添加伤病")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let condition = HealthCondition()
                        condition.name = name
                        condition.bodyRegion = bodyRegion
                        condition.severity = severity
                        condition.notes = notes
                        condition.isActive = isActive
                        onSave(condition)
                        dismiss()
                    }
                }
            }
        }
    }
}
