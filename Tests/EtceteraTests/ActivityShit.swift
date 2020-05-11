//
//  ActivityTests.swift
//  EtceteraTests
//
//  Created by Jared Sinclair on 5/11/20.
//

import XCTest
import Etcetera
import os.activity

final class ActivityTests: XCTestCase {

    func test_teenySmokeTest() {
        let leave = Activity("testin stuff").enter()
        leave()
    }

}
