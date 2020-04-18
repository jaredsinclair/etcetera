//
//  Container+Context.swift
//  Etcetera
//
//  Created by Jared Sinclair on 01/24/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

extension Container {

    /// Defines the context within which the container is being used.
    public enum Context: Hashable {

        /// Running in the typical manner.
        case running

        /// Running within a unit test.
        case unitTesting

        /// Running within a user interface test.
        ///
        /// - Note: It is not possible for the container to detect this context
        /// automatically. You must configure this value yourself by overriding
        /// the value of `DependencyContainer.context`.
        case userInterfaceTesting

        /// Running in a custom context.
        case custom(AnyHashable)

    }

}
