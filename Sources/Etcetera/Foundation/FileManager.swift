//
//  FileManager.swift
//  Etcetera
//
//  Created by Jared Sinclair on 8/15/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//

import Foundation

/// Convenience methods extending FileManager. These swallow errors you don't
/// care to know the details about, or force-unwrap things that should never be
/// nil in practice (where a crash would be preferable to undefined behavior).
public extension FileManager {

    func cachesDirectory() -> URL {
        #if os(iOS) || os(watchOS)
        return urls(for: .cachesDirectory, in: .userDomainMask).first!
        #elseif os(OSX)
        let library = urls(for: .libraryDirectory, in: .userDomainMask).first!
        return library.appendingPathComponent("Caches", isDirectory: true)
        #endif
    }

    func documentsDirectory() -> URL {
        return urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    func createDirectory(at url: URL) -> Bool {
        do {
            try createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return true
        } catch {
            return false
        }
    }

    func createSubdirectory(named name: String, atUrl url: URL) -> Bool {
        let subdirectoryUrl = url.appendingPathComponent(name, isDirectory: true)
        return createDirectory(at: subdirectoryUrl)
    }

    func removeDirectory(_ directory: URL) -> Bool {
        do {
            try removeItem(at: directory)
            return true
        } catch {
            return false
        }
    }

    func removeFile(at url: URL) -> Bool {
        do {
            try removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    func fileExists(at url: URL) -> Bool {
        return fileExists(atPath: url.path)
    }

    func moveFile(from: URL, to: URL) throws {
        if fileExists(at: to) {
            _ = try replaceItemAt(to, withItemAt: from)
        } else {
            _ = try moveItem(at: from, to: to)
        }
    }

    func removeFilesByDate(inDirectory directory: URL, untilWithinByteLimit limit: UInt) {

        struct Item {
            let url: NSURL
            let fileSize: UInt
            let dateModified: Date
        }

        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]

        guard let urls = try? contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: .skipsHiddenFiles
            ) else { return }

        let items: [Item] = (urls as [NSURL])
            .compactMap { url -> Item? in
                guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
                return Item(
                    url: url,
                    fileSize: (values[.fileSizeKey] as? NSNumber)?.uintValue ?? 0,
                    dateModified: (values[.contentModificationDateKey] as? Date) ?? Date.distantPast
                )
        }
        .sorted { $0.dateModified < $1.dateModified }

        var total = items.map { $0.fileSize }.reduce(0, +)
        var toDelete = [Item]()
        for item in items {
            guard total > limit else { break }
            total -= item.fileSize
            toDelete.append(item)
        }

        toDelete.forEach {
            _ = try? self.removeItem(at: $0.url as URL)
        }
    }

}

private func didntThrow(_ block: () throws -> Void) -> Bool {
    do{ try block(); return true } catch { return false }
}
