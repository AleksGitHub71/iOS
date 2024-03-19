import MEGADomain
import MEGAL10n
import MEGAPermissions

protocol AssetUploader {
    func upload(assets: [PHAsset], to handle: MEGAHandle)
}

struct CloudDrivePhotosPickerRouter {
    private let parentNode: NodeEntity
    private let presenter: UIViewController
    private let assetUploader: any AssetUploader

    private var permissionHandler: any DevicePermissionsHandling {
        DevicePermissionsHandler.makeHandler()
    }

    private var permissionRouter: PermissionAlertRouter {
        .makeRouter(deviceHandler: permissionHandler)
    }

    init(parentNode: NodeEntity, presenter: UIViewController, assetUploader: some AssetUploader) {
        self.parentNode = parentNode
        self.presenter = presenter
        self.assetUploader = assetUploader
    }

    func start() {
        permissionHandler.photosPermissionWithCompletionHandler { granted in
            if granted {
                loadPhotoAlbumBrowser()
            } else {
                permissionRouter.alertPhotosPermission()
            }
        }
    }

    private func loadPhotoAlbumBrowser() {
        let albumTableViewController = AlbumsTableViewController(
            selectionActionType: .upload,
            selectionActionDisabledText: Strings.Localizable.upload
        ) { assetUploader.upload(assets: $0, to: parentNode.handle) }

        let navigationController = MEGANavigationController(rootViewController: albumTableViewController)
        presenter.present(navigationController, animated: true)
    }
}
