//
//  DispatchQueue.swift
//  Etcetera
//
//  Created by Jared Sinclair on 8/25/18.
//

import Foundation

extension DispatchQueue {

    /// Because c'mon, really, how often do I ever need anything but this?
    public func after(_ seconds: TimeInterval, execute block: @escaping () -> Void) {
        asyncAfter(deadline: .now() + seconds, execute: block)
    }

}
