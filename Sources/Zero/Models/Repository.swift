import Foundation

struct Repository: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let isPrivate: Bool
    let htmlURL: URL
    let cloneURL: URL
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case isPrivate = "private"
        case htmlURL = "html_url"
        case cloneURL = "clone_url"
    }
}
