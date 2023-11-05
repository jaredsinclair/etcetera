//
//  UIViewController.swift
//  Etcetera
//
//  Created by Jared Sinclair on 8/15/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//
// swiftlint:disable force_cast

import UIKit
import SwiftUI

extension UIViewController {

    public func addHostedChild<Root: View>(for root: Root) {
        let host = UIHostingController(rootView: root)
        addConstrainedChild(host)
    }

    public func addConstrainedChild(_ child: UIViewController) {
        addChild(child)
        view.addConstrainedSubview(child.view)
        child.didMove(toParent: self)
    }

    public static func instantiateFromStoryboard<T: UIViewController>(of type: T.Type = T.self) -> T {
        let identifier = String(describing: type)
        let storyboard = UIStoryboard(name: identifier, bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: identifier)
        return viewController as! T
    }

}
