import AppKit
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

enum WallpaperUpdate {
    static func outputURL(root: URL, key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent("wallpaper-v14-\(digest).png")
    }
    static func needsApplication(expected: URL, actual: [URL?]) -> Bool {
        actual.isEmpty || actual.contains { $0?.standardizedFileURL != expected.standardizedFileURL }
    }
    static func ownsFilename(_ name: String) -> Bool {
        name == "wallpaper.png" || name.range(of: "^wallpaper-[0-9]{4}-[0-9]{2}-[0-9]{2}\\.png$", options: .regularExpression) != nil || name.range(of: "^wallpaper-v14-[a-f0-9]{64}\\.png$", options: .regularExpression) != nil
    }
    // Includes mixed collections: never remove an image that any system entry still references.
    static func referencedFiles(in data: Data, root: URL) throws -> Set<String> {
        var names = Set<String>()
        func visit(_ value: Any) {
            if let dict = value as? [String: Any] { dict.values.forEach(visit) }
            else if let array = value as? [Any] { array.forEach(visit) }
            else if let bytes = value as? Data, let nested = try? PropertyListSerialization.propertyList(from: bytes, format: nil) { visit(nested) }
            else if let text = value as? String, let url = URL(string: text), url.isFileURL,
                    url.deletingLastPathComponent().standardizedFileURL.path == root.standardizedFileURL.path,
                    ownsFilename(url.lastPathComponent) { names.insert(url.lastPathComponent) }
        }
        visit(try PropertyListSerialization.propertyList(from: data, format: nil))
        return names
    }
}

// Shared, side-effect-free logic used by the app, worker, and tests.
enum LifeDays {
    static func count(start: Date, today: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: today)).day! + 1
    }
}
enum ImageImport {
    static func normalizedImage(at url: URL) throws -> Data {
        func invalid(_ message: String) -> NSError { NSError(domain: "DayWallpaper", code: 5, userInfo: [NSLocalizedDescriptionKey: message]) }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let bytes = values.fileSize, bytes > 0, bytes <= 50 * 1024 * 1024 else { throw invalid("请选择不超过 50 MB 的图片文件。") }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.intValue > 0, height.intValue > 0,
              width.doubleValue * height.doubleValue <= 80_000_000 else { throw invalid("图片无法读取，或超过 8000 万像素。") }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 6240, kCGImageSourceShouldCacheImmediately: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw invalid("图片解码失败。请选择 JPEG、PNG、HEIC 或 TIFF 图片。") }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { throw invalid("图片转换失败。") }
        // Re-encode pixels only: omit source location and EXIF metadata.
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw invalid("图片保存失败。") }
        return data as Data
    }
}

func migrateWallpaperStore(_ data: Data, root: URL, output: URL) throws -> Data? {
    var changed = false
    func owns(_ choice: [String: Any]) -> Bool {
        guard let config = choice["Configuration"] as? Data,
              let info = try? PropertyListSerialization.propertyList(from: config, format: nil) as? [String: Any],
              let location = info["url"] as? [String: Any],
              let relative = location["relative"] as? String,
              let url = URL(string: relative), url.isFileURL,
              url.deletingLastPathComponent().standardizedFileURL.path == root.standardizedFileURL.path else { return false }
        return WallpaperUpdate.ownsFilename(url.lastPathComponent)
    }
    func rewrite(_ value: Any) throws -> Any {
        if let array = value as? [Any] { return try array.map(rewrite) }
        guard var dict = value as? [String: Any] else { return value }
        for (key, child) in dict { dict[key] = try rewrite(child) }
        guard var desktop = dict["Desktop"] as? [String: Any],
              var content = desktop["Content"] as? [String: Any],
              let choices = content["Choices"] as? [[String: Any]],
              choices.allSatisfy(owns),
              var choice = choices.first(where: owns) else { return dict }
        let configuration = try PropertyListSerialization.data(fromPropertyList: ["type": "imageFile", "url": ["relative": output.absoluteString]], format: .binary, options: 0)
        let existing = (choice["Configuration"] as? Data).flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
        let existingURL = (existing?["url"] as? [String: Any])?["relative"] as? String
        if choices.count == 1, existing?["type"] as? String == "imageFile", existingURL == output.absoluteString, content["Shuffle"] as? String == "$null" { return dict }
        choice["Configuration"] = configuration
        choice["Files"] = [Any]()
        content["Choices"] = [choice]
        content["Shuffle"] = "$null"
        desktop["Content"] = content
        desktop["LastSet"] = Date()
        dict["Desktop"] = desktop
        if dict["Type"] as? String == "linked" { dict["Type"] = "individual" }
        changed = true
        return dict
    }
    let input = try PropertyListSerialization.propertyList(from: data, format: nil)
    let updated = try rewrite(input)
    return changed ? try PropertyListSerialization.data(fromPropertyList: updated, format: .binary, options: 0) : nil
}
