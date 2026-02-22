import Foundation

enum AppResources {
    private static let moduleBundleName = "FluxTerm_FluxTerm.bundle"

    static let moduleBundle: Bundle? = {
        for candidate in moduleBundleCandidates() {
            if let bundle = Bundle(url: candidate) {
                return bundle
            }
        }
        return nil
    }()

    static var searchBundles: [Bundle] {
        if let moduleBundle {
            return [moduleBundle, .main]
        }
        return [.main]
    }

    static func url(forResource name: String, withExtension ext: String, subdirectory: String? = nil) -> URL? {
        for bundle in searchBundles {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
                return url
            }
        }
        return nil
    }

    private static func moduleBundleCandidates() -> [URL] {
        var candidates: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent(moduleBundleName))
        }

        candidates.append(Bundle.main.bundleURL.appendingPathComponent(moduleBundleName))
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(moduleBundleName)"))

        if let executableURL = Bundle.main.executableURL {
            let executableDir = executableURL.deletingLastPathComponent()
            let contentsDir = executableDir.deletingLastPathComponent()
            candidates.append(executableDir.appendingPathComponent(moduleBundleName))
            candidates.append(contentsDir.appendingPathComponent("Resources/\(moduleBundleName)"))
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        candidates.append(cwd.appendingPathComponent(".build/arm64-apple-macosx/debug/\(moduleBundleName)"))
        candidates.append(cwd.appendingPathComponent(".build/arm64-apple-macosx/release/\(moduleBundleName)"))
        candidates.append(cwd.appendingPathComponent(".build/x86_64-apple-macosx/debug/\(moduleBundleName)"))
        candidates.append(cwd.appendingPathComponent(".build/x86_64-apple-macosx/release/\(moduleBundleName)"))

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.path).inserted }
    }
}
