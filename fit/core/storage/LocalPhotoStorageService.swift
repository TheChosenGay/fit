import UIKit

// MARK: - LocalPhotoStorageService
// 将照片以 JPEG 格式存入沙盒 Documents/photos/ 目录
final class LocalPhotoStorageService: PhotoStorageService {

    private let photoDirectory: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        photoDirectory = documents.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photoDirectory, withIntermediateDirectories: true)
    }

    func save(image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw PhotoStorageError.encodingFailed
        }
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = photoDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileName
    }

    func load(fileName: String) -> UIImage? {
        let fileURL = photoDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func delete(fileName: String) throws {
        let fileURL = photoDirectory.appendingPathComponent(fileName)
        try FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - PhotoStorageError
enum PhotoStorageError: Error, LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "照片编码失败"
        }
    }
}
