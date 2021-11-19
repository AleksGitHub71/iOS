import UIKit
import PDFKit
import VisionKit

enum DocScanExportFileType: String {
    case pdf = "PDF"
    case jpg = "JPG"
}

enum DocScanQuality: Float, CustomStringConvertible {
    case best = 0.95
    case medium = 0.8
    case low = 0.7
    
    var description: String {
        switch self {
        case .best:
            return NSLocalizedString("best", comment: "")
        case .medium:
            return NSLocalizedString("medium", comment: "")
        case .low:
            return NSLocalizedString("low", comment: "")
        }
    }
    
    var imageSize: Int {
        switch self {
        case .best:
            return 3000
        case .medium:
            return 2500
        case .low:
            return 1500
        }
    }
}

class DocScannerSaveSettingTableViewController: UITableViewController {
    @objc var parentNode: MEGANode?
    @objc var docs: [UIImage]?
    @objc var chatRoom: MEGAChatRoom?
    var charactersNotAllowed: Bool = false
    
    @IBOutlet weak var sendButton: UIBarButtonItem!
    
    var originalFileName = NSLocalizedString("cloudDrive.scanDocument.defaultName", comment: "Default title given to the document created when you use the option 'Scan Document' in the app. For example: 'Scan 2021-11-09 14.40.41'")
    var currentFileName: String?
    
    private struct TableViewConfiguration {
        static let numberOfSections = 3
        static let numberOfRowsInFirstSection = 1
        static let numberOfRowsInSecondSection = 2
        static let numberOfRowsInThirdSection = 2
    }
    
    struct keys {
        static let docScanExportFileTypeKey = "DocScanExportFileTypeKey"
        static let docScanQualityKey = "DocScanQualityKey"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Save Settings", comment: "Setting title for Doc scan view")
        
        let currentDate = NSDate().mnz_formattedDefaultNameForMedia()
        originalFileName = originalFileName.replacingOccurrences(of: "%@", with: currentDate)
        currentFileName = originalFileName
        
        let fileType = UserDefaults.standard.string(forKey: keys.docScanExportFileTypeKey)
        let quality = UserDefaults.standard.string(forKey: keys.docScanQualityKey)
        if fileType == nil || docs?.count ?? 0 > 1  {
            UserDefaults.standard.set(DocScanExportFileType.pdf.rawValue, forKey: keys.docScanExportFileTypeKey)
        }
        if quality == nil {
            UserDefaults.standard.set(DocScanQuality.best.rawValue, forKey: keys.docScanQualityKey)
        }
        
        sendButton.title = NSLocalizedString("send", comment: "")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if chatRoom != nil {
            navigationController?.setToolbarHidden(false, animated: false)
        } else {
            navigationController?.setToolbarHidden(true, animated: false)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateAppearance()
            
            tableView.reloadData()
        }
    }
    
    // MARK: - Private
    
    @IBAction func sendAction(_ sender: Any) {
        
        guard isValidName() else {
            return
        }
        
        guard let chatRoom = chatRoom else {
            return
        }
        
        MEGASdkManager.sharedMEGASdk().getMyChatFilesFolder(completion: { (parentNode) in
            let paths = self.exportScannedDocs()
            paths.forEach { (path) in
                var appData = NSString().mnz_appData(toSaveCoordinates: path.mnz_coordinatesOfPhotoOrVideo() ?? "")
                appData = ((appData) as NSString).mnz_appDataToAttach(toChatID: chatRoom.chatId, asVoiceClip: false)
                ChatUploader.sharedInstance.upload(filepath: path,
                                                   appData: appData,
                                                   chatRoomId: chatRoom.chatId,
                                                   parentNode: parentNode,
                                                   isSourceTemporary: false,
                                                   delegate: MEGAStartUploadTransferDelegate(completion: nil))
            }
        })
        dismiss(animated: true, completion: nil)
    }
    
    private func isValidName() -> Bool {
        guard var currentFileName = currentFileName else {
            return false
        }
        
        currentFileName = currentFileName.trimmingCharacters(in: .whitespaces)
        let containsInvalidChars = currentFileName.mnz_containsInvalidChars()
        let empty = currentFileName.mnz_isEmpty()
        if containsInvalidChars || empty {
            let element = self.view.subviews.first(where: { $0 is DocScannerFileNameTableCell })
            let cell = element as? DocScannerFileNameTableCell
            cell?.filenameTextField.becomeFirstResponder()
            return false
        } else {
            return true
        }
    }
    
    private func putOriginalNameIfTextFieldIsEmpty() {
        let element = self.view.subviews.first(where: { $0 is DocScannerFileNameTableCell })
        let filenameTVC = element as? DocScannerFileNameTableCell
        guard let isFileNameTextFieldEmpty = filenameTVC?.filenameTextField.text?.isEmpty else { return }
        if isFileNameTextFieldEmpty {
            filenameTVC?.filenameTextField.text = originalFileName
        }
        
        filenameTVC?.filenameTextField.resignFirstResponder()
    }
    
    private func updateAppearance() {
        tableView.backgroundColor = .mnz_backgroundGrouped(for: traitCollection)
        tableView.separatorColor = .mnz_separator(for: traitCollection)
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if chatRoom != nil {
            return 2
        }
        return TableViewConfiguration.numberOfSections
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return TableViewConfiguration.numberOfRowsInFirstSection
        case 1:
            return TableViewConfiguration.numberOfRowsInSecondSection
        case 2:
            return TableViewConfiguration.numberOfRowsInThirdSection
        default:
            fatalError("please define a constant in struct TableViewConfiguration")
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()
        if indexPath.section == 0 {
            if let filenameCell = tableView.dequeueReusableCell(withIdentifier: DocScannerFileNameTableCell.reuseIdentifier, for: indexPath) as? DocScannerFileNameTableCell {
                let fileType = UserDefaults.standard.string(forKey: keys.docScanExportFileTypeKey)
                filenameCell.delegate = self
                filenameCell.configure(filename: originalFileName, fileType: fileType)
                cell = filenameCell
                
                if originalFileName != currentFileName {
                    filenameCell.filenameTextField.text = currentFileName
                }
                let containsInvalidChars = filenameCell.filenameTextField.text?.mnz_containsInvalidChars() ?? false
                filenameCell.filenameTextField.textColor = containsInvalidChars ? .mnz_redError() : .mnz_label()
            }
        } else if indexPath.section == 1 {
            if let detailCell = tableView.dequeueReusableCell(withIdentifier: DocScannerDetailTableCell.reuseIdentifier, for: indexPath) as? DocScannerDetailTableCell,
                let cellType = DocScannerDetailTableCell.CellType(rawValue: indexPath.row) {
                detailCell.cellType = cellType
                if docs?.count ?? 0 > 1 && indexPath.row == 0 {
                    detailCell.accessoryType = .none
                }
                
                cell = detailCell
            }
        } else {
            if let actionCell = tableView.dequeueReusableCell(withIdentifier: DocScannerActionTableViewCell.reuseIdentifier, for: indexPath) as?  DocScannerActionTableViewCell,
                let cellType = DocScannerActionTableViewCell.CellType(rawValue: indexPath.row) {
                actionCell.cellType = cellType
                cell = actionCell
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return charactersNotAllowed ? NSLocalizedString("general.error.charactersNotAllowed", comment: "Error message shown when trying to rename or create a folder with characters that are not allowed. We need the '\' before quotation mark, so it can be shown on code") : NSLocalizedString("tapFileToRename", comment: "")
            
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if section == 0 {
            let footer = view as! UITableViewHeaderFooterView
            footer.textLabel?.textAlignment = .center
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1:
            return NSLocalizedString("settingsTitle", comment: "")
        case 2:
            return NSLocalizedString("selectDestination", comment: "")
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 {
            switch indexPath.row {
            case 0:
                if docs?.count ?? 0 < 2 {
                    let alert = UIAlertController(title: nil, message: NSLocalizedString("File Type", comment: "file type title, used in changing the export format of scaned doc"), preferredStyle: .actionSheet)
                    let PDFAlertAction = UIAlertAction(title: "PDF", style: .default, handler: { _ in
                        UserDefaults.standard.set(DocScanExportFileType.pdf.rawValue, forKey: keys.docScanExportFileTypeKey)
                        tableView.reloadData()
                    })
                    alert.addAction(PDFAlertAction)
                    
                    let JPGAlertAction = UIAlertAction(title: "JPG", style: .default, handler: { _ in
                        UserDefaults.standard.set(DocScanExportFileType.jpg.rawValue, forKey: keys.docScanExportFileTypeKey)
                        tableView.reloadData()
                    })
                    alert.addAction(JPGAlertAction)
                    
                    if let popover = alert.popoverPresentationController {
                        popover.sourceView = tableView
                        popover.sourceRect = tableView.rectForRow(at: indexPath)
                    }
                    
                    alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
                    
                    present(alert, animated: true, completion: nil)
                }
            case 1:
                let alert = UIAlertController(title: nil, message:
                    NSLocalizedString("Quality", comment: "Quality title, used in changing the export quality of scaned doc"), preferredStyle: .actionSheet)
                let bestAlertAction = UIAlertAction(title: DocScanQuality.best.description, style: .default, handler: { _ in
                    UserDefaults.standard.set(DocScanQuality.best.rawValue, forKey: keys.docScanQualityKey)
                    tableView.reloadRows(at: [indexPath], with: .none)
                })
                alert.addAction(bestAlertAction)
                
                let mediumAlertAction = UIAlertAction(title: DocScanQuality.medium.description, style: .default, handler: { _ in
                    UserDefaults.standard.set(DocScanQuality.medium.rawValue, forKey: keys.docScanQualityKey)
                    tableView.reloadRows(at: [indexPath], with: .none)
                })
                alert.addAction(mediumAlertAction)
                
                let lowAlertAction = UIAlertAction(title:  DocScanQuality.low.description, style: .default, handler: { _ in
                    UserDefaults.standard.set(DocScanQuality.low.rawValue, forKey: keys.docScanQualityKey)
                    tableView.reloadRows(at: [indexPath], with: .none)
                })
                alert.addAction(lowAlertAction)
                
                if let popover = alert.popoverPresentationController {
                    popover.sourceView = tableView
                    popover.sourceRect = tableView.rectForRow(at: indexPath)
                }
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
                
                present(alert, animated: true, completion: nil)
            default: break
            }
        } else if indexPath.section == 2 {
            guard isValidName() else {
                return
            }
            
            putOriginalNameIfTextFieldIsEmpty()
            
            switch indexPath.row {
            case 0:
                let storyboard = UIStoryboard(name: "Cloud", bundle: Bundle(for: BrowserViewController.self))
                if let browserVC = storyboard.instantiateViewController(withIdentifier: "BrowserViewControllerID") as? BrowserViewController {
                    browserVC.browserAction = .shareExtension
                    browserVC.parentNode = parentNode
                    browserVC.isChildBrowser = true
                    browserVC.browserViewControllerDelegate = self
                    navigationController?.setToolbarHidden(false, animated: true)
                    navigationController?.pushViewController(browserVC, animated: true)
                }
            case 1:
                let storyboard = UIStoryboard(name: "Chat", bundle: Bundle(for: SendToViewController.self))
                if let sendToViewController = storyboard.instantiateViewController(withIdentifier: "SendToViewControllerID") as? SendToViewController {
                    sendToViewController.sendToViewControllerDelegate = self
                    sendToViewController.sendMode = .shareExtension
                    navigationController?.pushViewController(sendToViewController, animated: true)
                }
            default: break
            }
            
        }
    }
}

extension DocScannerSaveSettingTableViewController: DocScannerFileInfoTableCellDelegate {
    func filenameChanged(_ newFilename: String) {
        currentFileName = newFilename
    }
    
    func containsCharactersNotAllowed() {
        if !charactersNotAllowed {
            charactersNotAllowed = true
            tableView.reloadSections(IndexSet.init(integer: 0), with: .none)
        }
    }
}

extension DocScannerSaveSettingTableViewController: BrowserViewControllerDelegate {
    func upload(toParentNode parentNode: MEGANode) {
        let paths = exportScannedDocs()
        paths.forEach { (path) in
            let appData = NSString().mnz_appData(toSaveCoordinates: path.mnz_coordinatesOfPhotoOrVideo() ?? "")
            MEGASdkManager.sharedMEGASdk().startUpload(withLocalPath: path, parent: parentNode, appData: appData, isSourceTemporary: true)
        }
        dismiss(animated: true, completion: nil)
    }
}

extension DocScannerSaveSettingTableViewController: SendToViewControllerDelegate {
    func send(_ viewController: SendToViewController, toChats chats: [MEGAChatListItem], andUsers users: [MEGAUser]) {
        MEGASdkManager.sharedMEGASdk().getMyChatFilesFolder(completion: { (node) in
            let paths = self.exportScannedDocs()
            var completionCounter = 0
            paths.forEach { (path) in
                let appData = NSString().mnz_appData(toSaveCoordinates: path.mnz_coordinatesOfPhotoOrVideo() ?? "")
                let startUploadTransferDelegate = MEGAStartUploadTransferDelegate { (transfer) in
                    let node = MEGASdkManager.sharedMEGASdk().node(forHandle: transfer!.nodeHandle)
                    chats.forEach { chatRoom in
                        MEGASdkManager.sharedMEGAChatSdk().attachNode(toChat: chatRoom.chatId, node: node!.handle)
                    }
                    users.forEach { user in
                        if let chatRoom = MEGASdkManager.sharedMEGAChatSdk().chatRoom(byUser: user.handle) {
                            MEGASdkManager.sharedMEGAChatSdk().attachNode(toChat: chatRoom.chatId, node: node!.handle)
                        } else {
                            MEGASdkManager.sharedMEGAChatSdk().mnz_createChatRoom(userHandle: user.handle, completion: { (chatRoom) in
                                MEGASdkManager.sharedMEGAChatSdk().attachNode(toChat: chatRoom.chatId, node: node!.handle)
                            })
                        }
                    }
                    if completionCounter == self.docs!.count - 1 {
                        SVProgressHUD.showSuccess(withStatus: NSLocalizedString("Shared successfully", comment: "Success message shown when the user has successfully shared something"))
                    }
                    completionCounter = completionCounter + 1
                }
                MEGASdkManager.sharedMEGASdk().startUploadForChat(withLocalPath: path, parent: node, appData: appData, isSourceTemporary: true, delegate: startUploadTransferDelegate!)
            }
        })
        dismiss(animated: true, completion: nil)
    }
}

extension DocScannerSaveSettingTableViewController {
    private func exportScannedDocs() -> [String] {
        guard let storedExportFileTypeKey = UserDefaults.standard.string(forKey: keys.docScanExportFileTypeKey) else {
            MEGALogDebug("No stored value found for docScanExportFileTypeKey")
            return []
        }
        let fileType = DocScanExportFileType(rawValue: storedExportFileTypeKey)
        let scanQuality = DocScanQuality(rawValue: UserDefaults.standard.float(forKey: keys.docScanQualityKey)) ?? .best
        var tempPaths: [String] = []
        if fileType == .pdf {
            let pdfDoc = PDFDocument()
            docs?.enumerated().forEach {
                if let shrinkedImageData = $0.element.shrinkedImageData(docScanQuality: scanQuality),
                   let shrinkedImage = UIImage(data: shrinkedImageData),
                   let pdfPage = PDFPage(image: shrinkedImage) {
                    pdfDoc.insert(pdfPage, at: $0.offset)
                } else {
                    MEGALogDebug(String(format: "could not create PdfPage at index %d", $0.offset))
                }
            }
            
            if let data = pdfDoc.dataRepresentation() {
                let fileName = "\(currentFileName ?? originalFileName).pdf"
                let tempPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(fileName)
                do {
                    try data.write(to: URL(fileURLWithPath: tempPath), options: .atomic)
                    tempPaths.append(tempPath)
                } catch {
                    MEGALogDebug("Could not write to file \(tempPath) with error \(error.localizedDescription)")
                }
            } else {
                MEGALogDebug("Cannot convert pdf doc to data representation")
            }
        } else if fileType == .jpg {
            docs?.enumerated().forEach {
                if let data = $0.element.shrinkedImageData(docScanQuality: scanQuality) {
                    let fileName = (self.docs?.count ?? 1 > 1) ? "\(currentFileName ?? originalFileName) \($0.offset + 1).jpg" : "\(currentFileName ?? originalFileName).jpg"
                    let tempPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(fileName)
                    do {
                        try data.write(to: URL(fileURLWithPath: tempPath), options: .atomic)
                        tempPaths.append(tempPath)
                    } catch {
                        MEGALogDebug("Could not write to file \(tempPath) with error \(error.localizedDescription)")
                    }
                } else {
                    MEGALogDebug("Unable to fetch the stored DocScanQuality")
                }
            }
        }
        return tempPaths
    }
}
