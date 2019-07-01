
import Contacts
import ContactsUI
import MessageUI
import UIKit

class InviteContactViewController: UIViewController {

    var contactsOnMega = [Any]()
    var userLink = String()
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var contactsOnMegaHeader: UIView!
    @IBOutlet weak var contactsOnMegaHeaderTitle: UILabel!
    @IBOutlet weak var addFromContactsLabel: UILabel!
    @IBOutlet weak var enterEmailLabel: UILabel!
    @IBOutlet weak var scanQrCodeLabel: UILabel!
    @IBOutlet weak var moreLabel: UILabel!

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("inviteContact", comment: "Text shown when the user tries to make a call and the receiver is not a contact")
        
        let contactLinkCreateDelegate = MEGAContactLinkCreateRequestDelegate { (request) in
            self.userLink = String(format: "https://mega.nz/C!%@", MEGASdk.base64Handle(forHandle: request!.nodeHandle))
        }
        MEGASdkManager.sharedMEGASdk()?.contactLinkCreateRenew(false, delegate: contactLinkCreateDelegate)

        tableView.register(ContactsPermissionBottomView().nib(), forHeaderFooterViewReuseIdentifier: ContactsPermissionBottomView().bottomReuserIdentifier())

        contactsOnMega = ContactsOnMegaManager.shared.fetchContactsOnMega() ?? []
    }
    
    // MARK: Actions
    @IBAction func addFromContactsButtonTapped(_ sender: Any) {
        let contactsPickerVC = CNContactPickerViewController()
        contactsPickerVC.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        contactsPickerVC.predicateForSelectionOfProperty = NSPredicate(format: "key == 'phoneNumbers'")
        contactsPickerVC.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        contactsPickerVC.delegate = self
        
        present(contactsPickerVC, animated: true, completion: nil)
    }
    
    @IBAction func enterEmailButtonTapped(_ sender: Any) {
        guard let enterEmailVC = UIStoryboard(name: "Contacts", bundle: nil).instantiateViewController(withIdentifier: "EnterEmailViewControllerID") as? EnterEmailViewController else { return }
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationController?.pushViewController(enterEmailVC, animated: true)
    }
    
    @IBAction func scanQrCodeButtonTapped(_ sender: Any) {
        guard let contactLinkVC = UIStoryboard(name: "Contacts", bundle: nil).instantiateViewController(withIdentifier: "ContactLinkQRViewControllerID") as? ContactLinkQRViewController  else { return }
        contactLinkVC.scanCode = true
        present(contactLinkVC, animated: true, completion: nil)
    }
    
    @IBAction func moreButtonTapped(_ sender: Any) {
        let vc = UIActivityViewController(activityItems: [userLink], applicationActivities: [])
        present(vc, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension InviteContactViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if CNContactStore.authorizationStatus(for: CNEntityType.contacts) == CNAuthorizationStatus.authorized {
            return contactsOnMega.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "contactOnMegaCell", for: indexPath)
    }
}

// MARK: - UITableViewDelegate
extension InviteContactViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        contactsOnMegaHeaderTitle.text = NSLocalizedString("Contacts on MEGA", comment: "Text used as a section title or similar showing the user the phone contacts using MEGA").uppercased()
        return contactsOnMegaHeader
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 24
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch CNContactStore.authorizationStatus(for: CNEntityType.contacts) {
        case .notDetermined:
            guard let bottomView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ContactsPermissionBottomView().bottomReuserIdentifier()) as? ContactsPermissionBottomView else {
                return UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
            }
            bottomView.configureForRequestingPermission ( action: {
                DevicePermissionsHelper.contactsPermission { (granted) in
                    if granted {
                        ContactsOnMegaManager.shared.configureContactsOnMega(completion: {
                            self.contactsOnMega = ContactsOnMegaManager.shared.fetchContactsOnMega() ?? []
                            tableView.reloadData()
                        })
                    }
                }
            })
            return bottomView
            
        case .restricted, .denied:
            guard let bottomView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ContactsPermissionBottomView().bottomReuserIdentifier()) as? ContactsPermissionBottomView else {
                return UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
            }
            bottomView.configureForOpenSettingsPermission( action: {
                UIApplication.shared.openURL(URL(string: UIApplication.openSettingsURLString)!)
            })
            
            return bottomView
            
        case .authorized:
            return UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
            
        @unknown default:
            return UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
            
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return tableView.frame.height
    }
}

// MARK: - DZNEmptyDataSetSource
extension InviteContactViewController: DZNEmptyDataSetSource {
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        if (MEGAReachabilityManager.isReachable()) {
            return UIImage(named: "contactsEmptyState")
        } else {
            return UIImage(named: "noInternetEmptyState")
        }
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        if (MEGAReachabilityManager.isReachable()) {
            return NSAttributedString(string: NSLocalizedString("contactsEmptyState_title", comment: "Title shown when the Contacts section is empty, when you have not added any contact."))
        } else {
            return NSAttributedString(string: NSLocalizedString("noInternetConnection", comment: "No Internet Connection"))
        }
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        if (MEGAReachabilityManager.isReachable()) {
            return NSAttributedString(string: NSLocalizedString("Invite contacts and start chatting securely with MEGA’s encrypted chat.", comment: "Text encouraging the user to invite contacts to MEGA"))
        } else {
            return nil
        }
    }
}

// MARK: - CNContactPickerDelegate
extension InviteContactViewController: CNContactPickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
        var phones = [String]()
        for contact in contacts {
            for contactProperty in contact.phoneNumbers {
                let phoneNumber = contactProperty.value.stringValue.replacingOccurrences(of: " ", with: "")
                phones.append(phoneNumber)
            }
        }
        
        picker.dismiss(animated: true) {
            if phones.count > 0 {
                let composeVC = MFMessageComposeViewController()
                composeVC.messageComposeDelegate = self
                composeVC.recipients = phones
                composeVC.body = NSLocalizedString("Hi, Have encrypted conversations on Mega with me and get 50GB free storage.", comment: "Text to send as SMS message to user contacts inviting them to MEGA") + " " + self.userLink
                self.present(composeVC, animated: true, completion: nil)
            }
        }
    }
}

// MARK: - MFMessageComposeViewControllerDelegate
extension InviteContactViewController: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        switch result {
        case .failed:
            controller.present(UIAlertController(title: "Something went wrong", message: "Try it later", preferredStyle: .alert), animated: true, completion: nil)
            
        case .cancelled, .sent:
            controller.dismiss(animated: true, completion: nil)

        @unknown default:
            controller.dismiss(animated: true, completion: nil)
        }
    }
}
