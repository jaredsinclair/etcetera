//
//  NotificationCenter.swift
//  Etcetera
//
//  Copyright © 2018 Nice Boy LLC. All rights reserved.
//

import Foundation

/// Quality-of-life extension of NotificationCenter.
extension NotificationCenter {

    /// Posts a notification using the default center.
    ///
    /// - parameter name: The name of the notification to post.
    public static func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }

}
