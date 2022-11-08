import Foundation

enum ZoomType {
    case `in`
    case out
}

struct PhotoLibraryZoomState: Equatable {
    enum ScaleFactor: Int, CaseIterable, Equatable {
        case one = 1
        case three = 3
        case five = 5
        case thirteen = 13
    }
    
    private let supportedScaleFactors = ScaleFactor.allCases
    
    static let defaultScaleFactor: ScaleFactor = .three

    var scaleFactor: ScaleFactor = .three
    var maximumScaleFactor: ScaleFactor = .five
    
    func canZoom(_ type: ZoomType) -> Bool {
        switch type {
        case .in:
            return scaleFactor != supportedScaleFactors.first
        case .out:
            return scaleFactor != maximumScaleFactor
        }
    }
    
    mutating func zoom(_ type: ZoomType) {
        guard canZoom(type) else {
            return
        }
        
        guard let scaleIndex = supportedScaleFactors.firstIndex(of: scaleFactor) else {
            scaleFactor = Self.defaultScaleFactor // Uses default scale if the current scale doesn't match our supported scales
            return
        }
        
        switch type {
        case .in:
            let index = supportedScaleFactors.index(before: scaleIndex)
            scaleFactor = supportedScaleFactors[index]
        case .out:
            let index = supportedScaleFactors.index(after: scaleIndex)
            scaleFactor = supportedScaleFactors[index]
        }
    }
}
