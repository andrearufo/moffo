import Foundation

/// Plain text diary in ~/Library/Logs/Moffo, also visible in Console.app.
enum Log {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Moffo/moffo.log")

    private static let handle: FileHandle? = {
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // ponytail: rotates only at launch, fine for a few lines per hour
        if let size = try? fm.attributesOfItem(atPath: url.path)[.size] as? Int, size > 1_000_000 {
            let old = url.deletingLastPathComponent().appendingPathComponent("moffo.old.log")
            try? fm.removeItem(at: old)
            try? fm.moveItem(at: url, to: old)
        }
        if !fm.fileExists(atPath: url.path) { fm.createFile(atPath: url.path, contents: nil) }
        let h = try? FileHandle(forWritingTo: url)
        _ = try? h?.seekToEnd()
        return h
    }()

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func write(_ tag: String, _ message: String) {
        let line = "\(time.string(from: Date()))  \(tag.padding(toLength: 6, withPad: " ", startingAt: 0)) \(message)\n"
        try? handle?.write(contentsOf: Data(line.utf8))
    }
}
