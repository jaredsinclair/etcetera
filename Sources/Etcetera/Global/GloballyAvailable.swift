//
//  GloballyAvailable.swift
//  Etcetera
//
//  Created by Jared Sinclair on 01/24/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

/// A protocol to which most concrete types used with `@Global` must conform.
///
/// Only concrete types can be used with `GloballyAvailable`. Protocol types
/// can participate in `@Global` only by extensions of the `Global` struct that
/// provide `init()` methods for each protocol type.
///
/// - Note: If you have a type that needs to have multiple instances available
/// to `@Global`, use the `GloballyIdentifiable` protocol instead.
public protocol GloballyAvailable {

    /// Produces an instance of `Self` on demand. This method is called from the
    /// shared dependency container when a cached instance of `Self` cannot be
    /// found in the cache.
    static func make(container: Container) -> Self

}

extension Global where Wrapped: GloballyAvailable {

    /// Initializes a Global, wrapping any type that conforms to GloballyAvailable.
    ///
    /// Here is some example usage:
    ///
    ///     class MyClass: GloballyAvailable { ... }
    ///
    ///     @Global() var myClass: MyClass
    ///
    /// Don't forget the trailing parentheses!
    public init() {
        wrappedValue = Container.shared.resolveInstance()
    }

}
