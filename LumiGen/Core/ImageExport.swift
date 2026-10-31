import Foundation
import UIKit
import Photos
import SwiftUI

enum ImageExport {

    static func saveToPhotos(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(.failure(ExportError.noPermission))
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(.success(()))
                    } else {
                        completion(.failure(error ?? ExportError.unknown))
                    }
                }
            }
        }
    }

    enum ExportError: LocalizedError {
        case noPermission
        case unknown

        var errorDescription: String? {
            switch self {
            case .noPermission: return "没有相册权限，去设置里打开一下"
            case .unknown: return "保存失败"
            }
        }
    }
}

// MARK: - 分享面板

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
