import UIKit

class MeetingCreatingViewController: UIViewController {
    
    // MARK: - Internal properties
    let viewModel: MeetingCreatingViewModel

     init(viewModel: MeetingCreatingViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var hidesBottomBarWhenPushed: Bool {
        get {
            return true
        }
        set {
            super.hidesBottomBarWhenPushed = newValue
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("close", comment: ""),
            style: .plain,
            target: self,
            action: #selector(dissmissVC(_:))
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func loadView() {
        view = MeetingCreatingView(viewModel: viewModel, vc: self)
    }
    
    // MARK: - Private methods.
    
    @objc private func dissmissVC(_ barButtonItem: UIBarButtonItem) {
        viewModel.dispatch(.didTapCloseButton)
    }
    
    private func forceDarkNavigationUI() {
        if #available(iOS 13.0, *) {
            guard let navigationBar = navigationController?.navigationBar else  { return }
            AppearanceManager.forceNavigationBarUpdate(navigationBar, traitCollection: traitCollection)
        }
    }
}

extension MeetingCreatingViewController: TraitEnviromentAware {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        forceDarkNavigationUI()
    }
    
    func colorAppearanceDidChange(to currentTrait: UITraitCollection, from previousTrait: UITraitCollection?) {
        if #available(iOS 13.0, *) {
            guard let navigationBar = navigationController?.navigationBar else  { return }
            AppearanceManager.forceNavigationBarUpdate(navigationBar, traitCollection: traitCollection)
        }
    }
}
