//
//  BackgroundTask.swift
//  Etcetera
//
//  Created by Jared Sinclair on 8/15/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//

import UIKit

/// A quality-of-life wrapper around requesting iOS background execution time.
public class BackgroundTask {

    /// Convenience for initializing a task with a default expiration handler.
    ///
    /// - returns: Returns `nil` if background task time was denied.
    public static func start() -> BackgroundTask? {
        let task = BackgroundTask()
        let successful = task.start(withExpirationHandler: nil)
        return (successful) ? task : nil
    }

    /// Begins a background task with the system.
    ///
    /// - parameter handler: A block to be invoked if the task expires. Any
    /// cleanup necessary to recover from expired background time should be
    /// performed inside this block — synchronously, since the app will be
    /// suspended when the block returns.
    ///
    /// - returns: Returns `true` if background execution time was allotted.
    public func start(withExpirationHandler handler: (() -> Void)?) -> Bool {
        self.taskId = UIApplication.shared.beginBackgroundTask {
            handler?()
            self.end()
        }
        return (self.taskId != .invalid)
    }

    /// Ends the background task.
    public func end() {
        guard self.taskId != .invalid else { return }
        let taskId = self.taskId
        self.taskId = .invalid
        UIApplication.shared.endBackgroundTask(taskId)
    }

    public init() {}

    private var taskId: UIBackgroundTaskIdentifier = .invalid

}
