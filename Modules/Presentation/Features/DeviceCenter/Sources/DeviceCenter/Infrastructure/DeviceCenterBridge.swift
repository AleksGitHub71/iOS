/// This class facilitates communication between the parent of the Device Center feature and
///  the Device Center view models.
///  Acts as an abstraction to not pollute view model interface with many closures and makes testing easier

import Foundation
import MEGADomain

public class DeviceCenterBridge {
    public init() {}
    
    public typealias CameraUploadStatusChanged = () -> Void
    public var cameraUploadActionTapped: (@escaping CameraUploadStatusChanged) -> Void = { _ in }
    public var infoActionTapped: (NodeEntity) -> Void = { _ in }
    public var renameActionTapped: (RenameActionEntity) -> Void = { _ in }
    public var showInCDActionTapped: (NodeEntity) -> Void = { _ in }
    public var showInBackupsActionTapped: (NodeEntity) -> Void = { _ in }
    public var sortActionTapped: (NodeEntity, SortOrderEntity) -> Void = { _, _  in }
}
