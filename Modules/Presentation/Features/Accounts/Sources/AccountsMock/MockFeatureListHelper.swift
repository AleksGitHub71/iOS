import Accounts

public struct MockFeatureListHelper: FeatureListHelperProtocol {
    private var features: [FeatureDetails]
    
    public init(features: [FeatureDetails]) {
        self.features = features
    }
    
    public func createCurrentFeatures() -> [FeatureDetails] {
        features
    }
}
