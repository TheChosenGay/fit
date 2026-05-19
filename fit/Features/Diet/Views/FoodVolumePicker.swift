import SwiftUI

// MARK: - Food volume picker (for non-LiDAR devices)

struct FoodVolumePicker: View {
    let foodItems: [String]
    var onConfirm: ([String: Float]) -> Void

    @State private var selections: [String: Int] = [:]
    @Environment(\.dismiss) private var dismiss

    private let options: [(String, Int)] = [
        ("小份", 150),
        ("中份", 300),
        ("大份", 500),
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(foodItems, id: \.self) { item in
                    Section(item) {
                        Picker("份量", selection: Binding(
                            get: { selections[item] ?? 300 },
                            set: { selections[item] = $0 }
                        )) {
                            ForEach(options.indices, id: \.self) { i in
                                Text("\(options[i].0) (~\(options[i].1)ml)").tag(options[i].1)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("选择份量")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        let result = Dictionary(
                            uniqueKeysWithValues: selections.map { ($0.key, Float($0.value)) }
                        )
                        onConfirm(result)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
