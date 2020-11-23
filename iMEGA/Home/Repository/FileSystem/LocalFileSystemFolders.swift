import Foundation

struct TemporaryDirectoryFinding {

    var searchFor: (SearchType) throws -> URL?
}

extension TemporaryDirectoryFinding {

    static var live: Self {
        return Self(searchFor:  { searchType in
            let temporaryDirectory = FileManager.default.temporaryDirectory()
            let sdk = MEGASdkManager.sharedMEGASdk()
            switch searchType {
            case let .node(handle: handle, name: name, fingerprint):
                if let nodeTemporaryDirectoryURL = urlForNode(handle, name: name, in: temporaryDirectory),
                   sdk.fingerprint(forFilePath: nodeTemporaryDirectoryURL.path) == fingerprint {
                        return nodeTemporaryDirectoryURL
                }
            }
            return nil
        })
    }

    private static func urlForNode(_ nodeHandle: MEGABase64Handle, name: String, in directory: String?) -> URL? {
        guard let directory = directory else { return nil }
        return URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent(nodeHandle)
            .appendingPathComponent(name)
    }
}

extension TemporaryDirectoryFinding {
    enum SearchType {
        case node(handle: MEGABase64Handle, name: String, fingerprint: String)
    }
}
