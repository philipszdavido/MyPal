import OSLog

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "MyPal"
    static let data = Logger(subsystem: subsystem, category: "data")
    static let chat = Logger(subsystem: subsystem, category: "chat")
}
