//
//  AnyInstanceIdentifier.swift
//  Etcetera
//
//  Created by Jared Sinclair on 01/24/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

/// Used to provide the same behavior as `GloballyIdentifiable.InstanceIdentifier`
/// but for `@Global`-wrapped types that participate in injection via developer-
/// provided extensions of `Global`.
///
/// - SeeAlso: Global.init(instanceIdentifier:initializer)
@usableFromInline internal struct AnyInstanceIdentifier<T, InstanceIdentifier: Hashable>: Hashable {

    /// Identifies a particular instance of `T`.
    let instanceIdentifier: InstanceIdentifier

    /// Identifies all instances of `T` as a group.
    let metatypeIdentifier = ObjectIdentifier(T.self)

    /// Initializes an identifier.
    @usableFromInline init(_ instanceIdentifier: InstanceIdentifier) {
        self.instanceIdentifier = instanceIdentifier
    }

}
