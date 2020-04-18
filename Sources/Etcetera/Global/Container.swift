//
//  Container.swift
//  Etcetera
//
//  Created by Jared Sinclair on 01/24/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import Foundation

/// Resolves and caches global dependencies.
public class Container {

    // MARK: - Public (Static)

    /// The current context.
    @inlinable public static var context: Context { shared.context }

    /// A developer-provided context to override the underlying default context.
    ///
    /// In most cases there's no need to override this value. You might do so
    /// when your app launches for UI testing, since this scenario cannot be
    /// detected through a generalizable solution:
    ///
    /// For example, in your UI test you might have code like this:
    ///
    ///     let app = XCUIApplication()
    ///     app.launchArguments.append("IS_UI_TESTING")
    ///     app.launch()
    ///
    /// Then in your app delegate, you would forward this to the dependency
    /// container like so:
    ///
    ///     if ProcessInfo.processInfo.arguments.contains("IS_UI_TESTING") {
    ///         Container.overrideContext = .userInterfaceTesting
    ///     }
    ///
    /// Lastly, if your application has dependencies that need to be configured
    /// differently for UI tests versus production, you can switch on the
    /// context as needed. Protocols can only be used with `@Global` through an
    /// extension of the `Global` struct that your app provides:
    ///
    ///     extension Global where Wrapped == WebServiceProtocol {
    ///         init() {
    ///             self.init(initializer: { container in
    ///                 switch container.context {
    ///                 case .userInterfaceTesting:
    ///                     return MockService()
    ///                 default:
    ///                     return ProdService()
    ///                 }
    ///             })
    ///         }
    ///     }
    ///
    /// This setup will allow your dependent types to receive the correct
    /// implementation of a protocol for production versus UI tests:
    ///
    ///     @Global() var webService: WebServiceProtocol
    ///
    public static var overrideContext: Context? {
        get { shared.overrideContext }
        set { shared.overrideContext = newValue }
    }

    /// Removes all previously-resolved dependencies.
    ///
    /// This method is safe to call from any queue, though it is difficult to
    /// imagine a scenario where it is not preferrable to call it from `.main`.
    @inlinable public static func removeAll() {
        shared.removeAll()
    }

    // MARK: - Public (Instance)

    /// The current context. The override context is used if the developer
    /// provides one, otherwise it will fall back to the default context.
    @inlinable public var context: Context { overrideContext ?? defaultContext }

    /// Resolves an instance of `T`.
    ///
    /// Use this method to resolve dependencies of a type that is itself a
    /// global dependency. For example, you might use it in an implementation of
    /// the `GloballyAvailable` protocol:
    ///
    ///     extension Foo: GloballyAvailable {
    ///         static func make(container: Container) -> Self {
    ///             let bar = container.resolveInstance(of: Bar.self)
    ///             return Foo(bar: bar)
    ///         }
    ///     }
    ///
    /// Or you might use it in a custom extension of `Global`, perhaps to allow
    /// a protocol type to participate:
    ///
    ///     extension Global where Wrapped == SomeProtocol {
    ///         init() {
    ///             self.init(initializer: {
    ///                 Foo(bar: $0.resolveInstance())
    ///             })
    ///         }
    ///     }
    ///
    /// - Note: Please take note that both available `resolveInstance` methods,
    /// (this one and the other one) **do not support types unless they are
    /// concrete types that conform to either GloballyAvailable or GloballyIdentifiable**.
    /// This is because the container needs a compile-time guaranteed way of
    /// resolving any dependency it is asked for with these methods. Only a
    /// concrete type conforming to one of these protocols is able to provide a
    /// compile-time guarantee.
    @inlinable public func resolveInstance<T: GloballyAvailable>(of type: T.Type = T.self) -> T {
        instanceResolver(for: T.self).resolved(container: self)
    }

    /// Same as `resolveInstance<T: GloballyAvailable`, but for identifiable types.
    /// The `identifier` argument is used to look up a specific instance among
    /// multiple instances of `T`.
    @inlinable public func resolveInstance<T: GloballyIdentifiable>(for identifier: T.InstanceIdentifier, of type: T.Type = T.self) -> T {
        instanceResolver(for: T.self).resolved(container: self, identifier: identifier)
    }

    // MARK: - Internal (Static)

    /// The shared container.
    ///
    /// Do **not** expose this as a public member. Use of this class is very
    /// intentionally limited to a handful of officially-supported workflows.
    @usableFromInline internal static let shared = Container()

    // MARK: - Internal (Instance)

    /// The fallback context when no `overrideContext` is set.
    @usableFromInline internal let defaultContext: Context = {
        ProcessInfo.isRunningInUnitTests ? .unitTesting : .running
    }()

    /// The developer-provided context, if any.
    @usableFromInline internal var overrideContext: Context?

    /// Thread-safe storage of instance resolvers (see extended developer
    /// comment inside `resolveInstance(of:)`.
    @usableFromInline internal var storage = Protected<[ObjectIdentifier: InstanceResolver]>([:])

    /// Initializes a dependency container
    @usableFromInline internal init() {}

    /// Resolves an instance of a type that is **not** constrained by either the
    /// `GloballyAvailable` or `GloballyIdentifiable` protocol. This method must
    /// not exposed at a public scope. It's only to be used by the `Global`
    /// struct in its "designated" initializers, which are called from
    /// developer-provided convenience initializers in extensions.
    @usableFromInline internal func resolveInstance<T>(via initializer: (Container) -> T) -> T {
        instanceResolver(for: T.self).resolved(via: initializer, container: self)
    }

    /// Same as `resolveInstance(via:)` except it also takes an instance identifier.
    @usableFromInline internal func resolveInstance<T, InstanceIdentifier: Hashable>(for identifier: InstanceIdentifier, via initializer: (Container) -> T) -> T {
        instanceResolver(for: T.self).resolved(for: identifier, via: initializer, container: self)
    }

    /// Finds (or creates) an instance resolver responsible for resolving one or
    /// more instances of `T`.
    @usableFromInline internal func instanceResolver<T>(for type: T.Type) -> InstanceResolver {
        storage.access { storage -> InstanceResolver in
            let resolverKey = ObjectIdentifier(T.self)
            if let existing = storage[resolverKey] {
                return existing
            } else {
                let new = InstanceResolver()
                storage[resolverKey] = new
                return new
            }
        }
    }

    /// Removes all resolved dependencies.
    ///
    /// This method is safe to call from any queue, though it is difficult to
    /// imagine a scenario where it is not preferrable to call it from `.main`.
    @usableFromInline internal func removeAll() {
        storage.access {
            $0.removeAll()
        }
    }

}

// MARK: - Automated Testing

extension Container {

    /// Seeds a resolved value of `T` into the global container.
    ///
    /// Use this method as an alternative to `make(container:)` to supercede
    /// what that method would have returned to the container. Care must
    /// be taken when using this method: any `@Global` property wrappers that
    /// attempt to resolve a value of `T` must not begin resolving their values
    /// until **after** you have called `seed(value:)`.
    ///
    /// Use of this method is strongly discouraged except outside of automated
    /// testing because **it will overwrite any previously resolved value**.
    @inlinable public static func seed<T: GloballyAvailable>(value: T) {
        shared.storage.access {
            let key = ObjectIdentifier(T.self)
            $0[key] = InstanceResolver(resolvedValue: value)
        }
    }

    /// The same as `seed(value:)`, except with per-instance identifiers.
    ///
    /// Use of this method is strongly discouraged except outside of automated
    /// testing because **it will overwrite any previously resolved values**.
    @inlinable public static func seed<T: GloballyIdentifiable>(values: [T.InstanceIdentifier: T]) {
        shared.storage.access {
            let key = ObjectIdentifier(T.self)
            $0[key] = InstanceResolver(resolvedValues: values)
        }
    }

}
