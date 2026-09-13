import Foundation

/// Copies bundled geo databases into the shared working directory for sing-box routing.
enum GeoAssets {
    private static let geoFiles = ["geoip.dat", "geosite.dat"]
    private static let minGeoBytes: Int64 = 1024

    static func assetDirectory(in baseDir: URL) -> URL {
        baseDir
            .appendingPathComponent("working", isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
    }

    static func ensureCopied(to baseDir: URL) {
        let destDir = assetDirectory(in: baseDir)
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        for name in geoFiles {
            let dest = destDir.appendingPathComponent(name)
            if isValidGeoFile(at: dest) {
                continue
            }
            if let src = findBundledResource(name: name) {
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.copyItem(at: src, to: dest)
            }
        }
    }

    static func areReady(in baseDir: URL) -> Bool {
        let dir = assetDirectory(in: baseDir)
        return geoFiles.allSatisfy { isValidGeoFile(at: dir.appendingPathComponent($0)) }
    }

    private static func isValidGeoFile(at url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else {
            return false
        }
        return size.int64Value >= minGeoBytes
    }

    private static func findBundledResource(name: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "geo") {
            return url
        }
        return Bundle.main.url(forResource: name, withExtension: nil)
    }
}
