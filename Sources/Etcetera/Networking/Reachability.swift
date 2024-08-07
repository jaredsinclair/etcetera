//
//  Reachability.swift
//  Etcetera
//
//  Created by Jared Sinclair on 8/15/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//

import Foundation
import SystemConfiguration

extension Notification.Name {
    public static let ReachabilityChanged = Notification.Name(rawValue: "ReachabilityChanged")
}

/// A class that reports whether or not the network is currently reachable.
public final class Reachability: NSObject, Sendable {

    /// A more accurate alternative to using a Bool
    public enum Status {
        case probablyNotButWhoKnows
        case itWorkedThatOneTimeRecently
    }

    /// Shared instance. You're not obligated to use this.
    public static let shared = Reachability()

    /// Synchronous evaluation of the current flags using the shared instance.
    public static var status: Status {
        return shared.status
    }

    /// Synchronous evaluation of the current flags.
    public var status: Status {
        if let flags = flags, flags.contains(.reachable) {
            if flags.isDisjoint(with: [.connectionRequired, .interventionRequired]) {
                return .itWorkedThatOneTimeRecently
            }
        }
        return .probablyNotButWhoKnows
    }

    private let reachability: Protected<SCNetworkReachability?>
    private let _flags = Protected<SCNetworkReachabilityFlags?>()

    private var flags: SCNetworkReachabilityFlags? {
        get {
            _flags.current
        }
        set {
            _flags.current = newValue
            NotificationCenter.default.post(name: .ReachabilityChanged, object: nil)
        }
    }

    public init(host: String = "www.google.com") {
        let optionalReachability = SCNetworkReachabilityCreateWithName(nil, host)
        self.reachability = Protected(optionalReachability)
        super.init()
        guard let reachability = optionalReachability else { return }

        // Populate the current flags asap.
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability, &flags)
        self.flags = flags

        // Then configure the callback.
        let callback: SCNetworkReachabilityCallBack = { (_, flags, infoPtr) in
            guard let info = infoPtr else { return }
            let this = Unmanaged<Reachability>.fromOpaque(info).takeUnretainedValue()
            this.flags = flags
        }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var context = SCNetworkReachabilityContext(
            version: 0,
            info: selfPtr,
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        SCNetworkReachabilitySetCallback(reachability, callback, &context)
        SCNetworkReachabilitySetDispatchQueue(reachability, .main)
    }

}

extension Reachability.Status: CustomDebugStringConvertible {

    public var debugDescription: String {
        switch self {
        case .itWorkedThatOneTimeRecently: return ".itWorkedThatOneTimeRecently"
        case .probablyNotButWhoKnows: return ".probablyNotButWhoKnows"
        }
    }

}
