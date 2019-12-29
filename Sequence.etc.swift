//
//  Reachability.swift
//  Etcetera
//
//  Copyright © 2018 Nice Boy LLC. All rights reserved.
//

extension Sequence {

    func map<T>(_ keyPath: KeyPath<Element, T>) -> [T] {
        return map { $0[keyPath: keyPath] }
    }

}
