//
//  BackgroundTask.swift
//  Etcetera
//
//  Created by Jared Sinclair on 8/15/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//

#if os(iOS)
private typealias Internals = iOSBackgroundTask
#else
private typealias Internals = UnsupportedBackgroundTask
#endif

/// A cross-platform wrapper for requesting background execution time.
public final class BackgroundTask: @unchecked Sendable {

    /// Convenience for initializing a task with a default expiration handler.
    ///
    /// - returns: Returns `nil` if background task time was denied.
    @MainActor public static func start() -> BackgroundTask? {
        let task = BackgroundTask()
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
    @MainActor public func start(withExpirationHandler handler: @escaping @Sendable () -> Void = {}) -> Bool {
        internals.start(withExpirationHandler: handler)
    }

    /// Ends the background task.
    public func end() {
        internals.end()
    }

    public init() {}

    private let internals = Internals()

}
