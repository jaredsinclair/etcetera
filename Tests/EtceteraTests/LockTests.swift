//
//  LockTests.swift
//  EtceteraTests
//
//  Created by Jared Sinclair on 4/18/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//
// Based on code by Peter Steinberger from:
// https://gist.github.com/steipete/36350a8a60693d440954b95ea6cbbafc

import os.lock
import XCTest
import Etcetera

final class LockTests: XCTestCase {

    func testLock() {
        let lock = Lock()
        executeLockTest { (block) in
            lock.locked {
                block()
            }
        }
    }

    private func executeLockTest(performLocked lockingClosure: @escaping (_ block:() -> Void) -> Void) {
        let dispatchBlockCount = 16
        let iterationCountPerBlock = 100_000
        let queues = [
            DispatchQueue.global(qos: .userInteractive),
            DispatchQueue.global(qos: .default),
            DispatchQueue.global(qos: .utility),
        ]
        self.measure {
            var value = 0 // Value must be defined here because `measure` is repeated.
            let group = DispatchGroup()
            for block in 0..<dispatchBlockCount {
                group.enter()
                let queue = queues[block % queues.count]
                queue.async {
                    for _ in 0..<iterationCountPerBlock {
                        lockingClosure({
                            value = value + 2
                            value = value - 1
                        })
                    }
                    group.leave()
                }
            }
            _ = group.wait(timeout: DispatchTime.distantFuture)
            XCTAssertEqual(value, dispatchBlockCount * iterationCountPerBlock)
        }
    }

}
