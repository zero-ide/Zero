import Foundation

struct Organization: Codable, Identifiable, Hashable {
    let id: Int
    let login: String
    let avatarURL: String?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarURL = "avatar_url"
        case description
    }
}