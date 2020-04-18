//
//  Sequence.swift
//  Etcetera
//
//  Created by Jared Sinclair on 8/15/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//

extension Sequence {

    public func map<T>(_ keyPath: KeyPath<Element, T>) -> [T] {
        return map { $0[keyPath: keyPath] }
    }

}
