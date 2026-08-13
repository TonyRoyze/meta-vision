import SwiftUI
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        picker.accessibilityLabel = "Document camera"
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraCaptureView

        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.onCancel()
                return
            }
            parent.onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
