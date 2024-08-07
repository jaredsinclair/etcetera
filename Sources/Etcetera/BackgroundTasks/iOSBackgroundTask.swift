//
//  iOSBackgroundTask.swift
//  Etcetera
//
//  Created by Jared Sinclair on 8/15/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//

#if os(iOS)

import UIKit

/// A quality-of-life wrapper around requesting iOS background execution time.
final class iOSBackgroundTask: Sendable {

    /// Convenience for initializing a task with a default expiration handler.
    ///
    /// - returns: Returns `nil` if background task time was denied.
    @MainActor static func start() -> iOSBackgroundTask? {
        let task = iOSBackgroundTask()
        let successful = task.start()
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
    @MainActor func start(withExpirationHandler handler: @escaping @Sendable () -> Void = {}) -> Bool {
        self.taskId = UIApplication.shared.beginBackgroundTask {
            handler()
            self.end()
        }
        return (self.taskId != .invalid)
    }

    /// Ends the background task.
    func end() {
        guard self.taskId != .invalid else { return }
        let taskId = self.taskId
        self.taskId = .invalid
        DispatchQueue.main.async {
            UIApplication.shared.endBackgroundTask(taskId)
        }
    }

    init() {}

    private var taskId: UIBackgroundTaskIdentifier {
        get { _taskId.current }
        set { _taskId.current = newValue }
    }

    private let _taskId = Protected(UIBackgroundTaskIdentifier.invalid)

}

#endif
