//
//  Locking.swift
//  Etcetera
//
//  Created by Jared Sinclair on 7/21/18.
//

import Darwin

/// A high-performance lock supported by all Apple platforms.
public final class Lock {
    private var lock = os_unfair_lock()

    public init() {}

    /// Performs `block` inside a balanced lock/unlock pair.
    public func locked<T>(_ block: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return try block()
    }
}

/// A generic wrapper around a given value, which is protected by a `Lock`.
public final class Protected<T> {

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

/// A dictionary-like object that provides synchronized read/writes via an
/// underlying `Protected` value.
public final class ProtectedDictionary<Key: Hashable, Value> {
    private let protected: Protected<[Key: Value]>

    public init(_ contents: [Key: Value] = [:]) {
        self.protected = Protected(contents)
    }

    /// Read/write access to the underlying dictionary storage as if you had
    /// used the `access(_:)` method to subscript the dictionary directly.
    public subscript(key: Key) -> Value? {
        get { return protected.access{ $0[key] } }
        set { protected.access{ $0[key] = newValue } }
    }

    /// Accesses the protected value inside a balanced lock/unlock pair.
    ///
    /// - parameter block: Can either mutate the passed-in value or not, and can
    /// also return a value (or an implied Void).
    public func access<Return>(_ block: (inout [Key: Value]) throws -> Return) rethrows -> Return {
        return try protected.access(block)
    }
}
