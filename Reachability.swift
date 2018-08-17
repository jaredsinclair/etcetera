//
//  Reachability.swift
//  Etcetera
//
//  Copyright © 2018 Nice Boy LLC. All rights reserved.
//

import Foundation
import SystemConfiguration

extension Notification.Name {
    public static let ReachabilityChanged = Notification.Name(rawValue: "ReachabilityChanged")
}

/// A class that reports whether or not the network is currently reachable.
public class Reachability: NSObject {

    /// Shared instance. You're not obligated to use this.
    public static let shared = Reachability()

    /// Synchronous evaluation of the current flags using the shared instance.
    public static var isReachable: Bool {
        return shared.isReachable
    }

    /// Synchronous evaluation of the current flags.
    public var isReachable: Bool {
        return flags?.contains(.reachable) == true
    }

    private let reachability: SCNetworkReachability?
    private var lock = os_unfair_lock()
    private var _flags: SCNetworkReachabilityFlags?
    private var flags: SCNetworkReachabilityFlags? {
        get {
            os_unfair_lock_lock(&lock)
            let value = _flags
            os_unfair_lock_unlock(&lock)
            return value
        }
        set {
            os_unfair_lock_lock(&lock)
            _flags = newValue
            os_unfair_lock_unlock(&lock)
            NotificationCenter.default.post(name: .ReachabilityChanged, object: nil)
        }
    }

    public init(host: String = "www.google.com") {
        self.reachability = SCNetworkReachabilityCreateWithName(nil, host)
        super.init()
        guard let reachability = reachability else { return }

        // Populate the current flags asap.
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability, &flags)
        _flags = flags

        // Then configure the callback.
        let callback: SCNetworkReachabilityCallBack = { (_, flags, infoPtr) in
            guard let info = infoPtr else { return }
            let this = Unmanaged<Reachability>.fromOpaque(info).takeUnretainedValue()
            this.flags = flags
        }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var context = SCNetworkReachabilityContext(version: 0, info: selfPtr, retain: nil, release: nil, copyDescription: nil)
        SCNetworkReachabilitySetCallback(reachability, callback, &context)
        SCNetworkReachabilitySetDispatchQueue(reachability, .main)
    }

}
