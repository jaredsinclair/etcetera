//
//  GloballyIdentifiable.swift
//  Etcetera
//
//  Created by Jared Sinclair on 01/24/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

/// A protocol to which concrete types used with `@Global` must conform, if your
/// application requires multiple concurrent instances of the type to be made
/// available to `@Global` property wrappers, keyed by per-instance identifiers.
///
/// Only concrete types can be used with `GloballyAvailable`. Protocol types
/// can participate in `@Global` only by extensions of the `Global` struct that
/// provide `init()` methods for each protocol type.
///
/// See the README for more information on when and how to use this protocol.
public protocol GloballyIdentifiable {

    /// The type to be used for per-instance identifiers.
    associatedtype InstanceIdentifier: Hashable

    /// Produces an instance of `Self` on demand. This method is called from the
    /// shared dependency container when a cached instance of `Self` cannot be
    /// found in the cache for the given `identifier`.
    ///
    /// Since the `InstanceIdentifier` associated type can be anything that
    /// conforms to `Hashable`, you can use a type that contains any information
    /// necessary to initialize a `Self` for that identifier.
    static func make(container: Container, identifier: InstanceIdentifier) -> Self

}

extension Global where Wrapped: GloballyIdentifiable {

    /// Initializes a Global property wrapper, wrapping any type that conforms
    /// to `GloballyIdentifiable`.
    ///
    /// See the documentation in the README for example usage.
    public init(_ identifier: Wrapped.InstanceIdentifier) {
        wrappedValue = Container.shared.resolveInstance(for: identifier)
    }

}
