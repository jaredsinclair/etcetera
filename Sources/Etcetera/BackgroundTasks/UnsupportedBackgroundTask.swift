//
//  UnsupportedBackgroundTask.swift
//  Etcetera
//
//  Created by Jared Sinclair on 8/15/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//

import UIKit

/// For environments that do not support background tasks.
final class UnsupportedBackgroundTask: Sendable {

    @MainActor static func start() -> UnsupportedBackgroundTask? {
        return nil
    }

    @MainActor func start(withExpirationHandler handler: (() -> Void)?) -> Bool {
        return false
    }

    func end() {
        // no op
    }

    init() {}

}
