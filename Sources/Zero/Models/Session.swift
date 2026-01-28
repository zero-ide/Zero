import Foundation

struct Session: Codable, Identifiable, Equatable {
    let id: UUID
    let repoURL: URL
    let containerName: String
    let createdAt: Date
    var lastActiveAt: Date
}
