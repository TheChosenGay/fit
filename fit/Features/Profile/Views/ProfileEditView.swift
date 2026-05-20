import SwiftUI
import SwiftData

@available(iOS 17.0, *)


struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var heightCm: Double = 170
    @State private var weightKg: Double = 65
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var biologicalSex: String = "male"
    @State private var fitnessGoal: String = "general_fitness"
    @State private var activityLevel: String = "moderate"
    @State private var showSaveAnimation = false

    private let userDataService = DefaultUserDataService()

    private let goalOptions: [(String, String, String, Color)] = [
        ("posture_correction", "体态矫正", "figure.mind.and.body", .dsPrimary),
        ("weight_loss", "减脂", "flame.fill", .orange),
        ("muscle_gain", "增肌", "figure.strengthtraining.traditional", .dsSuccess),
        ("general_fitness", "综合健康", "heart.fill", .dsSecondary),
    ]

    private let activityOptions: [(String, String)] = [
        ("sedentary", "久坐不动"),
        ("light", "轻度活动"),
        ("moderate", "中等活动"),
        ("active", "活跃"),
        ("very_active", "非常活跃"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.lg) {
                    // Gradient hero
                    heroSection

                    // Basic info card
                    sectionCard("基本信息") {
                        VStack(spacing: DSSpacing.md) {
                            editRow(icon: "person.fill", label: "姓名") {
                                TextField("你的名字", text: $name)
                                    .dsTextStyle(.body)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.trailing)
                            }

                            Divider().background(Color.dsSeparator)

                            PickerRow(
                                icon: "person.2.fill",
                                label: "性别",
                                selection: $biologicalSex,
                                options: [
                                    ("male", "男"),
                                    ("female", "女"),
                                    ("other", "其他"),
                                ]
                            )

                            Divider().background(Color.dsSeparator)

                            DatePicker("出生日期", selection: $dateOfBirth, displayedComponents: .date)
                                .dsTextStyle(.body)
                                .foregroundColor(.white)
                                .tint(.dsPrimary)
                                .environment(\.colorScheme, .dark)
                                .padding(.vertical, DSSpacing.xxs)
                        }
                    }

                    // Body data card
                    sectionCard("身体数据") {
                        VStack(spacing: DSSpacing.md) {
                            measureRow(icon: "ruler.fill", label: "身高", value: $heightCm, unit: "cm", range: 100...250)
                            Divider().background(Color.dsSeparator)
                            measureRow(icon: "scalemass.fill", label: "体重", value: $weightKg, unit: "kg", range: 30...200)
                        }
                    }

                    // Goal card
                    sectionCard("健身目标") {
                        VStack(spacing: DSSpacing.sm) {
                            ForEach(goalOptions, id: \.0) { (key, label, icon, color) in
                                goalOptionRow(key: key, label: label, icon: icon, color: color)
                            }
                        }

                        Divider()
                            .background(Color.dsSeparator)
                            .padding(.vertical, DSSpacing.sm)

                        HStack(spacing: DSSpacing.xs) {
                            Image(systemName: "figure.walk")
                                .font(.body)
                                .foregroundColor(.dsPrimary)
                                .frame(width: 24)
                            Text("活动水平")
                                .dsTextStyle(.body)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Picker("", selection: $activityLevel) {
                                ForEach(activityOptions, id: \.0) { (key, label) in
                                    Text(label).tag(key)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.dsPrimary)
                        }
                    }

                    // Save button
                    saveButton
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.bottom, DSSpacing.xxxl)
            }
            .background(Color.dsBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.dsLabelSecondary)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: DSSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.dsPrimary, .dsSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Text(name.prefix(1).uppercased())
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("编辑个人档案")
                .dsTextStyle(.title3)
                .foregroundColor(.dsLabel)

            Text("完善信息让 AI 教练更懂你")
                .dsTextStyle(.caption1)
                .foregroundColor(.dsLabelSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.xl)
    }

    // MARK: - Card helper

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(title)
                .dsTextStyle(.headline)
                .foregroundColor(.dsLabel)
                .padding(.bottom, DSSpacing.xxs)

            content()
                .padding(DSSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                        .fill(Color.dsSurfaceSecondary)
                )
                .dsShadow(.subtle)
        }
    }

    // MARK: - Rows

    private func editRow(icon: String, label: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.dsPrimary)
                .frame(width: 24)
            Text(label)
                .dsTextStyle(.body)
                .foregroundColor(.dsLabelSecondary)
            Spacer()
            trailing()
        }
    }

    private func measureRow(icon: String, label: String, value: Binding<Double>, unit: String, range: ClosedRange<Double>) -> some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.dsPrimary)
                .frame(width: 24)
            Text(label)
                .dsTextStyle(.body)
                .foregroundColor(.dsLabelSecondary)
            Spacer()
            TextField("", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .dsTextStyle(.body)
                .foregroundColor(.white)
                .frame(width: 64)
            Text(unit)
                .dsTextStyle(.caption1)
                .foregroundColor(.dsLabelTertiary)
        }
    }

    private func goalOptionRow(key: String, label: String, icon: String, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                fitnessGoal = key
            }
        } label: {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(fitnessGoal == key ? .white : color)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(fitnessGoal == key ? color : color.opacity(0.15))
                    )

                Text(label)
                    .dsTextStyle(.body)
                    .foregroundColor(fitnessGoal == key ? .dsLabel : .dsLabelSecondary)

                Spacer()

                if fitnessGoal == key {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.dsPrimary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(DSSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.small)
                    .fill(fitnessGoal == key ? Color.dsPrimary.opacity(0.1) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button(action: saveWithAnimation) {
            HStack(spacing: DSSpacing.xs) {
                if showSaveAnimation {
                    Image(systemName: "checkmark.circle.fill")
                        .transition(.scale.combined(with: .opacity))
                }
                Text("保存档案")
            }
            .dsTextStyle(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                    .fill(
                        LinearGradient(
                            colors: [.dsPrimary, .dsPrimaryVariant],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .dsShadow(.medium)
        }
        .padding(.top, DSSpacing.md)
    }

    // MARK: - Logic

    private func loadExisting() {
        guard let existing = try? userDataService.fetchProfile(context: modelContext) else { return }
        name = existing.name
        heightCm = existing.heightCm ?? 170
        weightKg = existing.weightKg ?? 65
        dateOfBirth = existing.dateOfBirth ?? Date()
        biologicalSex = existing.biologicalSex ?? "male"
        fitnessGoal = existing.fitnessGoal ?? "general_fitness"
        activityLevel = existing.activityLevel ?? "moderate"
    }

    private func saveWithAnimation() {
        withAnimation(.spring(response: 0.3)) {
            showSaveAnimation = true
        }
        save()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            dismiss()
        }
    }

    private func save() {
        let existing = try? userDataService.fetchProfile(context: modelContext)
        let profile = existing ?? UserProfile()
        profile.name = name
        profile.heightCm = heightCm
        profile.weightKg = weightKg
        profile.dateOfBirth = dateOfBirth
        profile.biologicalSex = biologicalSex
        profile.fitnessGoal = fitnessGoal
        profile.activityLevel = activityLevel
        try? userDataService.saveProfile(profile, context: modelContext)
    }
}

// MARK: - Picker Row

private struct PickerRow: View {
    let icon: String
    let label: String
    @Binding var selection: String
    let options: [(String, String)]

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.dsPrimary)
                .frame(width: 24)
            Text(label)
                .dsTextStyle(.body)
                .foregroundColor(.dsLabelSecondary)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(options, id: \.0) { (key, label) in
                    Text(label).tag(key)
                }
            }
            .pickerStyle(.menu)
            .tint(.dsPrimary)
        }
    }
}
