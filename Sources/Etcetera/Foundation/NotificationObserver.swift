//
//  NotificationObserver.swift
//  Etcetera
//
//  Created by Jared Sinclair on 8/15/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//

import Foundation

/// Convenience for observing NSNotifications.
///
/// NotificationObserver removes all observers upon deinit, which means that the
/// developer using a NotificationObserver can simply declare a property like:
///
///     private var observer = NotificationObserver()
///
/// and trust ARC to release the observer at the appropriate time, which will
/// remove all observations. This assumes, of course, that all blocks passed to
/// `when(_:perform:)` do not strongly capture `self`.
public final class NotificationObserver: NSObject, Sendable {

    // MARK: - Typealiases

    /// Signature for the block which callers can use to remove an existing
    /// observer during the NotificationObserver's lifetime.
    public typealias Unobserver = @Sendable () -> Void

    // MARK: - Private Properties

    /// If `true`, and if `object` is `nil`, then the target object passed into
    /// the initializer is presumed to have been released (it is a weak ref).
    private let wasInitializedWithTargetObject: Bool

    /// The target queue for all observation callbacks.
    private let queue: OperationQueue

    /// The target object to be used when observing notifications.
    private var object: AnyObject? {
        get { _object.access {
            $0.object
        }}
        set { _object.access {
            $0.object = newValue
        }}
    }

    /// The backing storage for `object`.
    private let _object: Protected<WeakReferencingBox>

    /// A tote bag of observation tokens.
    private let tokens = Protected<[Token]>([])

    // MARK: - Sigh, Concurrency

    private struct Token: @unchecked Sendable {
        let wrapped: NSObjectProtocol
    }

    // MARK: - Init/Deinit

    /// Designated initializer.
    ///
    /// - parameter object: Optional. A target object to use with observations.
    ///
    /// - parameter queue: The target queue for all observation callbacks.
    public init(object: AnyObject? = nil, queue: OperationQueue = .main) {
        self._object = Protected(WeakReferencingBox(object: object))
        self.wasInitializedWithTargetObject = (object != nil)
        self.queue = queue
    }

    deinit {
        tokens.current.forEach {
            NotificationCenter.default.removeObserver($0)
        }
    }

    // MARK: - Public Methods

    /// Adds an observation for a given notification.
    ///
    /// This method's signature is designed for succinct clarity at the call
    /// site compared with the usual boilerplate, to wit:
    ///
    ///     observer.when(UIApplication.DidBecomeActive) { note in
    ///         // do something with `note`
    ///     }
    ///
    /// Which is especially useful in classes that require observing more than
    /// one notification name.
    ///
    /// - parameter name: The notification name to observe.
    ///
    /// - parameter block: The block to be performed upon each notification.
    /// This block will always be called on `queue`.
    ///
    /// - returns: Returns a block which can be used to remove the observation
    /// later on, if desired. This is not necessary for general use, however.
    @discardableResult
    public func when(_ name: Notification.Name, perform block: @escaping @Sendable (Notification) -> Void) -> Unobserver {
        guard wasInitializedWithTargetObject == false || object != nil else { return {} }
        let token = Token(wrapped: NotificationCenter.default.addObserver(
            forName: name,
            object: object,
            queue: queue,
            using: block
        ))
        let unobserve: Unobserver = {
            NotificationCenter.default.removeObserver(token)
        }
        queue.asap { [weak self] in
            if let this = self {
                this.tokens.access {
                    $0.append(token)
                }
            } else {
                unobserve()
            }
        }
        return unobserve
    }

    /// An alternative to the above method which does not pass a reference to
    /// the notification in the block argument, which can spare you a `_ in`.
    @discardableResult
    public func when(_ name: Notification.Name, perform block: @escaping @Sendable () -> Void) -> Unobserver {
        return when(name, perform: { _ in block() })
    }

    // MARK: - Nested Types

    private final class WeakReferencingBox {
        weak var object: AnyObject?

        init(object: AnyObject? = nil) {
            self.object = object
        }
    }

}
