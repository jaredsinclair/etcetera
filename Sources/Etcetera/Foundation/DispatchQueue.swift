//
//  DispatchQueue.swift
//  Etcetera
//
//  Created by Jared Sinclair on 8/15/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//

import Foundation

extension DispatchQueue {

    /// Because c'mon, really, how often do I ever need anything but this?
    public func after(_ seconds: TimeInterval, execute block: @escaping () -> Void) {
        asyncAfter(deadline: .now() + seconds, execute: block)
    }

}
