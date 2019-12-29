//
//  Collections.swift
//  Etcetera
//
//  Copyright © 2018 Nice Boy LLC. All rights reserved.
//
// swiftlint:disable line_length - I dislike multi-line function signatures.

/// Quality-of-life extension of RandomAccessCollection.
extension RandomAccessCollection {

    /// A flavor of subscripting that returns an optional element if the index
    /// is out-of-bounds.
    public subscript(optional index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }

}

/// Quality-of-life extension of Sequence.
public extension Sequence {

    /// Maps the receiver to a dictionary using a block to generate keys.
    ///
    /// - parameter block: A block that returns the key for a given element.
    ///
    /// - parameter firstWins: If `false` the last key/value pair overwrites any
    /// previous entries with the same key.
    ///
    /// - returns: Returns a dictionary of elements using the chosen keys.
    func map<Key: Hashable>(usingKeysFrom block: (Element) -> Key, firstWins: Bool = false) -> [Key: Element] {
        let keyValues: [(Key, Element)] = map { (block($0), $0) }
        return Dictionary(keyValues, uniquingKeysWith: { first, last in firstWins ? first : last })
    }

    /// Maps the receiver to a dictionary using key paths to generate keys.
    ///
    /// - parameter keyPath: The keyPath to the key for a given element.
    ///
    /// - parameter firstWins: If `false` the last key/value pair overwrites any
    /// previous entries with the same key.
    ///
    /// - returns: Returns a dictionary of elements using the chosen keys.
    func map<Key: Hashable>(using keyPath: KeyPath<Element, Key>, firstWins: Bool = false) -> [Key: Element] {
        let keyValues: [(Key, Element)] = map { ($0[keyPath: keyPath], $0) }
        return Dictionary(keyValues, uniquingKeysWith: { first, last in firstWins ? first : last })
    }

}

/// Quality-of-life extension of Swift.Dictionary.
extension Dictionary {

    /// Initializes a new dictionary with the elements of a sequence, creating
    /// keys via a block argument.
    ///
    /// - parameter sequence: The source sequence of elements.
    ///
    /// - parameter block: A block which can generate a key from any given
    /// element in `sequence`.
    ///
    /// - parameter firstWins: If `false`, the last key/value pair overwrites
    /// any previous pair for the same key.
    public init<S: Sequence>(_ sequence: S, usingKeysFrom block: (Value) -> Key, firstWins: Bool = false) where S.Element == Value {
        self = sequence.map(usingKeysFrom: block, firstWins: firstWins)
    }

    public init<S: Sequence>(_ sequence: S, using keyPath: KeyPath<Value, Key>, firstWins: Bool = false) where S.Element == Value {
        self = sequence.map(using: keyPath, firstWins: firstWins)
    }

}
