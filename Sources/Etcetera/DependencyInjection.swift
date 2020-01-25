//
//  DependencyInjection.swift
//  Etcetera
//
//  Created by Jared Sinclair on 1/24/20.
//

/// A protocol to which all `@Inject` dependencies must conform, ensuring that
/// the property wrapper is not used with an unsupported type.
///
/// Apply this protocol to any type where your application only ever needs a
/// single instance of that type, shared by all dependents.
public protocol Injectable {}

/// A protocol to which all `@UniqueInject` dependencies must conform, ensuring
/// that the property wrapper is not used with an unsupported type.
///
/// Apply this protocol to any type where your application needs two or more
/// instances of the same type, identified by a per-instance identifier.
public protocol UniquelyInjectable {}

/// A property wrapper that allows registered dependencies to be automatically
/// resolved at runtime.
///
/// To use this property wrapper for a given type, two requirements must be met.
/// First you must register a resolver for your `Injectable`-conforming type:
///
///     Dependencies.register { Foo(dependencies: $0) }
///
/// Next, in the type that depends upon that value, use the Inject wrapper:
///
///     @Inject var foo: Foo
///
/// You must ensure that the dependency resolver is registered prior the wrapped
/// property is first accessed, or else a precondition failure will be triggered.
///
/// ## Resolving Multiple Instances of the Same Type
///
/// If your application has multiple instances of the same type that need to be
/// injectable dependencies, use `@UniqueInject` instead.
@propertyWrapper public struct Inject<Type: Injectable> {

    /// The underlying depended-upon value.
    public let wrappedValue: Type

    /// Injects a dependency where only one instance of `Type` is ever used.
    public init() {
        wrappedValue = Dependencies.shared.resolveInstance()
    }

}

/// A property wrapper that allows registered dependencies to be automatically
/// resolved at runtime, and which supports resolving multiple instances of the
/// same type via unique identifiers per-instance.
///
/// To use this property wrapper for a given type, two requirements must be met.
/// First you must register a resolver for your `UniquelyInjectable` type:
///
///     Dependencies.register { (deps, id) in
///         Foo(dependencies: deps, identifier: id)
///     }
///
/// Next, in the type that depends upon that value, use the Inject wrapper:
///
///     @UniqueInject("MyIdentifier") var foo: Foo
///
/// You must ensure that the dependency resolver is registered prior the wrapped
/// property is first accessed, or else a precondition failure will be triggered.
@propertyWrapper public struct UniqueInject<Type: UniquelyInjectable> {

    /// The underlying depended-upon value.
    public let wrappedValue: Type

    /// Injects a dependency where discrete instances of `Type` are resolved
    /// via identifiers unique to each instance.
    public init<ID: Hashable>(_ identifier: ID) {
        wrappedValue = Dependencies.shared.resolveInstance(identifier: identifier)
    }

}

/// Stores all registered dependency resolvers and their resolved values.
///
/// Applications cannot initialize this class directly. Instead, use is limited
/// to methods that register resolver blocks and retrieve resolved values.
public class Dependencies {

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
    public static func register<T: Injectable>(resolver: @escaping (Dependencies) -> T) {
        shared.storage[Key(T.self)] = MetatypeStorage(resolver: resolver)
    }

    /// Registers a block that can resolve a given dependency on demand. This
    /// method allows multiple instances of the same type to be injectable.
    ///
    /// - parameter resolver: A block that supplies an instance of the required
    ///   value on demand. In addition to a Dependencies argument, an instance
    ///   identifier is provided which corresponds to the identifier used at the
    ///   `@Injectable(<identifier>)` call site. This argument is a convenience.
    ///   The `resolver` block does not have to use it (e.g. it does not have to
    ///   implement it's own caching mechanism).
    ///
    /// It is safe to call this method from any thread, however it is suggested
    /// that you call this method as early as possible in your application life
    /// cycle so that all resolvers have been registered before they are
    /// accessed. Accessing a dependency before a resolver has been registered
    /// for it will trigger a precondition failure.
    public static func register<T: UniquelyInjectable, ID: Hashable>(resolver: @escaping (Dependencies, ID) -> T) {
        shared.storage[Key(T.self)] = MetatypeStorage(resolver: resolver)
    }

    /// Resolves an instance of `T`.
    ///
    /// Use this method inside a resolver block if a given type depends upon
    /// other values tracked by `Dependencies`, for example:
    ///
    ///     Dependencies.register { deps in
    ///         let foo = deps.resolveInstance(of: Foo.self)
    ///         return Bar(foo: foo)
    ///     }
    public func resolveInstance<T: Injectable>(of type: T.Type) -> T {
        guard let instance: T = storage[Key(type)]?.resolved(dependencies: self) else {
            preconditionFailure("Unable to resolve instance of type \(T.self)")
        }
        return instance
    }

    /// Resolves an instance of `T`.
    ///
    /// Convenient alternative to `resolveInstance(of:)` where the type can be
    /// inferred from the left-hand-side of an assignment.
    public func resolveInstance<T: Injectable>() -> T {
        resolveInstance(of: T.self)
    }

    /// Resolves an instance of `T` for a given instance identifier.
    ///
    /// Use this method inside a resolver block if a given type depends upon
    /// other values tracked by `Dependencies`, for example:
    ///
    ///     Dependencies.register { (deps, id) in
    ///         let foo = deps.resolveInstance(of: Foo.self, identifier: id)
    ///         return Bar(foo: foo, identifier: id)
    ///     }
    public func resolveInstance<T: UniquelyInjectable, ID: Hashable>(of type: T.Type, identifier: ID) -> T {
        guard let instance: T = storage[Key(type)]?.resolved(dependencies: self, identifier: identifier) else {
            preconditionFailure("Unable to resolve instance of type \(T.self)")
        }
        return instance
    }

    /// Resolves an instance of `T` for a given instance identifier.
    ///
    /// Convenient alternative to `resolveInstance(of:identifier)` where the
    /// type can be inferred from the left-hand-side of an assignment.
    public func resolveInstance<T: UniquelyInjectable, ID: Hashable>(identifier: ID) -> T {
        resolveInstance(of: T.self, identifier: identifier)
    }

    /// Removes a previously-resolved instance of `T` for `identifier`, if any.
    public func removeInstance<T: UniquelyInjectable, ID: Hashable>(of type: T.Type, for identifier: ID) {
        storage[Key(T.self)]?.removeInstance(of: type, for: identifier)
    }

    /// A shared instance that stores all application dependencies.
    fileprivate static let shared = Dependencies()

    /// Private, thread-safe storage of resolvers keyed by metatype.
    ///
    /// If per-instance identifiers are used by the application, each resolved
    /// instance is stored within a single `MetatypeStorage` instance.
    private var storage = ProtectedDictionary<Key, MetatypeStorage>()

}

/// A multi-purpose key composed of a metatype identifier and an optional
/// instance identifier.
///
/// Use of the instance identifier should only be necessary for MetatypeStorage,
/// as the Dependencies class's storage only needs to be keyed by metatype.
private struct Key: Hashable {

    let metatypeIdentifier: ObjectIdentifier
    let instanceIdentifier: AnyHashable?

    init(_ metatype: Any.Type) {
        self.metatypeIdentifier = ObjectIdentifier(metatype)
        self.instanceIdentifier = nil
    }

    init<InstanceID: Hashable>(_ metatype: Any.Type, metatypeInstanceIdentifier identifier: InstanceID) {
        self.metatypeIdentifier = ObjectIdentifier(metatype)
        self.instanceIdentifier = AnyHashable(identifier)
    }

}

/// Stores a resolver block and one or more resolved instances of a given type.
private final class MetatypeStorage {

    /// The resolver block provided by the developer.
    private let resolver: (Dependencies, AnyHashable?) -> Any

    /// Thread-safe storage of resolved instances.
    private var _resolved = ProtectedDictionary<Key, Any>()

    /// Initializer for resolution that does not require per-instance identifiers.
    init<T: Injectable>(resolver: @escaping (Dependencies) -> T) {
        self.resolver = { (d, _) in resolver(d) }
    }

    /// Initializer for resolution tracked by per-instance identifiers.
    init<T: UniquelyInjectable, ID: Hashable>(resolver: @escaping (Dependencies, ID) -> T) {
        self.resolver = { (d, anyID) in
            let identifier = anyID?.base as! ID
            return resolver(d, identifier)
        }
    }

    /// Resolves an instance of `T` using `dependencies`.
    func resolved<T: Injectable>(dependencies: Dependencies) -> T {
        let key = Key(T.self)
        return _resolved.access { dictionary -> T in
            if let existing = dictionary[key] as? T {
                return existing
            } else {
                guard let new = resolver(dependencies, nil) as? T else {
                    preconditionFailure("Unable to resolve instance of type \(T.self)")
                }
                dictionary[key] = new
                return new
            }
        }
    }

    /// Resolves a specific instance of `T` for a given identifier.
    func resolved<T: UniquelyInjectable, ID: Hashable>(dependencies: Dependencies, identifier: ID) -> T {
        let key = Key(T.self, metatypeInstanceIdentifier: identifier)
        return _resolved.access { dictionary -> T in
            if let existing = dictionary[key] as? T {
                return existing
            } else {
                let anyIdentifier = AnyHashable(identifier)
                guard let new = resolver(dependencies, anyIdentifier) as? T else {
                    preconditionFailure("Unable to resolve instance of type \(T.self)")
                }
                dictionary[key] = new
                return new
            }
        }
    }

    /// Removes a previously-resolved instance of `T` for `identifier`, if any.
    func removeInstance<T: UniquelyInjectable, ID: Hashable>(of type: T.Type, for identifier: ID) {
        let key = Key(T.self, metatypeInstanceIdentifier: identifier)
        _resolved[key] = nil
    }

}
