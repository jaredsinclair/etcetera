//
//  Locking.swift
//  Etcetera
//
//  Created by Jared Sinclair on 8/15/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//

import os.lock

/// A high-performance lock supported by all Apple platforms.
///
/// This lock is **not** recursive.
public final class Lock: @unchecked Sendable {

    /// See WWDC 2016 Session 720. Using C struct locks like `pthread_mutex_t`
    /// or `os_unfair_lock` directly from Swift code is discouraged because of
    /// Swift's assumption that value types can be moved around freely in
    /// memory. Instead we have to manually manage memory here to ensure that
    /// the lock struct has a fixed address during its lifetime.
    private let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)

    public init() {
        lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    /// Performs `block` inside a balanced lock/unlock pair.
    public func locked<T>(_ block: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return try block()
    }
}

/// A generic wrapper around a given value, which is protected by a `Lock`.
public final class Protected<T>: @unchecked Sendable {

    /// Read/write access to the value as if you had used `access(_:)`.
    public var current: T {
        get { return access { $0 } }
        set { access { $0 = newValue } }
    }

    private let lock = Lock()
    private var value: T

    public init(_ value: T) {
        self.value = value
    }

    /// Accesses the protected value inside a balanced lock/unlock pair.
    ///
    /// - parameter block: Can either mutate the passed-in value or not, and can
    /// also return a value (or an implied Void).
    public func access<Return>(_ block: (inout T) throws -> Return) rethrows -> Return {
        return try lock.locked {
            try block(&value)
        }
    }
}

extension Protected {

    /// Convenience initializer that defaults to `nil`.
    public convenience init<O>() where T == Optional<O> {
        self.init(nil)
    }

}

/// A dictionary-like object that provides synchronized read/writes via an
/// underlying `Protected` value.
public final class ProtectedDictionary<Key: Hashable, Value>: Sendable {

    private let protected: Protected<[Key: Value]>

    public init(_ contents: [Key: Value] = [:]) {
        self.protected = Protected(contents)
    }

    /// Read/write access to the underlying dictionary storage as if you had
    /// used the `access(_:)` method to subscript the dictionary directly.
    public subscript(key: Key) -> Value? {
        get { return protected.access { $0[key] } }
        set { protected.access { $0[key] = newValue } }
    }

    /// Accesses the protected value inside a balanced lock/unlock pair.
    ///
    /// - parameter block: Can either mutate the passed-in value or not, and can
    /// also return a value (or an implied Void).
    public func access<Return>(_ block: (inout [Key: Value]) throws -> Return) rethrows -> Return {
        return try protected.access(block)
    }

    public func removeAll() {
        protected.access { $0.removeAll() }
    }

}
