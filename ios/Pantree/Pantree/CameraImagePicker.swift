import SwiftUI
#if canImport(UIKit)
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct CameraImagePicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

enum ReceiptCaptureSource: Equatable {
    case camera
    case photoLibrary

    var shortLabel: String {
        switch self {
        case .camera:
            return "camera photo"
        case .photoLibrary:
            return "photo library image"
        }
    }
}

struct ReceiptCapturedImage: Equatable {
    let imageData: Data
    let source: ReceiptCaptureSource
}

struct ReceiptCameraCaptureView: UIViewControllerRepresentable {
    var onCapture: (ReceiptCapturedImage) -> Void
    var onError: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = [UTType.image.identifier]
        picker.modalPresentationStyle = .fullScreen
        context.coordinator.picker = picker

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.cameraDevice = .rear
            if UIImagePickerController.isFlashAvailable(for: .rear) {
                picker.cameraFlashMode = .auto
            }
            picker.showsCameraControls = false
            picker.cameraOverlayView = context.coordinator.makeCameraOverlayView()
        } else {
            picker.sourceType = .photoLibrary
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate, PHPickerViewControllerDelegate {
        private let parent: ReceiptCameraCaptureView
        weak var picker: UIImagePickerController?

        init(_ parent: ReceiptCameraCaptureView) {
            self.parent = parent
        }

        func makeCameraOverlayView() -> UIView {
            let overlay = UIView(frame: UIScreen.main.bounds)
            overlay.backgroundColor = .clear
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlay.accessibilityIdentifier = "ReceiptCameraOverlay"

            let bottomBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
            bottomBar.translatesAutoresizingMaskIntoConstraints = false
            overlay.addSubview(bottomBar)

            let closeButton = UIButton(type: .system)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
            closeButton.tintColor = .white
            closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
            closeButton.layer.cornerRadius = 22
            closeButton.accessibilityLabel = "Close receipt camera"
            closeButton.accessibilityIdentifier = "CloseReceiptCameraButton"
            closeButton.addTarget(self, action: #selector(closeCamera), for: .touchUpInside)
            overlay.addSubview(closeButton)

            let libraryButton = UIButton(type: .system)
            libraryButton.translatesAutoresizingMaskIntoConstraints = false
            libraryButton.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
            libraryButton.tintColor = .white
            libraryButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            libraryButton.layer.cornerRadius = 18
            libraryButton.accessibilityLabel = "Choose receipt from photo library"
            libraryButton.accessibilityIdentifier = "ReceiptLibraryButton"
            libraryButton.addTarget(self, action: #selector(openPhotoLibrary), for: .touchUpInside)
            overlay.addSubview(libraryButton)

            let shutterButton = UIButton(type: .custom)
            shutterButton.translatesAutoresizingMaskIntoConstraints = false
            shutterButton.backgroundColor = .white
            shutterButton.layer.borderWidth = 5
            shutterButton.layer.borderColor = UIColor.white.withAlphaComponent(0.65).cgColor
            shutterButton.layer.cornerRadius = 38
            shutterButton.accessibilityLabel = "Take receipt picture"
            shutterButton.accessibilityIdentifier = "ReceiptShutterButton"
            shutterButton.addTarget(self, action: #selector(takePicture), for: .touchUpInside)
            overlay.addSubview(shutterButton)

            let safeArea = overlay.safeAreaLayoutGuide
            NSLayoutConstraint.activate([
                bottomBar.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
                bottomBar.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
                bottomBar.bottomAnchor.constraint(equalTo: overlay.bottomAnchor),
                bottomBar.heightAnchor.constraint(equalToConstant: 142),

                closeButton.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 18),
                closeButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 18),
                closeButton.widthAnchor.constraint(equalToConstant: 44),
                closeButton.heightAnchor.constraint(equalToConstant: 44),

                libraryButton.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 24),
                libraryButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -24),
                libraryButton.widthAnchor.constraint(equalToConstant: 58),
                libraryButton.heightAnchor.constraint(equalToConstant: 58),

                shutterButton.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
                shutterButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -16),
                shutterButton.widthAnchor.constraint(equalToConstant: 76),
                shutterButton.heightAnchor.constraint(equalToConstant: 76)
            ])

            return overlay
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let source: ReceiptCaptureSource = picker.sourceType == .camera ? .camera : .photoLibrary
            if let imageURL = info[.imageURL] as? URL,
               let imageData = try? Data(contentsOf: imageURL) {
                parent.onCapture(ReceiptCapturedImage(imageData: imageData, source: source))
                parent.dismiss()
                return
            }

            if let image = info[.originalImage] as? UIImage,
               let imageData = Self.normalizedImageData(from: image) {
                parent.onCapture(ReceiptCapturedImage(imageData: imageData, source: source))
                parent.dismiss()
                return
            }

            parent.onError("The receipt image could not be loaded.")
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                picker.dismiss(animated: true)
                return
            }

            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self, weak picker] imageData, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let imageData {
                        self.parent.onCapture(ReceiptCapturedImage(imageData: imageData, source: .photoLibrary))
                        self.parent.dismiss()
                    } else if let error {
                        self.parent.onError("Could not load receipt photo: \(error.localizedDescription)")
                        picker?.dismiss(animated: true)
                    } else {
                        self.parent.onError("The selected receipt photo could not be loaded.")
                        picker?.dismiss(animated: true)
                    }
                }
            }
        }

        @objc private func takePicture() {
            picker?.takePicture()
        }

        @objc private func openPhotoLibrary() {
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = .images
            configuration.selectionLimit = 1

            let photoPicker = PHPickerViewController(configuration: configuration)
            photoPicker.delegate = self
            picker?.present(photoPicker, animated: true)
        }

        @objc private func closeCamera() {
            parent.dismiss()
        }

        private static func normalizedImageData(from image: UIImage) -> Data? {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = image.scale
            let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
            let normalizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
            return normalizedImage.jpegData(compressionQuality: 0.92) ?? image.pngData()
        }
    }
}
#endif
