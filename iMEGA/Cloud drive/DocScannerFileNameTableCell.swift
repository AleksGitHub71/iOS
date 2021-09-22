
import UIKit

protocol DocScannerFileInfoTableCellDelegate: AnyObject {
    func filenameChanged(_ newFilename: String)
}

class DocScannerFileNameTableCell: UITableViewCell {
    @IBOutlet weak var fileImageView: UIImageView!
    @IBOutlet weak var filenameTextField: UITextField!
    
    weak var delegate: DocScannerFileInfoTableCellDelegate?
    
    var originalFilename: String? {
        didSet {
            filenameTextField?.placeholder = originalFilename
        }
    }
    var currentFilename: String? {
        didSet {
            filenameTextField?.text = currentFilename
        }
    }
    
    func configure(filename: String, fileType: String?) {
        backgroundColor = .mnz_secondaryBackgroundGrouped(traitCollection)
        
        self.originalFilename = filename
        self.currentFilename = filename
        fileImageView.mnz_setImage(forExtension: fileType)
    }
}

extension DocScannerFileNameTableCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        if textField.text?.count == 0 {
            guard let originalFileName = originalFilename else {
                return true
            }
            textField.text = originalFileName
        }
        
        return true
    }
    
    @IBAction func textFiledEditingChanged(_ textField: UITextField) {
        guard let text = textField.text else {
            return
        }
        
        if textField.text?.count == 0 {
            guard let originalFileName = originalFilename else {
                return
            }
            delegate?.filenameChanged(originalFileName)
        } else {
            let containsInvalidChars = textField.text?.mnz_containsInvalidChars() ?? false
            textField.textColor = containsInvalidChars ? UIColor.mnz_redError() : UIColor.mnz_label()
            currentFilename = text
            delegate?.filenameChanged(text)
        }
    }
}
