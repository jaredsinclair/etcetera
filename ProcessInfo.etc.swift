//
//  ProcessInfo.swift
//  Etcetera
//
//  Copyright © 2018 Nice Boy LLC. All rights reserved.
//
// swiftlint:disable nesting - Seriously, why do we even Swift then.

import Foundation

/// Quality-of-life extension of ProcessInfo.
extension ProcessInfo {

    /// Represents an process info argument.
    ///
    /// Define your own custom arguments in an extension of Argument:
    ///
    ///     extension ProcessInfo.Argument {
    ///         static let resetCachesOnLaunch = "resetCachesOnLaunch"
    ///     }
    ///
    /// If you want to prefix your launch arguments, then as early as possible
    /// during app launch, provide a value for the common prefix:
    ///
    ///     ProcessInfo.Argument.commonPrefix = "-com.domain.MyApp"
    ///
    /// Next, edit your target's Xcode scheme to add the following for each of
    /// your custom launch arguments:
    ///
    ///     -com.domain.MyApp.resetCachesOnLaunch 1
    ///
    /// Check for the presence of a process argument via:
    ///
    ///     if ProcessInfo.isArgumentEnabled(.resetCachesOnLaunch) { ... }
    ///
    /// or:
    ///
    ///     if ProcessInfo.Argument.resetCachesOnLaunch.isEnabled { ... }
    public struct Argument: RawRepresentable, ExpressibleByStringLiteral {

        /// Supply your own "-com.domain.MyApp." prefix which must be present in
        /// all the custom arguments defined in your target's scheme editor.
        public static var commonPrefix = ""

        /// Required by `RawRepresentable`.
        public typealias RawValue = String

        /// Required by `ExpressibleByStringLiteral`
        public typealias StringLiteralType = String

        /// The portion of the argument excluding any common prefix.
        public let rawValue: String

        /// - returns: Returns `true` if the argument is found among the process
        /// info launch arguments.
        public var isEnabled: Bool {
            return ProcessInfo.isArgumentEnabled(self)
        }

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            self.rawValue = value
        }
    }

    /// - returns: Returns `true` if `argument` is found among the arguments.
    public static func isArgumentEnabled(_ argument: Argument) -> Bool {
        let string = Argument.commonPrefix + argument.rawValue
        return processInfo.arguments.contains(string)
    }

}
