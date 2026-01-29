import Foundation

class SessionManager {
    private let storeURL: URL
    
    init(storeURL: URL? = nil) {
        if let url = storeURL {
            self.storeURL = url
        } else {
            // 기본값: ~/.zero/sessions.json
            let home = FileManager.default.homeDirectoryForCurrentUser
            let zeroDir = home.appendingPathComponent(".zero")
            try? FileManager.default.createDirectory(at: zeroDir, withIntermediateDirectories: true)
            self.storeURL = zeroDir.appendingPathComponent("sessions.json")
        }
    }
    
    func loadSessions() throws -> [Session] {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return []
        }
        let data = try Data(contentsOf: storeURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Session].self, from: data)
    }
    
    private func saveSessions(_ sessions: [Session]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(sessions)
        try data.write(to: storeURL)
    }
    
    @discardableResult
    func createSession(repoURL: URL, containerName: String) throws -> Session {
        var sessions = try loadSessions()
        let newSession = Session(
            id: UUID(),
            repoURL: repoURL,
            containerName: containerName,
            createdAt: Date(),
            lastActiveAt: Date()
        )
        sessions.append(newSession)
        try saveSessions(sessions)
        return newSession
    }
    
    func deleteSession(_ session: Session) throws {
        var sessions = try loadSessions()
        sessions.removeAll { $0.id == session.id }
        try saveSessions(sessions)
    }
}
