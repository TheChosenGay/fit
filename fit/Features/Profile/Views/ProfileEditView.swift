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

    private let userDataService = DefaultUserDataService()

    private let goalOptions: [(String, String)] = [
        ("posture_correction", "体态矫正"),
        ("weight_loss", "减脂"),
        ("muscle_gain", "增肌"),
        ("general_fitness", "综合健康"),
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
            Form {
                Section("基本信息") {
                    TextField("姓名", text: $name)

                    Picker("性别", selection: $biologicalSex) {
                        Text("男").tag("male")
                        Text("女").tag("female")
                        Text("其他").tag("other")
                    }

                    DatePicker("出生日期", selection: $dateOfBirth, displayedComponents: .date)

                    HStack {
                        Text("身高")
                        Spacer()
                        TextField("cm", value: $heightCm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("cm")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("体重")
                        Spacer()
                        TextField("kg", value: $weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kg")
                            .foregroundColor(.secondary)
                    }
                }

                Section("健身目标") {
                    Picker("目标", selection: $fitnessGoal) {
                        ForEach(goalOptions, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }

                    Picker("活动水平", selection: $activityLevel) {
                        ForEach(activityOptions, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }
                }
            }
            .navigationTitle("编辑档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear { loadExisting() }
        }
    }

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
        dismiss()
    }
}
