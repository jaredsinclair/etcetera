//
//  EtceteraTests.swift
//  EtceteraTests
//
//  Created by Jared Sinclair on 4/13/18.
//  Copyright © 2018 Nice Boy LLC. All rights reserved.
//

import XCTest
@testable import Etcetera

class EtceteraTests: XCTestCase {
    
    func testLog() {
        let log = OSLog(subsystem: "com.niceboy.EtceteraTests", category: "Logging")
        log.log("Success!")
    }
    
}
