
// This class is responsible for animating the "AddToChatViewController" when presented.
class AddToChatViewAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    enum TransitionType {
        case present
        case dismiss
    }

    let duration = 0.4
    let type: TransitionType

    init(type: TransitionType) {
        self.type = type
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        guard let addToChatViewController = transitionContext
            .viewController(forKey: (type == .present) ? .to : .from) as? AddToChatViewController else {
            return
        }

        addToChatViewController.backgroundView.alpha = (type == .present) ? 0.0 : 1.0

        if let toView = transitionContext.view(forKey: .to) {
            containerView.addSubview(toView)
        }
        containerView.bringSubviewToFront(addToChatViewController.view)
        addToChatViewController.view.layoutIfNeeded()

        guard let contentView = addToChatViewController.contentView,
            let contentSnapShot = contentView.snapshotView(afterScreenUpdates: (type == .present)) else {
            fatalError("something wrong with the animation")
        }

        contentSnapShot.frame = containerView.convert(contentView.frame, from: contentView.superview)

        if type == .present {
            contentSnapShot.transform = .init(translationX: 0,
                                              y: contentView.bounds.height)
        }

        containerView.addSubview(contentSnapShot)
        addToChatViewController.contentView.isHidden = true

        UIView.animate(withDuration: duration,
                       animations: {
                        contentSnapShot.transform = (self.type == .present)
                            ? .identity
                            : .init(translationX: 0, y: contentSnapShot.bounds.height)
                        addToChatViewController.backgroundView.alpha = (self.type == .present) ? 1.0 : 0.0
        }) { _ in
            addToChatViewController.backgroundView.alpha = 1.0
            addToChatViewController.contentView.isHidden = false
            contentSnapShot.removeFromSuperview()
            transitionContext.completeTransition(true)
        }
    }
}
