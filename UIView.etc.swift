//
//  Reachability.swift
//  Etcetera
//
//  Copyright © 2018 Nice Boy LLC. All rights reserved.
//
// swiftlint:disable force_cast

import UIKit

extension UIView {

    static func newFromNib<T: UIView>() -> T {
        let name = String(describing: T.self)
        let nib = UINib(nibName: name, bundle: nil)
        let array = nib.instantiate(withOwner: nil)
        return array[0] as! T
    }

    func constrainToFill() {
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        translatesAutoresizingMaskIntoConstraints = true
    }

    func constrain(to view: UIView, insetBy insets: UIEdgeInsets = .zero) {
        leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.left).isActive = true
        topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top).isActive = true
        trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.right).isActive = true
        bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -insets.bottom).isActive = true
    }

    func addConstrainedSubview(_ subview: UIView, insetBy insets: UIEdgeInsets = .zero) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
        subview.frame = {
            var frame = self.bounds
            frame.origin.y += insets.top
            frame.origin.x += insets.left
            frame.size.width -= (insets.left + insets.right)
            frame.size.height -= (insets.top + insets.bottom)
            return frame
        }()
        subview.constrain(to: self, insetBy: insets)
    }

    func addCenteredSubview(_ subview: UIView, size: CGSize) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
        subview.widthAnchor.constraint(equalToConstant: size.width).isActive = true
        subview.heightAnchor.constraint(equalToConstant: size.height).isActive = true
        center(subview)
    }

    func center(_ subview: UIView) {
        centerXAnchor.constraint(equalTo: subview.centerXAnchor).isActive = true
        centerYAnchor.constraint(equalTo: subview.centerYAnchor).isActive = true
    }

    func roundCornersToMatchSuperllipticalDisplayCorners() {
        var key = NSString(format: "%@%@%@", "display", "Corner", "Radius")
        guard let value = UIScreen.main.traitCollection.value(forKey: key as String) else {
            roundCorners(toRadius: 39)
            return
        }
        guard let radius = value as? CGFloat else {
            roundCorners(toRadius: 39)
            return
        }
        layer.cornerRadius = radius
        key = NSString(format: "%@%@", "continuous", "Corners")
        layer.setValue(true, forKey: key as String)
        clipsToBounds = true
    }

    func roundCorners(toRadius radius: CGFloat) {
        layer.cornerRadius = radius
        clipsToBounds = true
    }

}

extension CGRect {
    func outset(by offset: CGFloat) -> CGRect {
        return insetBy(dx: -offset, dy: -offset)
    }
}

extension UIView {

    var transformSafeFrame: CGRect {
        let left = self.left
        let top = self.top
        let width = self.width
        let height = self.height
        return CGRect(x: left, y: top, width: width, height: height)
    }

    var top: CGFloat {
        get {
            return self.center.y - self.halfHeight
        }
        set {
            var center = self.center
            center.y = newValue + self.halfHeight
            self.center = center
        }
    }

    var left: CGFloat {
        get {
            return self.center.x - self.halfWidth
        }
        set {
            var center = self.center
            center.x = newValue + self.halfWidth
            self.center = center
        }
    }

    var bottom: CGFloat {
        get {
            return self.center.y + self.halfHeight
        }
        set {
            var center = self.center
            center.y = newValue - self.halfHeight
            self.center = center
        }
    }

    var right: CGFloat {
        get {
            return self.center.x + self.halfWidth
        }
        set {
            var center = self.center
            center.x = newValue - self.halfWidth
            self.center = center
        }
    }

    var height: CGFloat {
        get {
            return self.bounds.height
        }
        set {
            var bounds = self.bounds
            let previousHeight = bounds.height
            bounds.size.height = newValue
            self.bounds = bounds

            let delta = previousHeight - newValue
            var center = self.center
            center.y += delta / 2.0
            self.center = center
        }
    }

    var width: CGFloat {
        get {
            return self.bounds.width
        }
        set {
            var bounds = self.bounds
            let previousWidth = bounds.width
            bounds.size.width = newValue
            self.bounds = bounds

            let delta = previousWidth - newValue
            var center = self.center
            center.x += delta / 2.0
            self.center = center
        }
    }

    var internalCenter: CGPoint {
        return CGPoint(x: self.halfWidth, y: self.halfHeight)
    }

    // MARK: Private

    private var halfHeight: CGFloat {
        return self.bounds.height / 2.0
    }

    private var halfWidth: CGFloat {
        return self.bounds.width / 2.0
    }

}
