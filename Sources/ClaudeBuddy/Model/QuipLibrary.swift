import Foundation

enum QuipCategory: String, CaseIterable {
    case greeting
    case idle
    case working
    case done
    case sleepy
}

/// Lines the buddy says. Ships with defaults and reloads from
/// `~/Library/Application Support/ClaudeBuddy/quips.json` whenever that file
/// changes, so editing it takes effect without restarting.
final class QuipLibrary {
    static let shared = QuipLibrary()

    private var quips: [String: [String]] = QuipLibrary.defaults
    private var lastModified: Date?
    private var lastSpoken: [String: String] = [:]

    static let defaults: [String: [String]] = [
        QuipCategory.greeting.rawValue: [
            "hi! i live here now",
            "hello :)",
            "reporting for desktop duty",
            "oh hey, you're back"
        ],
        QuipCategory.idle.rawValue: [
            "just vibing",
            "want me to move? drag me anywhere",
            "i like this wallpaper",
            "psst. take a break maybe?",
            "i'm not doing anything important",
            "have you had water today?",
            "nice folder organization. very brave",
            "i'll be right here"
        ],
        QuipCategory.working.rawValue: [
            "ooh, we're coding",
            "let's build something",
            "i'll keep watch",
            "go go go"
        ],
        QuipCategory.done.rawValue: [
            "nice work!",
            "shipped it",
            "that's a wrap",
            "well done, human"
        ],
        QuipCategory.sleepy.rawValue: [
            "mmf... i'm up, i'm up",
            "oh! hi. i wasn't sleeping",
            "*yawn*"
        ]
    ]

    var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ClaudeBuddy/quips.json")
    }

    /// A random line, avoiding an immediate repeat within the same category.
    func random(_ category: QuipCategory) -> String {
        reloadIfChanged()
        let pool = quips[category.rawValue] ?? QuipLibrary.defaults[category.rawValue] ?? []
        guard !pool.isEmpty else { return "..." }
        let previous = lastSpoken[category.rawValue]
        let candidates = pool.count > 1 ? pool.filter { $0 != previous } : pool
        let choice = candidates.randomElement() ?? pool[0]
        lastSpoken[category.rawValue] = choice
        return choice
    }

    /// Creates the file with the built-in lines if it does not exist yet.
    @discardableResult
    func ensureFileExists() -> URL {
        let url = fileURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return url }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(QuipLibrary.defaults) {
            try? data.write(to: url)
        }
        return url
    }

    private func reloadIfChanged() {
        let url = fileURL
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date else { return }
        guard modified != lastModified else { return }
        lastModified = modified

        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else { return }

        // Keep built-in lines for any category the user removed entirely.
        var merged = QuipLibrary.defaults
        for (key, value) in decoded where !value.isEmpty {
            merged[key] = value
        }
        quips = merged
    }
}
