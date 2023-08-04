import MEGADomain
import MEGAPresentation
import MEGASDKRepo
import UIKit

struct SlideShowRouter: Routing {
    private weak var presenter: UIViewController?
    private let dataProvider: PhotoBrowserDataProvider
    
    init(dataProvider: PhotoBrowserDataProvider, presenter: UIViewController?) {
        self.dataProvider = dataProvider
        self.presenter = presenter
    }
    
    private func configSlideShowViewModel() -> SlideShowViewModel {
        let photoEntities = dataProvider.fetchOnlyPhotoEntities(mediaUseCase: MediaUseCase(fileSearchRepo: FilesSearchRepository.newRepo))
        
        var preferenceRepo: PreferenceRepository
        if let slideshowUserDefaults = UserDefaults(suiteName: "slideshow") {
            preferenceRepo = PreferenceRepository(userDefaults: slideshowUserDefaults)
        } else {
            preferenceRepo = PreferenceRepository.newRepo
        }
        
        return SlideShowViewModel(dataSource: slideShowDataSource(photos: photoEntities),
                                  slideShowUseCase: SlideShowUseCase(preferenceRepo: preferenceRepo),
                                  accountUseCase: AccountUseCase(repository: AccountRepository.newRepo))
    }
    
    private func slideShowDataSource(photos: [NodeEntity]) -> SlideShowDataSource {
        SlideShowDataSource(
            currentPhoto: dataProvider.currentPhotoNodeEntity,
            nodeEntities: photos,
            thumbnailUseCase: dataProvider.makeThumbnailUseCase(),
            fileDownloadUseCase: FileDownloadUseCase(fileCacheRepository: FileCacheRepository.newRepo,
                                                     fileSystemRepository: FileSystemRepository.newRepo,
                                                     downloadFileRepository: DownloadFileRepository.newRepo),
            mediaUseCase: MediaUseCase(fileSearchRepo: FilesSearchRepository.newRepo),
            fileExistenceUseCase: FileExistUseCase(fileSystemRepository: FileSystemRepository.newRepo),
            advanceNumberOfPhotosToLoad: 20,
            numberOfUnusedPhotosBuffer: 20
        )
    }
    
    func build() -> UIViewController {
        let storyboard: UIStoryboard = UIStoryboard(name: "Slideshow", bundle: nil)
        let slideShowVC = storyboard.instantiateInitialViewController() as! SlideShowViewController
        let vm = configSlideShowViewModel()
        slideShowVC.update(viewModel: vm)
        return slideShowVC
    }
    
    func start() {
        guard let slideshowVC = build() as? SlideShowViewController else { return }
        presenter?.present(slideshowVC, animated: true)
    }
}
