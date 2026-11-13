import AppKit
import ImageIO
import UniformTypeIdentifiers

let scratch = URL(fileURLWithPath: CommandLine.arguments[1])
var checked = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
    checked += 1
}
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
func date(_ year: Int, _ month: Int, _ day: Int, in cal: Calendar) -> Date {
    cal.date(from: DateComponents(year: year, month: month, day: day))!
}
let first = date(2024, 2, 28, in: calendar)
expect(LifeDays.count(start: first, today: first, calendar: calendar) == 1, "Starting day is day 1")
expect(LifeDays.count(start: first, today: date(2024, 3, 1, in: calendar), calendar: calendar) == 3, "Leap day")
expect(LifeDays.count(start: date(2023, 12, 31, in: calendar), today: date(2024, 1, 1, in: calendar), calendar: calendar) == 2, "Year boundary")
calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
expect(LifeDays.count(start: date(2024, 3, 9, in: calendar), today: date(2024, 3, 11, in: calendar), calendar: calendar) == 3, "Daylight saving boundary")

let space = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(NSColor.red.cgColor)
context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
let fixture = scratch.appendingPathComponent("fixture.jpg")
let destination = CGImageDestinationCreateWithURL(fixture as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 1.0, kCGImagePropertyGPSLatitudeRef: "N"], kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2024:01:01 12:00:00"]] as CFDictionary)
expect(CGImageDestinationFinalize(destination), "Fixture encoding")
let converted = try ImageImport.normalizedImage(at: fixture)
let source = CGImageSourceCreateWithData(converted as CFData, nil)!
let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
expect(props[kCGImagePropertyGPSDictionary] == nil, "GPS removal")
let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
expect(exif?[kCGImagePropertyExifDateTimeOriginal] == nil, "Original capture time removal")
expect((props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue == 64, "Image dimensions preserved")
let invalid = scratch.appendingPathComponent("invalid.jpg")
try Data("not a JPEG".utf8).write(to: invalid)
var rejected = false
 do { _ = try ImageImport.normalizedImage(at: invalid) } catch { rejected = true }
expect(rejected, "Invalid image rejected")
let oversized = scratch.appendingPathComponent("oversized.jpg")
FileManager.default.createFile(atPath: oversized.path, contents: nil)
let handle = try FileHandle(forWritingTo: oversized)
try handle.truncate(atOffset: 51 * 1024 * 1024)
try handle.close()
rejected = false
 do { _ = try ImageImport.normalizedImage(at: oversized) } catch { rejected = true }
expect(rejected, "Oversized file rejected")

let ownedRoot = scratch.appendingPathComponent("Owned")
let output = ownedRoot.appendingPathComponent("wallpaper.png")
func choice(_ url: URL) throws -> [String: Any] {
    ["Provider": "com.apple.wallpaper.choice.image", "Configuration": try PropertyListSerialization.data(fromPropertyList: ["type": "imageFile", "url": ["relative": url.absoluteString]], format: .binary, options: 0)]
}
let owned = try choice(ownedRoot.appendingPathComponent("wallpaper-2024-01-01.png"))
let personal = try choice(scratch.appendingPathComponent("personal.jpg"))
let idle = ["sentinel": "preserve"]
let tree: [String: Any] = ["SystemDefault": ["Desktop": ["Content": ["Choices": [owned], "Shuffle": "enabled"]], "Idle": idle], "Mixed": ["Desktop": ["Content": ["Choices": [owned, personal]]]]]
let original = try PropertyListSerialization.data(fromPropertyList: tree, format: .binary, options: 0)
let migrated = try migrateWallpaperStore(original, root: ownedRoot, output: output)!
let result = try PropertyListSerialization.propertyList(from: migrated, format: nil) as! NSDictionary
let system = result["SystemDefault"] as! NSDictionary
expect((system["Idle"] as! NSDictionary).isEqual(idle), "Screen saver preserved")
expect((result["Mixed"] as! NSDictionary).isEqual(tree["Mixed"]), "Mixed personal collection preserved")
let second = try migrateWallpaperStore(migrated, root: ownedRoot, output: output)
expect(second == nil, "Migration idempotence")
let desktop = system["Desktop"] as! NSDictionary
let content = desktop["Content"] as! NSDictionary
expect(content["Shuffle"] as? String == "$null", "Shuffle disabled")
let choices = content["Choices"] as! [NSDictionary]
let config = try PropertyListSerialization.propertyList(from: choices[0]["Configuration"] as! Data, format: nil) as! NSDictionary
expect((config["url"] as! NSDictionary)["relative"] as? String == output.absoluteString, "Stable wallpaper reference")
let oldKey = "2026-11-10-v14-settings"
let newKey = "2026-11-13-v14-settings"
let oldURL = WallpaperUpdate.outputURL(root: ownedRoot, key: oldKey)
let newURL = WallpaperUpdate.outputURL(root: ownedRoot, key: newKey)
expect(oldURL != newURL, "Day change must invalidate the macOS wallpaper URL cache")
expect(newURL == WallpaperUpdate.outputURL(root: ownedRoot, key: newKey), "Same revision must have a stable URL")
expect(WallpaperUpdate.needsApplication(expected: newURL, actual: [newURL, oldURL]), "A stale second screen must trigger repair even with today's marker")
expect(WallpaperUpdate.needsApplication(expected: newURL, actual: [nil]), "Unavailable wallpaper state must retry")
expect(WallpaperUpdate.needsApplication(expected: newURL, actual: []), "No screens must never count as success")
expect(!WallpaperUpdate.needsApplication(expected: newURL, actual: [newURL, newURL]), "All screens verified can skip rendering")
expect(!WallpaperUpdate.ownsFilename("wallpaper-v14-personal.png"), "Never treat arbitrary personal files as owned")
let versionTree: [String: Any] = ["SystemDefault": ["Desktop": ["Content": ["Choices": [try choice(oldURL)], "Shuffle": "enabled"]], "Idle": idle], "Mixed": ["Desktop": ["Content": ["Choices": [try choice(oldURL), personal]]]]]
let versionData = try PropertyListSerialization.data(fromPropertyList: versionTree, format: .binary, options: 0)
let versionMigrated = try migrateWallpaperStore(versionData, root: ownedRoot, output: newURL)!
let references = try WallpaperUpdate.referencedFiles(in: versionMigrated, root: ownedRoot)
expect(references.contains(newURL.lastPathComponent), "Versioned image references must migrate")
expect(references.contains(oldURL.lastPathComponent), "A mixed collection's still-referenced image must be retained")
expect(LifeDays.count(start: date(2024, 1, 1, in: calendar), today: date(2024, 1, 4, in: calendar), calendar: calendar) == 4, "Three-day catch-up includes the starting day")
print("Passed \(checked) checks: calendar, image validation/privacy, and scoped migration.")
