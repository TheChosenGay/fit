import SwiftUI
import PhotosUI
import AVFoundation

struct VideoPickerView: UIViewControllerRepresentable {
    let onVideoPicked: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onVideoPicked: onVideoPicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onVideoPicked: (URL) -> Void
        private let dismiss: DismissAction

        init(onVideoPicked: @escaping (URL) -> Void, dismiss: DismissAction) {
            self.onVideoPicked = onVideoPicked
            self.dismiss = dismiss
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                dismiss()
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                guard let self, let url = url else {
                    DispatchQueue.main.async { self?.dismiss() }
                    return
                }

                // Copy to temp directory since PHPicker URL is temporary
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
                try? FileManager.default.copyItem(at: url, to: tempURL)

                DispatchQueue.main.async {
                    self.dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.onVideoPicked(tempURL)
                    }
                }
            }
        }
    }
}
