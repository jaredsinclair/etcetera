//
//  OperationQueue.swift
//  Etcetera
//
//  Copyright © 2018 Nice Boy LLC. All rights reserved.
//

import Foundation

/// Quality-of-life extension of OperationQueue.
extension OperationQueue {

    /// Is `true` if called from the main queue.
    public static var isMain: Bool {
        return OperationQueue.isCurrent(main)
    }

    /// - parameter queue: The queue in question.
    ///
    /// - returns: Returns `true` if called from `queue`.
    public static func isCurrent(_ queue: OperationQueue) -> Bool {
        return current === queue
    }

    /// Performs a block on the main queue as soon as possible without blocking
    /// execution on the current queue, if it isn't the main queue itself.
    ///
    /// - parameter block: The block to be performed.
    public static func onMain(_ block: @escaping () -> Void) {
        OperationQueue.main.asap(block)
    }

    /// Initializes and returns a new queue with a max concurrent operation
    /// count of 1.
    public static func serialQueue() -> OperationQueue {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }

    /// Performs a block on the receiver as soon as possible without blocking
    /// execution on the current queue, if it isn't the receiver itself.
    ///
    /// - parameter block: The block to be performed.
    public func asap(_ block: @escaping () -> Void) {
        if OperationQueue.current === self {
            block()
        } else {
            addOperation(block)
        }
    }

    /// Adds an array of operations to the receiver.
    ///
    /// The operations added will be executed asynchronously, according to the
    /// standard
    ///
    /// - parameter operations: An array of operations to be added, in order.
    public func add(_ operations: [Operation]) {
        addOperations(operations, waitUntilFinished: false)
    }

    public func sync(_ block: @escaping () -> Void) {
        let operation = BlockOperation(block: block)
        addOperations([operation], waitUntilFinished: true)
    }

}
