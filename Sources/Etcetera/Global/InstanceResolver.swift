//
//  InstanceResolver.swift
//  Etcetera
//
//  Created by Jared Sinclair on 01/24/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

/// Stores a resolver block and one or more resolved instances of a given type.
@MainActor @usableFromInline final class InstanceResolver {

    /// A single resolved instance, not keyed by any instance identifier.
    private var resolvedInstance: Any?

    /// Instances keyed by instance identifiers.
    private var resolvedInstances: [AnyHashable: Any] = [:]

    /// Initializes a resolver with an initial value.
    @usableFromInline init<T: GloballyAvailable>(resolvedValue: T) {
        resolvedInstance = resolvedValue
    }

    /// Initializes a resolver with an initial value for `identifier`.
    @usableFromInline init<T: GloballyIdentifiable>(resolvedValues: [T.InstanceIdentifier: T]) {
        resolvedInstances = resolvedValues
    }

    /// Initializes an empty resolver.
    @usableFromInline init() {}

    /// Resolves an instance of `T` using `GlobalContainer`.
    @usableFromInline func resolved<T: GloballyAvailable>(container: Container) -> T {
        if let existing = resolvedInstance as? T {
            return existing
        } else {
            let new = T.make(container: container)
            resolvedInstance = new
            return new
        }
    }

    /// Resolves a specific instance of `T` for a given identifier.
    @usableFromInline func resolved<T: GloballyIdentifiable>(container: Container, identifier: T.InstanceIdentifier) -> T {
        let key = AnyHashable(identifier)
        if let existing = resolvedInstances[key] as? T {
            return existing
        } else {
            let new = T.make(container: container, identifier: identifier)
            resolvedInstances[key] = new
            return new
        }
    }

    /// Resolves an instance of `T` using `GlobalContainer`.
    @usableFromInline func resolved<T>(via initializer: @MainActor (Container) -> T, container: Container) -> T {
        if let existing = resolvedInstance as? T {
            return existing
        } else {
            let new = initializer(container)
            resolvedInstance = new
            return new
        }
    }

    /// Resolves an instance of `T` using `GlobalContainer`.
    @usableFromInline func resolved<T, InstanceIdentifier: Hashable>(for identifier: InstanceIdentifier, via initializer: @MainActor (Container) -> T, container: Container) -> T {
        let key = AnyHashable(identifier)
        if let existing = resolvedInstances[key] as? T {
            return existing
        } else {
            let new = initializer(container)
            resolvedInstances[key] = new
            return new
        }
    }

    /// Removes a previously-resolved instance for `identifier`, if any.
    @usableFromInline func removeInstance<T: GloballyIdentifiable>(of type: T.Type, for identifier: T.InstanceIdentifier) {
        let key = AnyHashable(identifier)
        resolvedInstances[key] = nil
    }

}
