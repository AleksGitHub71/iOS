
import UIKit

enum SortingAndViewSection: Int {
    case sortingPreference = 0
    case viewModePreference = 1
}

class SortingAndViewModeTableViewController: UITableViewController {
    
    @IBOutlet weak var sortingPreferencePerFolderLabel: UILabel!
    @IBOutlet weak var sortingPreferenceSameForAllLabel: UILabel!
    @IBOutlet weak var sortingPreferenceSameForAllDetailLabel: UILabel!
    
    @IBOutlet weak var viewModePreferencePerFolderLabel: UILabel!
    @IBOutlet weak var viewModePreferenceListViewLabel: UILabel!
    @IBOutlet weak var viewModePreferenceThumbnailViewLabel: UILabel!
    
    var sortingPreference = UserDefaults.standard.integer(forKey: MEGASortingPreference)
    var viewModePreference = UserDefaults.standard.integer(forKey: MEGAViewModePreference)
    
    let localizedSortByStringsArray = [NSLocalizedString("nameAscending", comment: "Sort by option (1/6). This one orders the files alphabethically"), NSLocalizedString("nameDescending", comment: "Sort by option (2/6). This one arranges the files on reverse alphabethical order"), NSLocalizedString("largest", comment: "Sort by option (3/6). This one order the files by its size, in this case from bigger to smaller size"), NSLocalizedString("smallest", comment: "Sort by option (4/6). This one order the files by its size, in this case from smaller to bigger size"), NSLocalizedString("newest", comment: "Sort by option (5/6). This one order the files by its modification date, newer first"), NSLocalizedString("oldest", comment: "Sort by option (6/6). This one order the files by its modification date, older first")]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Sorting And View Mode", comment: "Inside of Settings - Appearance, there is a view on which you can change the sorting preferences or the view mode preference for the app")
        
        sortingPreferencePerFolderLabel.text = NSLocalizedString("Per Folder", comment: "Per folder configuration. For example the options for 'Sorting Preference' in the app are: 'Per Folder' and 'Same for all Folders'.")
        sortingPreferenceSameForAllLabel.text = NSLocalizedString("Same for All", comment: "Same for all configuration. For example the options for 'Sorting Preference' in the app are: 'Per Folder' and 'Same for all Folders'.")
        sortingPreferenceSameForAllDetailLabel.text = NSLocalizedString("choosePhotoVideo", comment: "Menu option from the `Add` section that allows the user to choose a photo or video to upload it to MEGA.")
        
        viewModePreferencePerFolderLabel.text = NSLocalizedString("Per Folder", comment: "Per folder configuration. For example the options for 'Sorting Preference' in the app are: 'Per Folder' and 'Same for all Folders'.")
        viewModePreferenceListViewLabel.text = NSLocalizedString("List View", comment: "Text shown for switching from thumbnail view to list view.")
        viewModePreferenceThumbnailViewLabel.text = NSLocalizedString("Thumbnail View", comment: "Text shown for switching from list view to thumbnail view.")
        
        updateAppearance()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(processSortingPreferenceNotification(_:)), name: Notification.Name(MEGASortingPreference), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(processViewModePreferenceNotification(_:)), name: Notification.Name(MEGAViewModePreference), object: nil)
        
        setupUI()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 13, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                updateAppearance()
            }
        }
    }
    
    // MARK: - Private
    
    private func updateAppearance() {
        sortingPreferenceSameForAllDetailLabel.textColor = UIColor.mnz_secondaryLabel()
        
        tableView.separatorColor = UIColor.mnz_separator(for: traitCollection)
        tableView.backgroundColor = UIColor.mnz_backgroundGrouped(for: traitCollection)
        
        tableView.reloadData()
    }
    
    private func setupUI() {
        sortingPreference = UserDefaults.standard.integer(forKey: MEGASortingPreference)
        switch sortingPreference {
        case SortingPreference.perFolder.rawValue:
            let selectedSortingPreferenceCell = tableView.cellForRow(at: IndexPath.init(row: sortingPreference, section: SortingAndViewSection.sortingPreference.rawValue)) as! SelectableTableViewCell
            selectedSortingPreferenceCell.redCheckmarkImageView.isHidden = false
            
        case SortingPreference.sameForAll.rawValue:
            setupSortingPreferenceSameForAllDetailLabel(orderType: UserDefaults.standard.integer(forKey: MEGASortingPreferenceType))
            
        default:
            return
        }
        
        viewModePreference = UserDefaults.standard.integer(forKey: MEGAViewModePreference)
        let selectedViewModePreferenceCell = tableView.cellForRow(at: IndexPath.init(row: viewModePreference, section: SortingAndViewSection.viewModePreference.rawValue)) as! SelectableTableViewCell
        selectedViewModePreferenceCell.redCheckmarkImageView.isHidden = false
    }
    
    @objc func processSortingPreferenceNotification(_ notification:Notification) {
        let selectedSortingPreference = notification.userInfo?[MEGASortingPreference] as! Int
        if selectedSortingPreference == SortingPreference.sameForAll.rawValue && sortingPreference != selectedSortingPreference {
            let previousSelectedViewModePreferenceCell = tableView.cellForRow(at: IndexPath.init(row: sortingPreference, section: SortingAndViewSection.sortingPreference.rawValue)) as! SelectableTableViewCell
            previousSelectedViewModePreferenceCell.redCheckmarkImageView.isHidden = true
        }
        
        sortingPreference = selectedSortingPreference
        setupSortingPreferenceSameForAllDetailLabel(orderType: UserDefaults.standard.integer(forKey: MEGASortingPreferenceType))
    }
    
    @objc func processViewModePreferenceNotification(_ notification:Notification) {
        let previousSelectedViewModePreferenceCell = tableView.cellForRow(at: IndexPath.init(row: viewModePreference, section: SortingAndViewSection.viewModePreference.rawValue)) as! SelectableTableViewCell
        previousSelectedViewModePreferenceCell.redCheckmarkImageView.isHidden = true
        
        viewModePreference = notification.userInfo?[MEGAViewModePreference] as! Int
        let selectedViewModePreferenceCell = tableView.cellForRow(at: IndexPath.init(row: viewModePreference, section: SortingAndViewSection.viewModePreference.rawValue)) as! SelectableTableViewCell
        selectedViewModePreferenceCell.redCheckmarkImageView.isHidden = false
    }
    
    private func setupSortingPreferenceSameForAllDetailLabel(orderType: Int) {
        var orderTypeIndex: Int
        switch (orderType) {
        case MEGASortOrderType.defaultAsc.rawValue:
            orderTypeIndex = 0
            
        case MEGASortOrderType.defaultDesc.rawValue:
            orderTypeIndex = 1
            
        case MEGASortOrderType.sizeDesc.rawValue:
            orderTypeIndex = 2
            
        case MEGASortOrderType.sizeAsc.rawValue:
            orderTypeIndex = 3
            
        case MEGASortOrderType.modificationDesc.rawValue:
            orderTypeIndex = 4
            
        case MEGASortOrderType.modificationAsc.rawValue:
            orderTypeIndex = 5
            
        default:
            orderTypeIndex = 0;
        }
        
        sortingPreferenceSameForAllDetailLabel.text = localizedSortByStringsArray[orderTypeIndex]
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor.mnz_secondaryBackgroundGrouped(traitCollection)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case SortingAndViewSection.sortingPreference.rawValue:
            return NSLocalizedString("Sorting preference", comment: "Section title of the 'Sorting And View Mode' view inside of Settings - Appearence - Sorting And View Mode.")
            
        case SortingAndViewSection.viewModePreference.rawValue:
            return NSLocalizedString("View mode preference", comment: "Section title of the 'Sorting And View Mode' view inside of Settings - Appearence - Sorting And View Mode.")
            
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case SortingAndViewSection.sortingPreference.rawValue:
            return NSLocalizedString("Configure column sorting order on a per-folder basis, or use the same order for all folders.", comment: "Footer text explaining what means choosing a sorting preference 'Per Folder' or 'Same for All' in Settings - Appearance - Sorting And View Mode.")
            
        case SortingAndViewSection.viewModePreference.rawValue:
            return NSLocalizedString("Select view mode (List or Thumbnail) on a per-folder basis, or use the same view mode for all folders.", comment: "Footer text explaining what means choosing a view mode preference 'Per Folder', 'List view' or 'Thumbnail view' in Settings - Appearance - Sorting And View Mode.")
            
        default:
            return nil
        }
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case SortingAndViewSection.sortingPreference.rawValue:
            if indexPath.row == SortingPreference.perFolder.rawValue {
                if sortingPreference == indexPath.row {
                    return
                }
                
                let selectedSortingPreferenceCell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row, section: SortingAndViewSection.sortingPreference.rawValue)) as! SelectableTableViewCell
                selectedSortingPreferenceCell.redCheckmarkImageView.isHidden = false
                
                sortingPreference = indexPath.row
                UserDefaults.standard.set(sortingPreference, forKey: MEGASortingPreference)
                
                sortingPreferenceSameForAllDetailLabel.text = NSLocalizedString("choosePhotoVideo", comment: "Menu option from the `Add` section that allows the user to choose a photo or video to upload it to MEGA.")
            } else {
                var actions = [ActionSheetAction]()
                let sortType = Helper.sortType(for: nil)
                let checkmarkImageView = UIImageView(image: UIImage(named: "turquoise_checkmark"))
    
                actions.append(ActionSheetAction(title: NSLocalizedString("nameAscending", comment: ""), detail:nil, accessoryView: sortType == .defaultAsc ? checkmarkImageView : nil, image: UIImage(named: "ascending"), style: .default) {
                    Helper.save(.defaultAsc, for: nil)
                })
                actions.append(ActionSheetAction(title: NSLocalizedString("nameDescending", comment: ""), detail:nil, accessoryView: sortType == .defaultDesc ? checkmarkImageView : nil, image: UIImage(named: "descending"), style: .default) {
                    Helper.save(.defaultDesc, for: nil)
                })
                actions.append(ActionSheetAction(title: NSLocalizedString("largest", comment: ""), detail:nil, accessoryView: sortType == .sizeDesc ? checkmarkImageView : nil, image: UIImage(named: "largest"), style: .default) {
                    Helper.save(.sizeDesc, for: nil)
                })
                actions.append(ActionSheetAction(title: NSLocalizedString("smallest", comment: ""), detail:nil, accessoryView: sortType == .sizeAsc ? checkmarkImageView : nil, image: UIImage(named: "smallest"), style: .default) {
                    Helper.save(.sizeAsc, for: nil)
                })
                actions.append(ActionSheetAction(title: NSLocalizedString("newest", comment: ""), detail:nil, accessoryView: sortType == .modificationDesc ? checkmarkImageView : nil, image: UIImage(named: "newest"), style: .default) {
                    Helper.save(.modificationDesc, for: nil)
                })
                actions.append(ActionSheetAction(title: NSLocalizedString("oldest", comment: ""), detail:nil, accessoryView: sortType == .modificationAsc ? checkmarkImageView : nil, image: UIImage(named: "oldest"), style: .default) {
                    Helper.save(.modificationAsc, for: nil)
                })
                
                let sortByActionSheet = ActionSheetViewController(actions: actions, headerTitle: nil, dismissCompletion: nil, sender: tableView.cellForRow(at: indexPath))
                present(sortByActionSheet, animated: true, completion: nil)
            }
            
        case SortingAndViewSection.viewModePreference.rawValue:
            if viewModePreference == indexPath.row {
                return
            }
            
            UserDefaults.standard.set(indexPath.row, forKey: MEGAViewModePreference)
            if #available(iOS 12, *) {} else {
                UserDefaults.standard.synchronize()
            }
            
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: MEGAViewModePreference), object: nil, userInfo: [MEGAViewModePreference : indexPath.row])
            
        default:
            return
        }
    }
}
