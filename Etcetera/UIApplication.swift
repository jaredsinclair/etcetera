//
//  UIApplication.swift
//  Etcetera
//
//  Copyright © 2018 Nice Boy LLC. All rights reserved.
//

import UIKit

extension UIApplication {

    /// - returns: Returns `true` if the application is running during unit tests.
    public var isRunningFromTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

}
