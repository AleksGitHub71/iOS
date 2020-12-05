
final class DocAndAudioListSource: NSObject, FilesExplorerListSourceProtocol {
    
    // MARK:- Private variables.

    var nodes: [MEGANode]?
    var selectedNodes: [MEGANode]?
    var tableView: UITableView
    weak var delegate: FilesExplorerListSourceDelegate?
    
    // MARK:- Initializers.

    init(tableView: UITableView,
         nodes: [MEGANode]?,
         selectedNodes: [MEGANode]?,
         delegate: FilesExplorerListSourceDelegate?) {
        self.tableView = tableView
        self.nodes = nodes
        self.selectedNodes = selectedNodes
        self.delegate = delegate
        super.init()
        configureTableView(tableView)
    }

    // MARK:- Actions
    
    @objc func moreButtonTapped(sender: UIButton) {
        guard let node = nodes?[sender.tag] else { return  }
        
        delegate?.showMoreOptions(forNode: node, sender: sender)
    }
    
    // MARK:- Interface methods.
    
    func onTransferStart(forNode node: MEGANode) {
        // Since we are using NodeTableViewCell and relying on Helper.downloadingNodes() which is updated in Appdelegate transfer delegates, we do need the delay or else we might see inconsitency in the cell update
        reloadCell(withNode: node, afterDelay: 1)
    }

    func updateProgress(_ progress: Float, forNode node: MEGANode, infoString: String) {
        if let nodeCell = cell(forNode: node) as? NodeTableViewCell,
           let infoLabel = nodeCell.infoLabel,
           let downloadProgressView = nodeCell.downloadProgressView {
            infoLabel.text = infoString
            downloadProgressView.progress = progress
        }
    }
    
    func onTransferCompleted(forNode node: MEGANode) {
        // Since we are using NodeTableViewCell and relying on Helper.downloadingNodes() which is updated in Appdelegate transfer delegates, we do need the delay or else we might see inconsitency in the cell update
        reloadCell(withNode: node, afterDelay: 1)
    }
    
    // MARK:- Private methods.
    
    private func configureTableView(_ tableView: UITableView) {        
        tableView.rowHeight = 60
        tableView.register(UINib(nibName: "NodeTableViewCell", bundle: nil),
                           forCellReuseIdentifier: "nodeCell")
        tableView.register(UINib(nibName: "DownloadingNodeCell", bundle: nil),
                           forCellReuseIdentifier: "downloadingNodeCell")
    }
    
    private func reloadCell(withNode node: MEGANode, afterDelay delay: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) { [weak self] in
            self?.reloadCell(withNode: node)
        }
    }

}

// MARK:- UITableViewDataSource

extension DocAndAudioListSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return nodes?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let node = nodes?[indexPath.row] else { return UITableViewCell() }
        
        var cell: NodeTableViewCell?
        if let handle = node.base64Handle, let _ = Helper.downloadingNodes()[handle] {
            cell = tableView.dequeueReusableCell(withIdentifier: "downloadingNodeCell", for: indexPath) as? NodeTableViewCell
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "nodeCell", for: indexPath) as? NodeTableViewCell
        }
        
        if let moreButton = cell?.moreButton {
            moreButton.removeTarget(nil, action: nil, for: .allEvents)
            moreButton.tag = indexPath.row
            moreButton.addTarget(self, action: #selector(moreButtonTapped(sender:)), for: .touchUpInside)
        }
                
        cell?.cellFlavor = .explorerView
        cell?.configureCell(for: node, delegate: nil, api: MEGASdkManager.sharedMEGASdk())
        cell?.setSelectedBackgroundView(withColor: .clear)
        
        if tableView.isEditing,
           let selectedNodes = selectedNodes,
           !selectedNodes.isEmpty,
           selectedNodes.contains(node) {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
        
        return cell ?? UITableViewCell()
    }
}

// MARK:- UITableViewDelegate

extension DocAndAudioListSource {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        toggleSelection(at: indexPath)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        toggleSelection(at: indexPath)
    }
}

// MARK:- Swipe gesture UITableViewDelegate

@available(iOS 11.0, *)
extension DocAndAudioListSource {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        guard let nodeCell = tableView.cellForRow(at: indexPath) as? NodeTableViewCell,
              let node = nodeCell.node else {
            return nil
        }

        if !isNodeInRubbishBin(node){
            let shareAction = contextualAction(
                withImageName: "share",
                backgroundColor: .systemOrange
            ) { [weak self] in
                self?.share(node: nodeCell.node)
            }
            let rubbishBinAction = contextualAction(
                withImageName: "rubbishBin",
                backgroundColor: .mnz_redError()
            ) { [weak self] in
                self?.moveToRubbishBin(node: nodeCell.node)
            }

            var actions = [rubbishBinAction, shareAction]
            
            if let base64Handle = node.base64Handle,
               Helper.downloadingNodes()[base64Handle] == nil {
                let downloadAction = contextualAction(withImageName: "infoDownload", backgroundColor: .mnz_turquoise(for: tableView.traitCollection)) { [weak self] in
                    self?.download(node: node)
                }
                actions += [downloadAction]
            }
            
            return UISwipeActionsConfiguration(actions: actions)
        }

        return nil
    }

    // MARK:- Private methods
    
    private func indexPath(forNode node: MEGANode) -> IndexPath? {
        guard let index = nodes?.firstIndex(of: node) else {
            MEGALogDebug("Could not find the node with name \(node.name ?? "no node name") as the index is nil")
            return nil
        }

        return IndexPath(row: index, section: 0)
    }

    private func share(node: MEGANode) {
        guard let indexPath = indexPath(forNode: node),
              let cell = tableView.cellForRow(at: indexPath) else {
            MEGALogDebug("Could not find the node with name \(node.name ?? "no node name") as cell or the indexPath is nil")
            return
        }

        let activityVC = UIActivityViewController(forNodes: [node], sender: cell)
        delegate?.present(activityVC, animated: true)
        tableView.setEditing(false, animated: true)
    }

    private func moveToRubbishBin(node: MEGANode) {
        node.mnz_moveToTheRubbishBin { [weak self] in
            self?.tableView.setEditing(false, animated: true)
        }
    }

    private func restore(node: MEGANode) {
        node.mnz_restore()
        tableView.setEditing(false, animated: true)
    }

    private func download(node: MEGANode) {
        if node.mnz_downloadNodeOverwriting(false),
           let indexPath = indexPath(forNode: node) {
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }

        tableView.setEditing(false, animated: true)
    }

    private func contextualAction(withImageName imageName: String, backgroundColor: UIColor, completion: @escaping () -> Void) -> UIContextualAction {
        let action = UIContextualAction(style: .normal,
                                        title: nil)
        { (action, sourceView, callback) in
            completion()
        }

        action.image = UIImage(named: imageName)
        if #available(iOS 13.0, *) {
            action.image = action.image?.withTintColor(.white)
        }

        action.backgroundColor = backgroundColor
        return action
    }
    
    private func isOwner(ofNode node: MEGANode) -> Bool {
        return MEGASdkManager.sharedMEGASdk().accessLevel(for: node) == .accessOwner
    }

    private func isNodeInRubbishBin(_ node: MEGANode) -> Bool {
        return MEGASdkManager.sharedMEGASdk().isNode(inRubbish: node)
    }

    private func restorationNode(forNode node: MEGANode) -> MEGANode? {
        return MEGASdkManager.sharedMEGASdk().node(forHandle: node.restoreHandle)
    }
}
