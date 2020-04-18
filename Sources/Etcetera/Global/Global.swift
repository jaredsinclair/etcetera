//
//  Global.swift
//  Etcetera
//
//  Created by Jared Sinclair on 01/24/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

/// Property wrapper that transparently resolves global dependencies via a
/// shared dependency container.
///
/// Please consult the README in this repository for usage and cautions.
@propertyWrapper public struct Global<Wrapped> {

    /// The wrapped value (required by `@propertyWrapper`).
    public let wrappedValue: Wrapped

    /// Initializes a Global using a closure that returns a wrapped value. The
    /// closure is only evaluated if an existing cached value cannot be found
    /// in the shared container. If that happens, the value returned from the
    /// closure is cached in the shared container for future re-use.
    ///
    /// It is very, very unlikely that you would ever use this initializer
    /// directly when declaring an `@Global`-wrapped property. Instead, Global
    /// wrappers are regularly initialized via init methods declared in
    /// extensions (see the README for details).
    public init(initializer: (Container) -> Wrapped) {
        self.wrappedValue = Container.shared.resolveInstance(via: initializer)
    }

    /// Initializes a Global using a closure that returns a wrapped value. The
    /// closure is only evaluated if an existing cached value cannot be found
    /// in the shared container. If that happens, the value returned from the
    /// closure is cached in the shared container for future re-use.
    ///
    /// Unlike `init(initializer:)`, this method augments the caching strategy
    /// with an identifier (`instanceIdentifier`) that identifies a particular
    /// instance of `Wrapped` in the cache. The `initializer` closure is
    /// evaluated whenever a cached value for `instanceIdentifier` cannot be
    /// found in the cache.
    ///
    /// It is very, very unlikely that you would ever use this initializer
    /// directly when declaring an `@Global`-wrapped property. Instead, Global
    /// wrappers are regularly initialized via init methods declared in
    /// extensions (see the README for details).
    public init<InstanceIdentifier: Hashable>(instanceIdentifier: InstanceIdentifier, initializer: (Container) -> Wrapped) {
        let someKey = AnyInstanceIdentifier<Wrapped, InstanceIdentifier>(instanceIdentifier)
        self.wrappedValue = Container.shared.resolveInstance(for: someKey, via: initializer)
    }

}
