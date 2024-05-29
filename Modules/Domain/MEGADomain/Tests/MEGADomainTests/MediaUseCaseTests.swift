import MEGADomain
import MEGADomainMock
import XCTest

final class MediaUseCaseTests: XCTestCase {
    let sut = MediaUseCase(fileSearchRepo: MockFilesSearchRepository.newRepo)
    
    func testIsImage() {
        for fileExtension in ImageFileExtensionEntity().imagesSupportedExtensions {
            let name = "image.\(fileExtension)"
            XCTAssertTrue(sut.isImage(name))
        }
    }
    
    func testIsNotImage() {
        let name = "notImage.doc"
        XCTAssertFalse(sut.isImage(name))
    }
    
    func testIsVideo() {
        for fileExtension in VideoFileExtensionEntity().videoSupportedExtensions {
            let name = "video.\(fileExtension)"
            XCTAssertTrue(sut.isVideo(name))
        }
    }
    
    func testIsNotVideo() {
        let name = "notVideo.pdf"
        XCTAssertFalse(sut.isVideo(name))
    }
    
    func testIsMultimedia() {
        for fileExtension in VideoFileExtensionEntity().videoSupportedExtensions {
            let name = "video.\(fileExtension)"
            XCTAssertTrue(sut.isMultimedia(name))
        }
        
        for fileExtension in ImageFileExtensionEntity().imagesSupportedExtensions {
            let name = "image.\(fileExtension)"
            XCTAssertTrue(sut.isMultimedia(name))
        }
    }
    
    func testIsNotMultimedia() {
        let name = "notVideo.pdf"
        XCTAssertFalse(sut.isVideo(name))
    }
    
    func testIsRawImage_whenFilteringPhotos_shouldReturnTrue() {
        for fileExtension in RawImageFileExtensionEntity().imagesSupportedExtensions {
            let name = "image.\(fileExtension)"
            XCTAssertTrue(sut.isRawImage(name))
        }
    }
    
    func testIsNotRawImage_whenFilteringPhotos_shouldReturnFalse() {
        let name1 = "image.jpg"
        let name2 = "5.gif"
        XCTAssertFalse(sut.isRawImage(name1))
        XCTAssertFalse(sut.isRawImage(name2))
    }
    
    func testIsGifImage_whenFilteringPhotos_shouldReturnTrue() {
        let name = "image.gif"
        XCTAssertTrue(sut.isGifImage(name))
    }
    
    func testIsGifImage_whenFilteringPhotos_shouldReturnFalse() {
        let name = "image.jpg"
        XCTAssertFalse(sut.isGifImage(name))
    }
    
    // MARK: - Private
    
    private func photoNodes() -> [NodeEntity] {
        [NodeEntity(name: "1.raw", handle: 1),
         NodeEntity(name: "2.nef", handle: 2),
         NodeEntity(name: "3.cr2", handle: 3),
         NodeEntity(name: "4.dng", handle: 4),
         NodeEntity(name: "5.gif", handle: 5)
        ]
    }
    
    private func videoNodes() -> [NodeEntity] {
        [NodeEntity(name: "1.mp4", handle: 1),
         NodeEntity(name: "2.mov", handle: 2)
        ]
    }
}
