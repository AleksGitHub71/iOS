import MEGADomain
import MEGASDKRepo
import SwiftUI
import UIKit

public struct AdsSlotRouter<T: View> {
    private weak var presenter: UIViewController?
    private let adsSlotViewController: any AdsSlotViewControllerProtocol
    private let contentView: T
    private let presentationStyle: UIModalPresentationStyle
    
    private class HostingController<S: View>: UIHostingController<AdsSlotView<S>> {
        
        private var onViewFirstAppeared: (() -> Void)?
        
        init(rootView: AdsSlotView<S>, onViewFirstAppeared: (() -> Void)? = nil) {
            self.onViewFirstAppeared = onViewFirstAppeared
            super.init(rootView: rootView)
        }
        
        required dynamic init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onViewFirstAppeared?()
            onViewFirstAppeared = nil
        }
    }
    
    public init(
        adsSlotViewController: some AdsSlotViewControllerProtocol,
        contentView: T,
        presenter: UIViewController? = nil,
        presentationStyle: UIModalPresentationStyle = .automatic
    ) {
        self.adsSlotViewController = adsSlotViewController
        self.contentView = contentView
        self.presenter = presenter
        self.presentationStyle = presentationStyle
    }
    
    public func build(onViewFirstAppeared: (() -> Void)? = nil) -> UIViewController {
        let viewModel = AdsSlotViewModel(adsSlotChangeStream: AdsSlotChangeStream(adsSlotViewController: adsSlotViewController))
        let adsSlotView = AdsSlotView(viewModel: viewModel, contentView: contentView)
        let adsViewController = HostingController(
            rootView: adsSlotView,
            onViewFirstAppeared: onViewFirstAppeared
        )
        adsViewController.modalPresentationStyle = presentationStyle
        return adsViewController
    }
    
    public func start() {
        presenter?.present(build(), animated: true)
    }
}
