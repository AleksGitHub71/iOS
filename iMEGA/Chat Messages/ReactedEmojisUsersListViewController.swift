
import PanModal

protocol ReactedEmojisUsersListViewControllerDelegate: class {
    func didSelectUserhandle(_ userhandle: UInt64)
}

class ReactedEmojisUsersListViewController: UIViewController  {
    
    var selectedEmoji: String {
        didSet {
            guard isViewLoaded else {
                return
            }
            
            headerView.selectEmojiAtIndex(emojiList.firstIndex(of: selectedEmoji) ?? 0)
            updateEmojiHeaderViewDescription()
        }
    }
    
    private let chatRoom: MEGAChatRoom
    private let messageId: UInt64
    private let emojiList: [String]
    private let localSavedEmojis = EmojiListReader.readFromFile()
    private weak var delegate: ReactedEmojisUsersListViewControllerDelegate?
    private var isShortFormEnabled = true

    init(delegate: ReactedEmojisUsersListViewControllerDelegate,
         emojiList: [String],
         selectedEmoji: String,
         chatRoom: MEGAChatRoom,
         messageId: UInt64) {
        self.delegate = delegate
        self.emojiList = emojiList
        self.selectedEmoji = selectedEmoji
        self.chatRoom = chatRoom
        self.messageId = messageId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let headerView = EmojiCarousalView.instanceFromNib
    lazy var reactedUsersListPageViewController: ReactedUsersListPageViewController = {
        let viewController = ReactedUsersListPageViewController(transitionStyle: .scroll,
                                                                navigationOrientation: .horizontal,
                                                                options: nil)
        viewController.usersListDelegate = self
        return viewController
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        preferredContentSize = CGSize(width: 400, height: 600)

        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        
        addHeaderView(emojiList: emojiList)
        let userHandleList = userhandleList(forEmoji: selectedEmoji, chatId: chatRoom.chatId, messageId: messageId)
        updateEmojiHeaderViewDescription()
        let foundIndex = emojiList.firstIndex(of: selectedEmoji) ?? 0
        reactedUsersListPageViewController.set(numberOfPages: emojiList.count,
                                               selectedPage: foundIndex,
                                               initialUserHandleList: userHandleList)
        add(viewController: reactedUsersListPageViewController)
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        headerView.selectEmojiAtIndex(emojiList.firstIndex(of: selectedEmoji) ?? 0, animated: false)
    }
    
    private func updateEmojiHeaderViewDescription() {
        headerView.updateDescription(text: localSavedEmojis?.filter({ $0.representation == selectedEmoji }).first?.displayString)
    }
    
    private func addHeaderView(emojiList: [String]) {
        headerView.delegate = self
        headerView.selectEmojiAtIndex(emojiList.firstIndex(of: selectedEmoji) ?? 0)
        view.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: headerView.bounds.height)
        ])
    }
    
    private func add(viewController: UIViewController) {
        addChild(viewController)
        view.addSubview(viewController.view)
        
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            viewController.view.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        viewController.didMove(toParent: self)
    }
    
    private func userhandleList(forEmoji emoji: String, chatId: UInt64, messageId: UInt64) -> [UInt64] {
        guard let userHandleList =  MEGASdkManager
            .sharedMEGAChatSdk()?
            .reactionUsers(forChat: chatId, messageId: messageId, reaction: emoji) else {
                MEGALogDebug("user handle list for emoji \(emoji) is empty")
            return []
        }
        
        return (0..<userHandleList.size).compactMap { userHandleList.megaHandle(at: $0) }
    }
}

extension ReactedEmojisUsersListViewController: EmojiCarousalViewDelegate {
    func numberOfEmojis() -> Int {
        return emojiList.count
    }
    
    func emojiAtIndex(_ index: Int) -> String {
        return emojiList[index]
    }
    
    func numberOfUsersReacted(toEmoji emoji: String) -> Int {
        let handleList = userhandleList(forEmoji: emoji, chatId: chatRoom.chatId, messageId: messageId)
        return handleList.count
    }
        
    func didSelect(emoji: String, atIndex index: Int) {
        let userHandleList = userhandleList(forEmoji: emoji, chatId: chatRoom.chatId, messageId: messageId)
        reactedUsersListPageViewController.didSelectPage(withIndex: index, userHandleList: userHandleList)
        selectedEmoji = emoji
    }
}

extension ReactedEmojisUsersListViewController: ReactedUsersListPageViewControllerDelegate {
    func userHandleList(atIndex index: Int) -> [UInt64] {
        return userhandleList(forEmoji: emojiList[index], chatId: chatRoom.chatId, messageId: messageId)
    }
    
    func pageChanged(toIndex index: Int) {
        selectedEmoji = emojiList[index]
    }
    
    func didSelectUserhandle(_ userhandle: UInt64) {
        guard let myHandle = MEGASdkManager.sharedMEGASdk().myUser?.handle,
            myHandle != userhandle else {
                MEGALogDebug("My user handle tapped on chat reactions screen")
                return
        }
        
        dismiss(animated: true, completion: nil)
        delegate?.didSelectUserhandle(userhandle)
    }
    
    func userName(forHandle handle: UInt64) -> String? {
        guard let myHandle = MEGASdkManager.sharedMEGASdk().myUser?.handle, myHandle != handle else {
            if let myFullName = MEGASdkManager.sharedMEGAChatSdk()?.myFullname {
                return String(format: "%@ (%@)", myFullName, AMLocalizedString("me", "The title for my message in a chat. The message was sent from yourself."))
            }

            return nil
        }
        return chatRoom.participantName(forUserHandle: handle)
    }
}

// MARK: - Pan Modal Presentable

extension ReactedEmojisUsersListViewController: PanModalPresentable {

    var panScrollable: UIScrollView? {
        return reactedUsersListPageViewController.tableViewController?.tableView
    }
    
    var showDragIndicator: Bool {
        return false
    }

    var shortFormHeight: PanModalHeight {
        return isShortFormEnabled ? .contentHeight(300) : longFormHeight
    }
    
    
    var longFormHeight: PanModalHeight {
        return .contentHeight(view.bounds.height)
    }
    
    var anchorModalToLongForm: Bool {
        return false
    }

    func willTransition(to state: PanModalPresentationController.PresentationState) {
        guard isShortFormEnabled, case .longForm = state
            else { return }

        isShortFormEnabled = false
        panModalSetNeedsLayoutUpdate()
    }
}
