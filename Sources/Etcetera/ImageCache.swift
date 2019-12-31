//
//  ImageCache.swift
//  Etcetera
//
//  Created by Jared Sinclair on 8/15/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//
// swiftlint:disable file_length - This <USED TO BE> intentionally a one-file, a drop-in.
// swiftlint:disable identifier_name - Clarity!
// swiftlint:disable line_length - I dislike multi-line function signatures.
// swiftlint:disable nesting - Seriously, why do we even Swift then.
// swiftlint:disable function_parameter_count - Some problems are hard.

#if os(iOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

/// An image cache that balances high-performance features with straightforward
/// usage and sensible defaults.
///
/// - Note: This file is embarassingly long, but it's purposeful. Each file in
/// Etcetera is meant to be self-contained, ready to be dropped into your
/// project all by itself. That's also why this file has some duplicated bits of
/// utility code found elsewhere in Etcetera.
///
/// - Warning: This class currently only supports iOS. I have vague plans to
/// have it support macOS and watchOS, too, but that's not guaranteed.
public final class ImageCache {

    // MARK: Shared Instance

    /// The shared instance. You're not obligated to use this.
    public static let shared = ImageCache()

    // MARK: Public Properties

    /// The default directory where ImageCache stores files on disk.
    public static var defaultDirectory: URL {
        return FileManager.default.cachesDirectory().subdirectory(named: "Images")
    }

    /// Disk storage will be automatically trimmed to this byte limit (by 
    /// trimming the least-recently accessed items first). Trimming will occur
    /// whenever the app enters the background, or when this value is changed.
    ///
    /// Provide a `nil` value to allow for unbounded disk usage. YOLO.
    public var byteLimitForFileStorage: Bytes? {
        didSet { trimStaleFiles() }
    }

    /// Your app can provide something stronger than "\(url.hashValue)" if you
    /// will encounter images with very long file URLs that could collide with
    /// one another. The value returned from this function is used to form the
    /// filename for cached images (since URLs could be longer than the max
    /// allowed file name length). Letting your app inject this functionality
    /// eliminates an awkward dependency on a stronger hashing algorithm.
    public var uniqueFilenameFromUrl: (URL) -> String

    /// When `true` this will empty the in-memory cache when the app enters the
    /// background. This can help reduce the likelihood that your app will be
    /// terminated in order to reclaim memory for foregrounded applications.
    /// Defaults to `false`.
    public var shouldRemoveAllImagesFromMemoryWhenAppEntersBackground: Bool {
        get { return memoryCache.shouldRemoveAllObjectsWhenAppEntersBackground }
        set { memoryCache.shouldRemoveAllObjectsWhenAppEntersBackground = newValue }
    }

    // MARK: Private Properties

    private let directory: URL
    private let urlSession: URLSession
    private let formattingTaskRegistry = TaskRegistry<ImageKey, Image?>()
    private let downloadTaskRegistry = TaskRegistry<ImageKey, DownloadResult?>()
    private let userImageDiskTaskRegistry = TaskRegistry<ImageKey, Void>()
    private let memoryCache = MemoryCache<ImageKey, Image>()
    private let formattingQueue: OperationQueue
    private let workQueue: OperationQueue
    private var observers = [NSObjectProtocol]()

    // MARK: Init / Deinit

    /// Designated initializer.
    ///
    /// - parameter directory: The desired directory. This must not be a system-
    /// managed directory (like /Caches), but it can be a subdirectory thereof.
    ///
    /// - parameter byteLimitForFileStorage: Disk storage will be automatically
    /// trimmed to this byte limit (by trimming the least-recently accessed
    /// items first). Trimming will occur whenever the app enters the
    /// background, or when this value is changed. Provide a `nil` value to
    /// allow for unbounded disk usage. YOLO.
    public init(directory: URL = ImageCache.defaultDirectory, byteLimitForFileStorage: Bytes? = .fromMegabytes(500)) {
        self.uniqueFilenameFromUrl = { return "\($0.hashValue)" }
        self.directory = directory
        self.byteLimitForFileStorage = byteLimitForFileStorage
        self.urlSession = {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 90
            return URLSession(configuration: config)
        }()
        self.formattingQueue = {
            let q = OperationQueue()
            q.qualityOfService = .userInitiated
            return q
        }()
        self.workQueue = {
            let q = OperationQueue()
            q.qualityOfService = .userInitiated
            return q
        }()
        _ = FileManager.default.createDirectory(at: directory)
        registerObservers()
    }

    deinit {
        observers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
    }

    // MARK: Public Methods

    /// Retrieves an image from the specified URL, formatted to the requested
    /// format.
    ///
    /// If the formatted image already exists in memory, it will be returned
    /// synchronously. If not, ImageCache will look for the cached formatted
    /// image on disk. If that is not found, ImageCache will look for the cached
    /// original image on disk, format it, save the formatted image to disk, and
    /// return the formatted image. If all of the above turn up empty, the
    /// original file will be downloaded from the url and saved to disk, then
    /// the formatted image will be generated and saved to disk, then the
    /// formatted image will be cached in memory, and then finally the formatted
    /// image will be returned to the caller via the completion handler. If any
    /// of the above steps fail, the completion block will be called with `nil`.
    ///
    /// Concurrent requests for the same resource are combined into the smallest
    /// possible number of active tasks. Requests for different image formats
    /// based on the same original image will lead to a single download task for
    /// the original file. Requests for the same image format will lead to a
    /// single image formatting task. The same result is distributed to all
    /// requests in the order in which they were requested.
    ///
    /// - parameter url: The HTTP URL at which the original image is found.
    ///
    /// - parameter format: The desired image format for the completion result.
    ///
    /// - parameter completion: A completion handler called when the image is
    /// available in the desired format, or if the request failed. The
    /// completion handler will always be performed on the main queue.
    ///
    /// - returns: A callback mode indicating whether the completion handler was
    /// executed synchronously before the return, or will be executed
    /// asynchronously at some point in the future. When asynchronous, the
    /// cancellation block associated value of the `.async` mode can be used to
    /// cancel the request for this image. Cancelling a request will not cancel
    /// any other in-flight requests. If the cancelled request was the only
    /// remaining request awaiting the result of a downloading or formatting
    /// task, then the unneeded task will be cancelled and any in-progress work
    /// will be abandoned.
    @discardableResult
    public func image(from url: URL, format: Format = .original, completion: @escaping (Image?) -> Void) -> CallbackMode {
        let key = ImageKey(url: url, format: format)
        return image(for: key, completion: completion)
    }

    /// Removes all the cached images from the in-memory cache only. Files on
    /// disk will not be removed.
    public func removeAllImagesFromMemory() {
        memoryCache.removeAll()
    }

    /// Removes and recreates the directory containing all cached image files.
    /// Images cached in-memory will not be removed.
    public func removeAllFilesFromDisk() {
        _ = try? FileManager.default.removeItem(at: directory)
        _ = FileManager.default.createDirectory(at: directory)
    }

    /// Convenience function for storing user-provided images in memory.
    ///
    /// - parameter image: The image to be added. ImageCache will not apply any
    /// formatting to this image, instead treating it as a source image.
    ///
    /// - parameter destinations: Where the image should be saved.
    ///
    /// - parameter key: A developer-provided key uniquely identifying this
    /// image. This key should be as unique as a URL to a remote image might be.
    public func add(userProvidedImage image: Image, to destinations: [UserProvidedImageDestination] = UserProvidedImageDestination.allCases, key: String) {
        guard let actualKey = self.actualKey(forUserProvidedKey: key, format: .original) else { return }
        onMain {
            if destinations.contains(.memory) {
                self.memoryCache[actualKey] = image
            }
            guard destinations.contains(.disk) else { return }
            var saveOperation: Operation?
            _ = self.userImageDiskTaskRegistry.addRequest(
                taskId: actualKey,
                workQueue: self.formattingQueue,
                taskExecution: { finish in
                    let blockOperation = BlockOperation {
                        let url = self.fileUrl(forOriginalImageWithKey: actualKey)
                        FileManager.default.save(image, to: url)
                    }
                    saveOperation = blockOperation
                    self.formattingQueue.addOperation(blockOperation)
                }, taskCancellation: {
                    saveOperation?.cancel()
                }, taskCompletion: {
                    // no-op
                }, requestCompletion: {
                    // no-op
                }
            )
        }
    }

    /// An alternative to `image(from:format:completion:)` that sources from an
    /// existing user-provided source image.
    ///
    /// This method will resolve to a `nil` image if the image has not already
    /// been added via `add(userProvidedImage:to:key:)`
    @discardableResult
    public func userProvidedImage(originalImageKey key: String, format: Format = .original, completion: @escaping (Image?) -> Void) -> CallbackMode {
        guard let actualKey = self.actualKey(forUserProvidedKey: key, format: format) else {
            completion(nil)
            return .sync
        }
        return image(for: actualKey, completion: completion)
    }

    // MARK: Private Methods

    private func image(for key: ImageKey, completion: @escaping (Image?) -> Void) -> CallbackMode {

        let task = BackgroundTask.start()
        let completion: (Image?) -> Void = {
            completion($0)
            task?.end()
        }

        if let image = memoryCache[key] {
            completion(image)
            return .sync
        }

        // Use a deferred value for `formattingRequestId` so that we can capture
        // a future reference to the formatting request ID. This will allow us
        // to cancel the request whether it's in the downloading or formatting
        // step at the time the user executes the cancellation block. The same
        // approach applies to the download request.

        let formattingRequestId = DeferredValue<UUID>()
        let downloadRequestId = DeferredValue<UUID>()

        checkForFormattedImage(key: key) { [weak self] cachedImage in
            guard let this = self else { completion(nil); return }
            if let image = cachedImage {
                this.memoryCache[key] = image
                completion(image)
            } else {
                downloadRequestId.value = this.downloadFile(for: key) { [weak this] downloadResult in
                    guard let this = this else { completion(nil); return }
                    guard let downloadResult = downloadResult else { completion(nil); return }
                    // `this.formatImage` is asynchronous, but returns a request ID
                    // synchronously which can be used to cancel the formatting request.
                    formattingRequestId.value = this.formatImage(
                        key: key,
                        result: downloadResult,
                        completion: completion
                    )
                }
            }
        }

        return .async(cancellation: { [weak self] in
            defer { task?.end() }
            guard let this = self else { return }
            if let id = formattingRequestId.value {
                this.formattingTaskRegistry.cancelRequest(withId: id)
            }
            if let id = downloadRequestId.value {
                this.downloadTaskRegistry.cancelRequest(withId: id)
            }
        })
    }

    /// Returns the underlying ImageKey used for a user-provided key.
    private func actualKey(forUserProvidedKey key: String, format: Format) -> ImageKey? {
        guard let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil}
        guard let url = URL(string: "imagecache://\(encoded)") else { return nil}
        return ImageKey(url: url, format: format)
    }

    /// Returns the original string used for a user-provided key.
    private func userProvidedString(forKey key: ImageKey) -> String? {
        let absolute = key.url.absoluteString
        let prefix = "imagecache://"
        guard absolute.hasPrefix(prefix) else { return nil }
        let encoded = absolute.replacingOccurrences(of: prefix, with: "")
        return encoded.removingPercentEncoding
    }

    /// Adds a request for formatting a downloaded image. If this request is the
    /// first for this format, it will create a task for that format. Otherwise
    /// it will be appended to the existing task. Upon completion of the task,
    /// the formatted image will be inserted into the in-memory cache.
    ///
    /// If an image in the requested format already exists on disk, then the
    /// the request(s) will be fulfilled with that existing image.
    ///
    /// - parameter key: The key to use when caching the image.
    ///
    /// - parameter result: The result of a previous download phase. Contains
    /// either a previously-downloaded image, a local URL to a freshly-
    /// downloaded image file.
    ///
    /// - parameter completion: A block performed on the main queue when the
    /// requested is fulfilled, or when the underlying task fails for one reason
    /// or another.
    ///
    /// - returns: Returns an ID for the request. This ID can be used to later
    /// cancel the request if needed.
    private func formatImage(key: ImageKey, result: DownloadResult, completion: @escaping (Image?) -> Void) -> UUID {
        var operation: Operation?
        return formattingTaskRegistry.addRequest(
            taskId: key,
            workQueue: workQueue,
            taskExecution: { [weak self] finish in
                guard let this = self else { finish(nil); return }
                let destination = this.fileUrl(forFormattedImageWithKey: key)
                if let image = FileManager.default.image(fromFileAt: destination) {
                    finish(image)
                } else {
                    let blockOperation = BlockOperation {
                        let image = key.format.image(from: result)
                        if let image = image {
                            FileManager.default.save(image, to: destination)
                        }
                        finish(image)
                    }
                    operation = blockOperation
                    this.formattingQueue.addOperation(blockOperation)
                }
            },
            taskCancellation: {
                operation?.cancel()
            },
            taskCompletion: { [weak self] result in
                result.map { self?.memoryCache[key] = $0 }
            },
            requestCompletion: completion
        )
    }

    /// Adds a request for downloading an image.
    ///
    /// If the original image is found already on disk, then the image will be
    /// instantiated from the data on disk. Otherwise, the image will be
    /// downloaded and moved to the expected location on disk, and the resulting
    /// file URL will be returned to the caller via the completion block.
    ///
    /// - parameter url: The HTTP URL at which the original image is found.
    ///
    /// - parameter completion: A block performed on the main queue when the
    /// image file is found, or if the request fails.
    ///
    /// - returns: Returns an ID for the request. This ID can be used to later
    /// cancel the request if needed.
    private func downloadFile(for key: ImageKey, completion: @escaping (DownloadResult?) -> Void) -> UUID {
        let destination = fileUrl(forOriginalImageWithKey: key)
        let taskValue = DeferredValue<URLSessionDownloadTask>()
        return downloadTaskRegistry.addRequest(
            taskId: key,
            workQueue: workQueue,
            taskExecution: { finish in
                if FileManager.default.fileExists(at: destination), let image = Image.fromFile(at: destination) {
                    finish(.previous(image))
                } else if self.userProvidedString(forKey: key) != nil {
                    finish(nil)
                } else {
                    taskValue.value = self.urlSession.downloadTask(with: key.url) { (temp, _, _) in
                        if let temp = temp, let _ = try? FileManager.default.moveFile(from: temp, to: destination) {
                            finish(.fresh(destination))
                        } else {
                            finish(nil)
                        }
                    }
                    taskValue.value?.resume()
                }
        },
            taskCancellation: { taskValue.value?.cancel() },
            taskCompletion: { _ in },
            requestCompletion: completion
        )
    }

    /// Checks if an existing image of a given format already exists on disk.
    ///
    /// - parameter key: The key used when caching the formatted image.
    ///
    /// - parameter completion: A block performed with the result, called upon
    /// the main queue. If found, the image is decompressed on a background
    /// queue to avoid doing so on the main queue.
    private func checkForFormattedImage(key: ImageKey, completion: @escaping (Image?) -> Void) {
        deferred(on: workQueue) {
            let image: Image? = {
                let destination = self.fileUrl(forFormattedImageWithKey: key)
                guard let data = try? Data(contentsOf: destination) else { return nil }
                guard let image = Image(data: data) else { return nil }
                return ImageDrawing.decompress(image)
            }()
            onMain {
                completion(image)
            }
        }
    }

    private func fileUrl(forOriginalImageWithKey key: ImageKey) -> URL {
        let originalKey = ImageKey(url: key.url, format: .original)
        let filename = uniqueFilenameFromUrl(key.url) + originalKey.filenameSuffix
        return directory.appendingPathComponent(filename, isDirectory: false)
    }

    private func fileUrl(forFormattedImageWithKey key: ImageKey) -> URL {
        let filename = uniqueFilenameFromUrl(key.url) + key.filenameSuffix
        return directory.appendingPathComponent(filename, isDirectory: false)
    }

    private func registerObservers() {
        #if os(iOS)
            observers.append(NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.trimStaleFiles()
            }))
        #endif
    }

    private func trimStaleFiles() {
        guard let byteLimit = byteLimitForFileStorage else { return }
        let task = BackgroundTask.start()
        DispatchQueue.global().async {
            FileManager.default.removeFilesByDate(
                inDirectory: self.directory,
                untilWithinByteLimit: byteLimit
            )
            task?.end()
        }
    }

}

//------------------------------------------------------------------------------
// MARK: - Typealiases
//------------------------------------------------------------------------------

extension ImageCache {

    // MARK: Typealiases (All)

    public typealias Bytes = UInt

    // MARK: Typealiases (iOS)

    #if os(iOS)
    public typealias Image = UIImage
    public typealias Color = UIColor
    #endif

    // MARK: Typealiases (macOS)

    #if os(OSX)
    public typealias Image = NSImage
    public typealias Color = NSColor
    #endif

}

private typealias Image = ImageCache.Image
private typealias Color = ImageCache.Color

//------------------------------------------------------------------------------
// MARK: - User-Provided Image Destinations
//------------------------------------------------------------------------------

extension ImageCache {

    public enum UserProvidedImageDestination: CaseIterable {
        case memory, disk
    }

}

//------------------------------------------------------------------------------
// MARK: - Bytes (Convenience)
//------------------------------------------------------------------------------

extension ImageCache.Bytes {

    public static func fromMegabytes(_ number: UInt) -> UInt {
        return number * 1_000_000
    }

}

//------------------------------------------------------------------------------
// MARK: - CallbackMode
//------------------------------------------------------------------------------

extension ImageCache {

    /// The manner in which a completion handler is (or will be) executed.
    ///
    /// Indicates whether a completion handler was executed synchronously before
    /// the return, or will be executed asynchronously at some point in the
    /// future. When asynchronous, the cancellation block associated value of
    /// the `.async` mode can be used to cancel the pending request.
    public enum CallbackMode {

        /// The completion handler was performed synchronously, before the
        /// method returned.
        case sync

        /// The completion handler will be performed asynchronously, sometime
        /// after the method returned.
        ///
        /// - parameter cancellation: A block which the caller can use to cancel
        /// the in-flight request.
        case async(cancellation: () -> Void)
    }

}

//------------------------------------------------------------------------------
// MARK: - Format
//------------------------------------------------------------------------------

extension ImageCache {

    /// Describes the format options to be used when processing a source image.
    public enum Format: Hashable {

        // MARK: Typealiases

        /// Use `0` to default to the system-determined default.
        public typealias ContentScale = CGFloat

        // MARK: Formats

        /// Do not modify the source image in any way.
        case original

        /// Scale the source image, with a variety of options.
        ///
        /// - parameter size: The desired output size, in points.
        ///
        /// - parameter mode: The manner in which the image will be scaled
        /// relative to the desired output size.
        ///
        /// - parameter bleed: The number of points, relative to `size`, that
        /// the image should be scaled beyond the desired output size.
        /// Generally, you should provide a value of `0` since this isn't a
        /// commonly-used feature. However, you might want to use a value larger
        /// than `0` if the source image has known artifacts (like, say, a one-
        /// pixel border around some podcast artwork) which can be corrected by
        /// drawing the image slightly larger than the output size, thus
        /// cropping the border from the result.
        ///
        /// - parameter opaque: If `false`, opacity in the source image will be
        /// preserved. If `true`, any opacity in the source image will be
        /// blended into the default (black) bitmap content.
        ///
        /// - parameter cornerRadius: If this value is greater than `0`, the
        /// image will be drawn with the corners rounded by an equivalent number
        /// of points (relative to `size`). A value of `0` or less will disable
        /// this feature.
        ///
        /// - parameter border: If non-nil, the resulting image will include the
        /// requested border drawn around the perimeter of the image.
        ///
        /// - parameter contentScale: The number of pixels per point, which is
        /// used to reckon the output image size relative to the requested
        /// `size`. Pass `0` to use the native defaults for the current device.
        case scaled(size: CGSize, mode: ContentMode, bleed: CGFloat, opaque: Bool, cornerRadius: CGFloat, border: Border?, contentScale: ContentScale)

        /// Scale the source image and crop it to an elliptical shape. The
        /// resulting image will have transparent contents in the corners.
        ///
        /// - parameter size: The desired output size, in points.
        ///
        /// - parameter border: If non-nil, the resulting image will include the
        /// requested border drawn around the perimeter of the image.
        ///
        /// - parameter contentScale: The number of pixels per point, which is
        /// used to reckon the output image size relative to the requested
        /// `size`. Pass `0` to use the native defaults for the current device.
        case round(size: CGSize, border: Border?, contentScale: ContentScale)

        /// Draw the source image using a developer-supplied formatting block.
        ///
        /// - parameter editKey: A key uniquely identifying the formatting
        /// strategy used by `block`. This key is **not** specific to any
        /// particular image, but is instead common to all images drawn with
        /// this format. ImageCache will combine the edit key with other unique
        /// parameters when caching an image drawn with a custom format.
        ///
        /// - parameter block: A developer-supplied formatting block which
        /// accepts the unmodified source image as input and returns a formatted
        /// image. The developer does not need to cache the returned image.
        /// ImageCache will cache the result in the same manner as images drawn
        /// using the other formats.
        case custom(editKey: String, block: (ImageCache.Image) -> ImageCache.Image)

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .original:
                hasher.combine(".original")
            case let .scaled(size, mode, bleed, opaque, cornerRadius, border, contentScale):
                hasher.combine(".scaled")
                hasher.combine(size.width)
                hasher.combine(size.height)
                hasher.combine(mode)
                hasher.combine(bleed)
                hasher.combine(opaque)
                hasher.combine(cornerRadius)
                hasher.combine(border)
                hasher.combine(contentScale)
            case let .round(size, border, contentScale):
                hasher.combine(".round")
                hasher.combine(size.width)
                hasher.combine(size.height)
                hasher.combine(border)
                hasher.combine(contentScale)
            case .custom(let key, _):
                hasher.combine(".original")
                hasher.combine(key)
            }
        }

        public static func == (lhs: Format, rhs: Format) -> Bool {
            switch (lhs, rhs) {
            case (.original, .original):
                return true
            case let (.scaled(ls, lm, lbl, lo, lc, lb, lcs), .scaled(rs, rm, rbl, ro, rc, rb, rcs)):
                return ls == rs && lm == rm && lbl == rbl && lo == ro && lc == rc && lb == rb && lcs == rcs
            case let (.round(ls, lb, lc), .round(rs, rb, rc)):
                return ls == rs && lb == rb && lc == rc
            case let (.custom(left, _), .custom(right, _)):
                return left == right
            default:
                return false
            }
        }

        fileprivate func image(from result: DownloadResult) -> Image? {
            switch result {
            case .fresh(let url):
                guard let image = Image.fromFile(at: url) else { return nil }
                return ImageDrawing.draw(image, format: self)
            case .previous(let image):
                return ImageDrawing.draw(image, format: self)
            }
        }

    }

}

//------------------------------------------------------------------------------
// MARK: - ContentMode
//------------------------------------------------------------------------------

extension ImageCache.Format {

    /// Platform-agnostic analogue to UIView.ContentMode
    public enum ContentMode {

        /// Contents scaled to fill with fixed aspect ratio. Some portion of
        /// the content may be clipped.
        case scaleAspectFill

        /// Contents scaled to fit with fixed aspect ratio. The remainder of
        /// the resulting image area will be either transparent or black,
        /// depending upon the requested `opaque` value.
        case scaleAspectFit
    }

}

//------------------------------------------------------------------------------
// MARK: - Border
//------------------------------------------------------------------------------

extension ImageCache.Format {

    /// Border styles you can use when drawing a scaled or round image format.
    public enum Border: Hashable {

        case hairline(ImageCache.Color)

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .hairline(let color):
                hasher.combine(".hairline")
                hasher.combine(color)
            }
        }

        public static func == (lhs: Border, rhs: Border) -> Bool {
            switch (lhs, rhs) {
            case let (.hairline(left), .hairline(right)): return left == right
            }
        }

        #if os(iOS)
        fileprivate func draw(around path: UIBezierPath) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            switch self {
            case .hairline(let color):
                context.setStrokeColor(color.cgColor)
                let perceivedWidth: CGFloat = 1.0 // In the units of the context!
                let actualWidth = perceivedWidth * 2.0 // Half'll be cropped
                context.setLineWidth(actualWidth) // it's centered
                context.addPath(path.cgPath)
                context.strokePath()
            }
        }
        #endif

    }

}

//------------------------------------------------------------------------------
// MARK: - ImageDrawing
//------------------------------------------------------------------------------

/// Utility for drawing an image according to a specified format.
///
/// - Note: This is public since it may be useful outside this file.
public enum /*scope*/ ImageDrawing {

    // MARK: Common

    /// Draws `image` using the specified format.
    ///
    /// - returns: Returns the formatted image.
    public static func draw(_ image: ImageCache.Image, format: ImageCache.Format) -> ImageCache.Image {
        switch format {
        case .original:
            return decompress(image)
        case let .scaled(size, mode, bleed, opaque, cornerRadius, border, contentScale):
            return draw(image, at: size, using: mode, bleed: bleed, opaque: opaque, cornerRadius: cornerRadius, border: border, contentScale: contentScale)
        case let .round(size, border, contentScale):
            return draw(image, clippedByOvalOfSize: size, border: border, contentScale: contentScale)
        case .custom(_, let block):
            return block(image)
        }
    }

    // MARK: macOS

    #if os(OSX)
    fileprivate static func decompress(_ image: Image) -> Image {
        // Not yet implemented.
        return image
    }

    private static func draw(_ image: Image, at targetSize: CGSize, using mode: ImageCache.Format.ContentMode, opaque: Bool, cornerRadius: CGFloat, border: ImageBorder?, contentScale: CGFloat) -> Image {
        // Not yet implemented.
        return image
    }

    private static func draw(_ image: Image, clippedByOvalOfSize targetSize: CGSize, border: ImageCache.Format.Border?, contentScale: CGFloat) -> Image {
        // Not yet implemented.
        return image
    }
    #endif

    // MARK: iOS

    #if os(iOS)
    fileprivate static func decompress(_ image: Image) -> Image {
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1)) // Size doesn't matter.
        defer { UIGraphicsEndImageContext() }
        image.draw(at: CGPoint.zero)
        return image
    }

    private static func draw(_ image: Image, at targetSize: CGSize, using mode: ImageCache.Format.ContentMode, bleed: CGFloat, opaque: Bool, cornerRadius: CGFloat, border: ImageCache.Format.Border?, contentScale: CGFloat) -> Image {
        guard !image.size.equalTo(.zero) else { return image }
        guard !targetSize.equalTo(.zero) else { return image }
        switch mode {
        case .scaleAspectFill, .scaleAspectFit:
            var scaledSize: CGSize
            if mode == .scaleAspectFit {
                scaledSize = image.sizeThatFits(targetSize)
            } else {
                scaledSize = image.sizeThatFills(targetSize)
            }
            if bleed != 0 {
                scaledSize.width += bleed * 2
                scaledSize.height += bleed * 2
            }
            let x = (targetSize.width - scaledSize.width) / 2.0
            let y = (targetSize.height - scaledSize.height) / 2.0
            let drawingRect = CGRect(x: x, y: y, width: scaledSize.width, height: scaledSize.height)
            UIGraphicsBeginImageContextWithOptions(targetSize, opaque, contentScale)
            defer { UIGraphicsEndImageContext() }
            if cornerRadius > 0 || border != nil {
                let clipRect = CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
                let bezPath = UIBezierPath(roundedRect: clipRect, cornerRadius: cornerRadius)
                bezPath.addClip()
                image.draw(in: drawingRect)
                border?.draw(around: bezPath)
            } else {
                image.draw(in: drawingRect)
            }
            return UIGraphicsGetImageFromCurrentImageContext() ?? image
        }
    }

    private static func draw(_ image: Image, clippedByOvalOfSize targetSize: CGSize, border: ImageCache.Format.Border?, contentScale: CGFloat) -> Image {
        guard !image.size.equalTo(.zero) else { return image }
        guard !targetSize.equalTo(.zero) else { return image }
        let scaledSize = image.sizeThatFills(targetSize)
        let x = (targetSize.width - scaledSize.width) / 2.0
        let y = (targetSize.height - scaledSize.height) / 2.0
        let drawingRect = CGRect(x: x, y: y, width: scaledSize.width, height: scaledSize.height)
        let clipRect = CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0)
        defer { UIGraphicsEndImageContext() }
        let bezPath = UIBezierPath(ovalIn: clipRect)
        bezPath.addClip()
        image.draw(in: drawingRect)
        border?.draw(around: bezPath)
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    #endif

}

//------------------------------------------------------------------------------
// MARK: - ImageKey
//------------------------------------------------------------------------------

/// Uniquely identifies a particular format of an image from a particular URL.
private class ImageKey: Hashable {

    /// The HTTP URL to the original image from which the cached image was derived.
    let url: URL

    /// The format used when processing the cached image.
    let format: ImageCache.Format

    init(url: URL, format: ImageCache.Format) {
        self.url = url
        self.format = format
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(format)
    }

    var filenameSuffix: String {
        switch format {
        case .original:
            return "_original"
        case let .scaled(size, mode, bleed, opaque, radius, border, contentScale):
            let base = "_scaled_\(Int(size.width))_\(Int(size.height))_\(mode)_\(Int(bleed))_\(opaque)_\(Int(radius))_\(Int(contentScale))"
            if let border = border, case .hairline(let color) = border {
                return base + "_hairline(\(color))"
            } else {
                return base + "_nil"
            }
        case let .round(size, border, contentScale):
            let base = "_round_\(Int(size.width))_\(Int(size.height))"
            if let border = border, case .hairline(let color) = border {
                return base + "_hairline(\(color))" + "_\(Int(contentScale))"
            } else {
                return base + "_nil"
            }
        case let .custom(key, _):
            return "_custom_\(key)"
        }
    }

    static func == (lhs: ImageKey, rhs: ImageKey) -> Bool {
        return lhs.url == rhs.url && lhs.format == rhs.format
    }

}

//------------------------------------------------------------------------------
// MARK: - DownloadResult
//------------------------------------------------------------------------------

/// Communicates to `ImageCache` whether the result of a download operation was
/// that a new file was freshly downloaded, or whether a previously-downloaded
/// file was able to be used.
private enum DownloadResult {

    /// A fresh file was downloaded and is available locally at a file URL.
    case fresh(URL)

    /// A previously-downloaded image was already available on disk.
    case previous(Image)

}

//------------------------------------------------------------------------------
// MARK: - MemoryCache
//------------------------------------------------------------------------------

private class MemoryCache<Key: Hashable, Value> {

    var shouldRemoveAllObjectsWhenAppEntersBackground = false

    private var items = ProtectedDictionary<Key, Value>()
    private var observers = [NSObjectProtocol]()

    subscript(key: Key) -> Value? {
        get { return items[key] }
        set { items[key] = newValue }
    }

    subscript(filter: (Key) -> Bool) -> [Key: Value] {
        return items.access {
            $0.filter { filter($0.key) }
        }
    }

    init() {
        #if os(iOS)
            observers.append(NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.removeAll()
            }))
            observers.append(NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    guard let this = self else { return }
                    if this.shouldRemoveAllObjectsWhenAppEntersBackground {
                        this.removeAll()
                    }
            }))
        #endif
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func removeAll() {
        items.access { $0.removeAll() }
    }

}

//------------------------------------------------------------------------------
// MARK: - DeferredValue
//------------------------------------------------------------------------------

private class DeferredValue<T> {
    var value: T?
}

//------------------------------------------------------------------------------
// MARK: - TaskRegistry
//------------------------------------------------------------------------------

private class TaskRegistry<TaskID: Hashable, Result> {

    typealias RequestID = UUID
    typealias Finish = (Result) -> Void
    typealias TaskType = Task<TaskID, Result>
    typealias RequestType = Request<Result>

    private var protectedTasks = Protected<[TaskID: TaskType]>([:])

    func addRequest(taskId: TaskID, workQueue: OperationQueue, taskExecution: @escaping (@escaping Finish) -> Void, taskCancellation: @escaping () -> Void, taskCompletion: @escaping TaskType.Completion, requestCompletion: @escaping RequestType.Completion) -> RequestID {
        let request = RequestType(completion: requestCompletion)
        protectedTasks.access { tasks in
            if var task = tasks[taskId] {
                task.requests[request.id] = request
                tasks[taskId] = task
            } else {
                var task = Task<TaskID, Result>(
                    id: taskId,
                    cancellation: taskCancellation,
                    completion: taskCompletion
                )
                task.requests[request.id] = request
                tasks[taskId] = task
                let finish: Finish = { [weak self] result in
                    onMain { self?.finishTask(withId: taskId, result: result) }
                }
                // `deferred(on:block:)` will dispatch to next main runloop then
                // from there dispatch to a global queue, ensuring that the
                // completion block cannot be executed before this method returns.
                deferred(on: workQueue) { taskExecution(finish) }
            }
        }
        return request.id
    }

    func cancelRequest(withId id: RequestID) {
        let taskCancellation: TaskType.Cancellation? = protectedTasks.access { tasks in
            guard var (_, task) = tasks.first(where: { $0.value.requests[id] != nil }) else { return nil }
            task.requests[id] = nil
            let shouldCancelTask = task.requests.isEmpty
            if shouldCancelTask {
                tasks[task.id] = nil
                return task.cancellation
            } else {
                tasks[task.id] = task
                return nil
            }
        }
        taskCancellation?()
    }

    private func finishTask(withId id: TaskID, result: Result) {
        let (taskCompletion, requestCompletions): (TaskType.Completion?, [RequestType.Completion]?) = protectedTasks.access { tasks in
            let task = tasks[id]
            tasks[id] = nil
            return (task?.completion, task?.requests.values.map { $0.completion })
        }
        // Per my standard habit, completion handlers are always performed on
        // the main queue.
        if let completion = taskCompletion {
            onMain { completion(result) }
        }
        if let completions = requestCompletions {
            onMain {
                completions.forEach { $0(result) }
            }
        }
    }

}

//------------------------------------------------------------------------------
// MARK: - Task
//------------------------------------------------------------------------------

private struct Task<TaskID: Hashable, Result> {

    typealias Cancellation = () -> Void
    typealias Completion = (Result) -> Void

    var requests = [UUID: Request<Result>]()
    let id: TaskID
    let cancellation: Cancellation
    let completion: Completion

    init(id: TaskID, cancellation: @escaping Cancellation, completion: @escaping Completion) {
        self.id = id
        self.cancellation = cancellation
        self.completion = completion
    }

}

//------------------------------------------------------------------------------
// MARK: - Request
//------------------------------------------------------------------------------

private struct Request<Result> {
    typealias Completion = (Result) -> Void

    let id = UUID()
    let completion: Completion
}

//------------------------------------------------------------------------------
// MARK: - URL (Convenience)
//------------------------------------------------------------------------------

extension URL {

    fileprivate func subdirectory(named name: String) -> URL {
        return appendingPathComponent(name, isDirectory: true)
    }

}

//------------------------------------------------------------------------------
// MARK: - FileManager (Convenience)
//------------------------------------------------------------------------------

extension FileManager {

    fileprivate func image(fromFileAt url: URL) -> Image? {
        if let data = try? Data(contentsOf: url) {
            return Image(data: data)
        } else {
            return nil
        }
    }

    fileprivate func save(_ image: Image, to url: URL) {
        #if os(iOS)
            guard let data = image.pngData() else { return }
        #elseif os(OSX)
            guard let data = image.tiffRepresentation else { return }
        #endif
        do {
            if fileExists(at: url) {
                try removeItem(at: url)
            }
            try data.write(to: url, options: .atomic)
        } catch {}
    }

}

//------------------------------------------------------------------------------
// MARK: - Image (Convenience)
//------------------------------------------------------------------------------

extension Image {

    #if os(iOS)
    fileprivate static func fromFile(at url: URL) -> Image? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return Image(data: data)
    }
    #endif

    fileprivate func sizeThatFills(_ other: CGSize) -> CGSize {
        guard !size.equalTo(.zero) else { return other }
        let h = size.height
        let w = size.width
        let heightRatio = other.height / h
        let widthRatio = other.width / w
        if heightRatio > widthRatio {
            return CGSize(width: w * heightRatio, height: h * heightRatio)
        } else {
            return CGSize(width: w * widthRatio, height: h * widthRatio)
        }
    }

    fileprivate func sizeThatFits(_ other: CGSize) -> CGSize {
        guard !size.equalTo(.zero) else { return other }
        let h = size.height
        let w = size.width
        let heightRatio = other.height / h
        let widthRatio = other.width / w
        if heightRatio > widthRatio {
            return CGSize(width: w * widthRatio, height: h * widthRatio)
        } else {
            return CGSize(width: w * heightRatio, height: h * heightRatio)
        }
    }

}

//------------------------------------------------------------------------------
// MARK: - GCD (Convenience)
//------------------------------------------------------------------------------

private func onMain(_ block: @escaping () -> Void) {
    DispatchQueue.main.async { block() }
}

private func deferred(on queue: OperationQueue, block: @escaping () -> Void) {
    onMain { queue.addOperation(block) }
}

//------------------------------------------------------------------------------
// MARK: - Error (Convenience)
//------------------------------------------------------------------------------

private func didntThrow(_ block: () throws -> Void) -> Bool {
    do { try block(); return true } catch { return false }
}
