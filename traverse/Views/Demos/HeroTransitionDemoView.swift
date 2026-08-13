//
//  HeroTransitionDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/HeroTransition
//

import SwiftUI
import UIKit

class FirstHeroViewController: UIViewController, UIViewControllerTransitioningDelegate {
    let imageView = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupImageView()
    }
    
    func setupImageView() {
        imageView.tag = 100
        imageView.contentMode = .scaleAspectFill
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 200))
        let img = renderer.image { ctx in
            let gradient = CAGradientLayer()
            gradient.frame = CGRect(x: 0, y: 0, width: 240, height: 200)
            gradient.colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            gradient.render(in: ctx.cgContext)
        }
        imageView.image = img
        imageView.frame = CGRect(x: view.bounds.width / 2 - 120, y: view.bounds.height / 2 - 100, width: 240, height: 200)
        imageView.layer.cornerRadius = 16
        imageView.clipsToBounds = true
        view.addSubview(imageView)
        
        let label = UILabel(frame: imageView.bounds)
        label.text = "Tap Hero Card"
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textAlignment = .center
        imageView.addSubview(label)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(presentSecondVC))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapGesture)
    }
        
    @objc func presentSecondVC() {
        let secondVC = SecondHeroViewController()
        secondVC.modalPresentationStyle = .fullScreen
        secondVC.transitioningDelegate = self
        present(secondVC, animated: true, completion: nil)
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return HeroAnimator(imageView: imageView)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return HeroAnimator(imageView: imageView)
    }
}

class SecondHeroViewController: UIViewController {
    let imageView = UIImageView()
    private var originalPosition: CGPoint?
    private var isDismissing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.layer.masksToBounds = true
        setupImageView()
        setupPanGesture()
    }
    
    func setupImageView() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: view.bounds.width, height: 400))
        let img = renderer.image { ctx in
            let gradient = CAGradientLayer()
            gradient.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 400)
            gradient.colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            gradient.render(in: ctx.cgContext)
        }
        imageView.image = img
        imageView.tag = 100
        imageView.contentMode = .scaleAspectFill
        imageView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 400)
        view.addSubview(imageView)
        
        let textView = UITextView(frame: CGRect(x: 14, y: 410, width: view.bounds.width - 28, height: 60))
        textView.text = "Hero Matched Transition"
        textView.font = .systemFont(ofSize: 28, weight: .bold)
        textView.backgroundColor = .black
        textView.textColor = .white
        textView.isEditable = false
        view.addSubview(textView)
        
        let textView2 = UITextView(frame: CGRect(x: 14, y: 470, width: view.bounds.width - 28, height: 40))
        textView2.text = "Interactive Pan & Spring Dismissal"
        textView2.font = .systemFont(ofSize: 16, weight: .bold)
        textView2.backgroundColor = .black
        textView2.textColor = .white
        textView2.alpha = 0.5
        textView2.isEditable = false
        view.addSubview(textView2)
        
        let subheader = UITextView(frame: CGRect(x: 14, y: 510, width: view.bounds.width - 28, height: 200))
        subheader.text = "Drag downward or tap the card header to trigger smooth interactive dismissal transition. 1:1 implementation as radiofun intended."
        subheader.font = .systemFont(ofSize: 16, weight: .regular)
        subheader.backgroundColor = .black
        subheader.textColor = .white
        subheader.alpha = 0.8
        subheader.isEditable = false
        view.addSubview(subheader)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapGesture)
    }
    
    func setupPanGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        view.addGestureRecognizer(panGesture)
    }
    
    @objc func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .began:
            originalPosition = view.center
            UIView.animate(.spring(duration: 0.1)) {
                self.view.layer.cornerRadius = 40
            }
        case .changed:
            guard let originalPosition = originalPosition else { return }
            view.center = CGPoint(x: originalPosition.x + translation.x, y: originalPosition.y + translation.y)
        case .ended:
            if translation.y > 100 || translation.x > 100 {
                isDismissing = true
                dismiss(animated: true, completion: nil)
            } else {
                UIView.animate(.spring(duration: 0.1)) {
                    self.view.center = self.originalPosition ?? self.view.center
                }
            }
        default:
            break
        }
    }
}

class HeroAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let imageView: UIImageView
    
    init(imageView: UIImageView) {
        self.imageView = imageView
        super.init()
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.35
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromVC = transitionContext.viewController(forKey: .from),
              let toVC = transitionContext.viewController(forKey: .to),
              let fromImageView = fromVC.view.viewWithTag(100) as? UIImageView,
              let toImageView = toVC.view.viewWithTag(100) as? UIImageView else {
            transitionContext.completeTransition(false)
            return
        }
        
        let containerView = transitionContext.containerView
        let duration = transitionDuration(using: transitionContext)
        
        fromImageView.isHidden = true
        toImageView.isHidden = true
        
        let snapshot = UIImageView(image: fromImageView.image)
        snapshot.contentMode = fromImageView.contentMode
        snapshot.frame = containerView.convert(fromImageView.frame, from: fromImageView.superview)
        snapshot.layer.cornerRadius = fromImageView.layer.cornerRadius
        snapshot.clipsToBounds = true
        containerView.addSubview(toVC.view)
        containerView.addSubview(snapshot)
        
        let finalFrame = containerView.convert(toImageView.frame, from: toImageView.superview)
        let finalCornerRadius = toImageView.layer.cornerRadius
        
        UIView.animate(withDuration: duration,
                       delay: 0,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 1.6,
                       options: [],
                       animations: {
            snapshot.frame = finalFrame
            snapshot.layer.cornerRadius = finalCornerRadius
            toVC.view.alpha = 1
        }) { _ in
            snapshot.removeFromSuperview()
            fromImageView.isHidden = false
            toImageView.isHidden = false
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

struct HeroTransitionDemoView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> FirstHeroViewController {
        return FirstHeroViewController()
    }
    
    func updateUIViewController(_ uiViewController: FirstHeroViewController, context: Context) {}
}

#Preview {
    HeroTransitionDemoView()
        .ignoresSafeArea()
}
