import SwiftUI
import PhotosUI
import UIKit

// MARK: - PhotoPickerView
// 桥接 PHPickerViewController 到 SwiftUI
struct PhotoPickerView: UIViewControllerRepresentable {
    /// 选中照片后的回调
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images       // 只显示图片
        config.selectionLimit = 1     // 单选

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    // MARK: - Coordinator
    // 负责接收 PHPicker 的选择结果回调
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onImagePicked: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                dismiss()
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self else { return }
                let image = object as? UIImage
                DispatchQueue.main.async {
                    self.dismiss()
                    guard let image else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.onImagePicked(image)
                    }
                }
            }
        }
    }
}
