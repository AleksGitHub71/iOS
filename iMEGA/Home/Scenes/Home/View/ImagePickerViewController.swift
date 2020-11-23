import UIKit
import CoreServices
import Photos

final class UploadImagePickerViewController: UIImagePickerController {

    var completion: ((Result<String, ImagePickingError>) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.modalPresentationStyle = .currentContext
        videoQuality = .typeHigh
        delegate = self
    }

    // MARK: - Public

    func prepare(
        withSourceType sourceType: SourceType,
        completion: @escaping (Result<String, ImagePickingError>) -> Void
    ) throws {
        try createTemporaryDirectory()
        try isSourceTypeAvailable(sourceType)

        self.completion = completion

        if let avaialbeMediaTypes = UIImagePickerController.availableMediaTypes(for: sourceType) {
            mediaTypes = avaialbeMediaTypes
        }
    }

    // MARK: - FileSystem

    private func createTemporaryDirectory() throws {
        do {
            try FileManager.default.createDirectory(
                atPath: NSTemporaryDirectory(),
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw ImagePickingError.failedCreateTemporaryData
        }
    }
    
    private func isSourceTypeAvailable(_ sourceType: SourceType) throws {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            throw ImagePickingError.sourceTypeIsNotAvailable
        }
        self.sourceType = sourceType
    }
}

// MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate

extension UploadImagePickerViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
    ) {
        guard let mediaType = info[InfoKey.mediaType] as? String else { return }

        if mediaType == (kUTTypeImage as String) {
            processImageType(with: info[.originalImage] as! UIImage)
            return
        }

        if mediaType == (kUTTypeMovie as String) {
            processMovieType(with: info[.mediaURL] as! URL)
            return
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Post Process Medias

    private func processImageType(with image: UIImage) {
        let imageName = NSDate().mnz_formattedDefaultNameForMedia() + ".jpg"
        guard let imagePath = FileManager.default.uploadsDirectory()?.appending(imageName),
            let imageAsData = image.jpegData(compressionQuality: 1) as NSData? else {
            completion?(.failure(.failedCreateTemporaryData))
            return
        }
        imageAsData.write(toFile: imagePath, atomically: true)

        // MARK: - Write some defaults

        if !UserDefaults.standard.bool(forKey: "isSaveMediaCapturedToGalleryEnabled") {
            UserDefaults.standard.set(true, forKey: "isSaveMediaCapturedToGalleryEnabled")
        }

        if UserDefaults.standard.bool(forKey: "isSaveMediaCapturedToGalleryEnabled") {
            createAsset(fromFilePath: imagePath, forAssetType: .photo)
        } else {
            completion?(.success(relativeLocalPath(imagePath)))
        }
    }

    private func relativeLocalPath(_ filePath: String) -> String {
        (filePath as NSString).mnz_relativeLocalPath()
    }

    private func processMovieType(with videoURL: URL) {
        do {
            let videoAttributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
            guard let modificationDate = videoAttributes[FileAttributeKey.modificationDate] as? NSDate else {
                completion?(.failure(.failedCreateTemporaryData))
                return
            }

            let videoName = modificationDate.mnz_formattedDefaultNameForMedia().appending(".mov")
            guard let localFilePath = FileManager.default.uploadsDirectory()?.appending(videoName) else {
                completion?(.failure(.failedCreateTemporaryData))
                return
            }

            try FileManager.default.moveItem(atPath: videoURL.path, toPath: localFilePath)

            var isSaveMediaCapturedToGalleryEnabled = false
            if !UserDefaults.standard.bool(forKey: "isSaveMediaCapturedToGalleryEnabled") {
                UserDefaults.standard.set(true, forKey: "isSaveMediaCapturedToGalleryEnabled")
                isSaveMediaCapturedToGalleryEnabled = true
            }

            if isSaveMediaCapturedToGalleryEnabled {
                createAsset(fromFilePath: localFilePath, forAssetType: .video)
            } else {
                completion?(.success(relativeLocalPath(localFilePath)))
            }

        } catch {
            completion?(.failure(.sourceTypeIsNotAvailable))
        }
    }

    private func createAsset(fromFilePath filePath: String, forAssetType assetType: PHAssetResourceType) {

        func relativeLocalPath(_ filePath: String) -> String {
            (filePath as NSString).mnz_relativeLocalPath()
        }

        let assetURL = URL(fileURLWithPath: filePath)

        PHPhotoLibrary.shared().performChanges({
            let assetCreationRequest = PHAssetCreationRequest.forAsset()
            assetCreationRequest.addResource(with: assetType, fileURL: assetURL, options: nil)
        }) { [completion] (success, error) in
            guard success else {
                completion?(.success(relativeLocalPath(filePath)))
                return
            }

            switch assetType {
            case .photo, .video: completion?(.success(relativeLocalPath(filePath)))
            default:
                completion?(.failure(.unsupportedFileType))
            }
        }
    }
}

enum ImagePickingPurpose {
    case uploading
}

enum ImagePickingError: Error {
    case failedCreateTemporaryData
    case sourceTypeIsNotAvailable
    case unsupportedFileType
}
