//
//  Global.swift
//  Etcetera
//
//  Created by Jared Sinclair on 1/24/20.
//

import Foundation

/// A property wrapper that automatically resolves global values registered with
/// a shared container of global values.
///
/// To use this property wrapper for a given type, two requirements must be met.
/// First you must register a resolver for your type:
///
///     GlobalContainer.register { container in
///         let bar: Bar = container.resolveInstance()
///         return Foo(bar: bar)
///     }
///
/// Next, in the type that depends upon that value, use the Global wrapper:
///
///     @Global var foo: Foo
///
/// You must ensure that the dependency resolver is registered prior the wrapped
/// property is first accessed, or else a precondition failure will be triggered.
///
/// ## Resolving Multiple Instances of the Same Type
///
/// If your application has multiple instances of the same type that need to be
/// stored in the GlobalContainer, use `@Global(identifer:)` instead. This
/// initializer uses a combination of the `Value` metatype and a developer-
/// provided "instance identifier" as a key when resolving the wrapped value.
/// The instance identifier can be anything you wish, as long as it conforms to
/// the `Hashable` protocol.
///
/// ## Working with Protocols
///
/// The `Global` property wrapper fully supports protocol-oriented values. Some
/// caveats need to be taken into account however. First, initializer blocks
/// must explicitly provide the protocol as the return type, otherwise the
/// concrete type will be inferred. For example:
///
///     // Don't do this:
///     GlobalContainer.register { _ in
///         MyImplementation()
///     }
///
///     // Instead do this:
///     GlobalContainer.register { _ -> MyProtocol in
///         MyImplementation()
///     }
///
/// This will allow your `@Global` property wrappers to be declared using the
/// protocol and not the concrete type:
///
///     @Global var someObject: MyProtocol
///
/// A compile-time error will not be available if you make a mistake. Be sure to
/// test all `@Global` values carefully to check for resolution errors.
///
/// Use the `context` property of the global container to return different
/// implementations of a given protocol for production versus UI testing:
///
///     GlobalContainer.register { container -> MyProtocol in
///         if container.context == .userInterfaceTest {
///             return TestImplementation()
///         } else {
///             return ProdImplementation()
///         }
///     }
///
/// Bear in mind that the container can't automatically detect a UI test like it
/// can detect a unit test context. For UI tests, you must detect this yourself
/// and set the `overrideContext` property of the `GlobalContainer` as early as
/// possible in the lifecycle of your app.
@propertyWrapper public struct Global<Value> {

    /// The resolved global value.
    public let wrappedValue: Value

    /// Resolves a global value where only once instance of `Value` is ever used.
    public init() {
        wrappedValue = GlobalContainer.shared.resolveInstance()
    }

    /// Resolves a global where multiple instances of the same type may exist at
    /// one time in the container, identified by a unique identifier per instance.
    public init<InstanceIdentifier: Hashable>(_ instanceIdentifier: InstanceIdentifier) {
        let id = AnyHashable(instanceIdentifier)
        wrappedValue = GlobalContainer.shared.resolveInstance(identifier: id)
    }

}

/// Stores all registered dependency resolvers and their resolved values.
///
/// Applications cannot initialize this class directly. Instead, use is limited
/// to methods that register resolver blocks and retrieve resolved values.
public class GlobalContainer {

    /// You may configure this value if you need to provide a context other than
    /// the one that is automatically detected by the container. For example,
    /// you may wish to override with `.userInterfaceTest` when running your app
    /// as a runner for UI tests.
    public static var overrideContext: Context?

    /// Registers a block that can resolve a given dependency on demand.
    ///
    /// - parameter resolver: A block that supplies an instance of the required
    ///   value on demand. While the implementation details are left to the
    ///   developer to determine, it is assumed that a value returned from this
    ///   block can be reused across the lifetime of the application, or until
    ///   `register(resolver:)` is called again for the same type `T`.
    ///
    /// It is safe to call this method from any thread, however it is suggested
    /// that you call this method as early as possible in your application life
    /// cycle so that all resolvers have been registered before they are
    /// accessed. Accessing a dependency before a resolver has been registered
    /// for it will trigger a precondition failure.
    public static func register<T>(resolver: @escaping (GlobalContainer) -> T) {
        shared.storage[Key(T.self)] = MetatypeStorage(resolver: resolver)
    }

    /// Registers a block that can resolve a given dependency on demand. This
    /// method allows multiple instances of the same type to be Global-wrapped.
    ///
    /// - parameter resolver: A block that supplies an instance of the required
    ///   value on demand. In addition to a GlobalContainer argument, an instance
    ///   identifier is provided which corresponds to the identifier used at the
    ///   `@Global(<identifier>)` call site. This argument is a convenience.
    ///   The `resolver` block does not have to use it (e.g. it does not have to
    ///   implement its own caching mechanism).
    ///
    /// It is safe to call this method from any thread, however it is suggested
    /// that you call this method as early as possible in your application life
    /// cycle so that all resolvers have been registered before they are
    /// accessed. Accessing a dependency before a resolver has been registered
    /// for it will trigger a precondition failure.
    public static func register<T, InstanceIdentifier: Hashable>(type: T.Type = T.self, resolver: @escaping (GlobalContainer, InstanceIdentifier) -> T) {
        shared.storage[Key(T.self)] = MetatypeStorage(resolver: resolver)
    }

    /// The current context.
    public var context: Context {
        GlobalContainer.overrideContext ?? nativeContext
    }

    /// Resolves an instance of `T`.
    ///
    /// Use this method inside a resolver block if a given type depends upon
    /// other values tracked by `GlobalContainer`, for example:
    ///
    ///     GlobalContainer.register { deps in
    ///         let foo = deps.resolveInstance(of: Foo.self)
    ///         return Bar(foo: foo)
    ///     }
    public func resolveInstance<T>(of type: T.Type) -> T {
        guard let resolver = storage[Key(type)] else {
            preconditionFailure("Unable to resolve instance of type \(T.self)")
        }
        return resolver.resolved(container: self)
    }

    /// Resolves an instance of `T`.
    ///
    /// Convenient alternative to `resolveInstance(of:)` where the type can be
    /// inferred from the left-hand-side of an assignment.
    public func resolveInstance<T>() -> T {
        resolveInstance(of: T.self)
    }

    /// Resolves an instance of `T` for a given instance identifier.
    ///
    /// Use this method inside a resolver block if a given type depends upon
    /// other values tracked by `GlobalContainer`, for example:
    ///
    ///     GlobalContainer.register { (deps, id) in
    ///         let foo = deps.resolveInstance(of: Foo.self, identifier: id)
    ///         return Bar(foo: foo, identifier: id)
    ///     }
    public func resolveInstance<T, InstanceIdentifier: Hashable>(of type: T.Type, identifier: InstanceIdentifier) -> T {
        guard let resolver = storage[Key(type)] else {
            preconditionFailure("Unable to resolve instance of type \(T.self)")
        }
        return resolver.resolved(container: self, identifier: identifier)
    }

    /// Resolves an instance of `T` for a given instance identifier.
    ///
    /// Convenient alternative to `resolveInstance(of:identifier)` where the
    /// type can be inferred from the left-hand-side of an assignment.
    public func resolveInstance<T, InstanceIdentifier: Hashable>(identifier: InstanceIdentifier) -> T {
        resolveInstance(of: T.self, identifier: identifier)
    }

    /// Removes a previously-resolved instance of `T` for `identifier`, if any.
    public func removeInstance<T, InstanceIdentifier: Hashable>(of type: T.Type, for identifier: InstanceIdentifier) {
        storage[Key(T.self)]?.removeInstance(of: type, for: identifier)
    }

    /// A shared instance that stores all application GlobalContainer.
    fileprivate static let shared = GlobalContainer()

    /// The underlying native context.
    private var nativeContext: Context {
        ProcessInfo.isRunningInUnitTests ? .unitTest : .default
    }

    /// Private, thread-safe storage of resolvers keyed by metatype.
    ///
    /// If per-instance identifiers are used by the application, each resolved
    /// instance is stored within a single `MetatypeStorage` instance.
    private var storage = ProtectedDictionary<Key, MetatypeStorage>()

}

extension GlobalContainer {

    /// The run time context in which global values are being used.
    public enum Context: Equatable {

        /// The default context: running the app by itself, not as a test runner for
        /// unit or user interface tests, nor a custom context.
        case `default`

        /// The app is running as a test runner for unit tests.
        case unitTest

        /// The app is running in a user interface test.
        ///
        /// This context cannot be automatically detected by `Global`. You must
        /// manually indicate this context by overriding the global container's
        /// context.
        case userInterfaceTest

        /// A developer-provided custom context.
        case custom(Any)

        public static func ==(lhs: Context, rhs: Context) -> Bool {
            switch (lhs, rhs) {
            case (.default, .default),
                 (.unitTest, .unitTest),
                 (.userInterfaceTest, .userInterfaceTest):
                return true
            case (.custom(let left as AnyHashable), .custom(let right as AnyHashable)):
                return left == right
            case (.default, _),
                 (.unitTest, _),
                 (.userInterfaceTest, _),
                 (.custom, _):
                return false
            }
        }

    }

}

/// A multi-purpose key composed of a metatype identifier and an optional
/// instance identifier.
///
/// Use of the instance identifier should only be necessary for MetatypeStorage,
/// as the GlobalContainer class's storage only needs to be keyed by metatype.
private struct Key: Hashable {

    let metatypeIdentifier: ObjectIdentifier
    let instanceIdentifier: AnyHashable?

    init(_ metatype: Any.Type) {
        self.metatypeIdentifier = ObjectIdentifier(metatype)
        self.instanceIdentifier = nil
    }

    init<InstanceIdentifier: Hashable>(_ metatype: Any.Type, metatypeInstanceIdentifier identifier: InstanceIdentifier) {
        self.metatypeIdentifier = ObjectIdentifier(metatype)
        self.instanceIdentifier = AnyHashable(identifier)
    }

}

/// Stores a resolver block and one or more resolved instances of a given type.
private final class MetatypeStorage {

    /// The resolver block provided by the developer.
    private let resolver: (GlobalContainer, AnyHashable?) -> Any

    /// Thread-safe storage of resolved instances.
    private var resolvedInstances = ProtectedDictionary<Key, Any>()

    /// Initializer for resolution that does not require per-instance identifiers.
    init<T>(resolver: @escaping (GlobalContainer) -> T) {
        self.resolver = { (d, _) in resolver(d) }
    }

    /// Initializer for resolution tracked by per-instance identifiers.
    init<T, InstanceIdentifier: Hashable>(resolver: @escaping (GlobalContainer, InstanceIdentifier) -> T) {
        self.resolver = { (d, anyID) in
            let identifier = anyID?.base as! InstanceIdentifier
            return resolver(d, identifier)
        }
    }

    /// Resolves an instance of `T` using `GlobalContainer`.
    func resolved<T>(container: GlobalContainer) -> T {
        let key = Key(T.self)
        return resolvedInstances.access { dictionary -> T in
            if let existing = dictionary[key] as? T {
                return existing
            } else {
                guard let new = resolver(container, nil) as? T else {
                    preconditionFailure("Unable to resolve instance of type \(T.self)")
                }
                dictionary[key] = new
                return new
            }
        }
    }

    /// Resolves a specific instance of `T` for a given identifier.
    func resolved<T, InstanceIdentifier: Hashable>(container: GlobalContainer, identifier: InstanceIdentifier) -> T {
        let key = Key(T.self, metatypeInstanceIdentifier: identifier)
        return resolvedInstances.access { dictionary -> T in
            if let existing = dictionary[key] as? T {
                return existing
            } else {
                let anyIdentifier = AnyHashable(identifier)
                guard let new = resolver(container, anyIdentifier) as? T else {
                    preconditionFailure("Unable to resolve instance of type \(T.self)")
                }
                dictionary[key] = new
                return new
            }
        }
    }

    /// Removes a previously-resolved instance of `T` for `identifier`, if any.
    func removeInstance<T, InstanceIdentifier: Hashable>(of type: T.Type, for identifier: InstanceIdentifier) {
        let key = Key(T.self, metatypeInstanceIdentifier: identifier)
        resolvedInstances[key] = nil
    }

}
