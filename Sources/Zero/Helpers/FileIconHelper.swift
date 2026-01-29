import SwiftUI

import SwiftUI

enum FileIconHelper {
    // MARK: - Material Theme Colors
    private static let jsYellow = Color(red: 0.96, green: 0.84, blue: 0.23)
    private static let tsBlue = Color(red: 0.19, green: 0.47, blue: 0.75)
    private static let swiftOrange = Color(red: 0.96, green: 0.51, blue: 0.19)
    private static let javaRed = Color(red: 0.91, green: 0.13, blue: 0.13)
    private static let kotlinPurple = Color(red: 0.50, green: 0.35, blue: 0.95)
    private static let pythonBlue = Color(red: 0.22, green: 0.46, blue: 0.65)
    private static let goCyan = Color(red: 0.00, green: 0.68, blue: 0.84)
    private static let rubyRed = Color(red: 0.80, green: 0.10, blue: 0.10)
    private static let htmlOrange = Color(red: 0.89, green: 0.29, blue: 0.13)
    private static let cssBlue = Color(red: 0.33, green: 0.62, blue: 0.92)
    private static let jsonYellow = Color(red: 0.96, green: 0.84, blue: 0.23)
    private static let mdBlue = Color(red: 0.31, green: 0.61, blue: 0.93)
    private static let shellGreen = Color(red: 0.31, green: 0.82, blue: 0.38)
    private static let folderYellow = Color(red: 1.00, green: 0.80, blue: 0.35)
    private static let dockerBlue = Color(red: 0.14, green: 0.58, blue: 0.94)
    private static let gitOrange = Color(red: 0.94, green: 0.31, blue: 0.20)
    private static let textGray = Color(red: 0.60, green: 0.60, blue: 0.60)
    
    /// 파일 확장자에 따른 아이콘 이름과 색상 반환
    static func iconInfo(for filename: String, isDirectory: Bool) -> (name: String, color: Color) {
        if isDirectory {
            return ("folder.fill", folderYellow)
        }
        
        let ext = (filename as NSString).pathExtension.lowercased()
        let name = filename.lowercased()
        
        // Special files
        if name == "dockerfile" { return ("shippingbox.fill", dockerBlue) }
        if name == "readme.md" { return ("book.fill", mdBlue) }
        if name == ".gitignore" { return ("eye.slash", gitOrange) }
        if name.contains("license") { return ("doc.text.fill", textGray) }
        
        switch ext {
        case "swift": return ("swift", swiftOrange)
        case "java": return ("cup.and.saucer.fill", javaRed)
        case "kt", "kts": return ("k.square.fill", kotlinPurple)
        case "js": return ("j.square.fill", jsYellow)
        case "ts": return ("t.square.fill", tsBlue)
        case "py": return ("p.square.fill", pythonBlue)
        case "rb": return ("r.square.fill", rubyRed)
        case "go": return ("g.square.fill", goCyan)
        case "rs": return ("r.square.fill", swiftOrange)
        case "json": return ("curlybraces", jsonYellow)
        case "xml", "plist": return ("chevron.left.forwardslash.chevron.right", swiftOrange)
        case "html": return ("globe", htmlOrange)
        case "css", "scss", "sass": return ("paintbrush.fill", cssBlue)
        case "md", "markdown": return ("doc.richtext.fill", mdBlue)
        case "yml", "yaml": return ("list.bullet.rectangle.fill", kotlinPurple)
        case "sh", "bash", "zsh": return ("terminal.fill", shellGreen)
        case "sql": return ("cylinder.fill", tsBlue)
        case "png", "jpg", "jpeg", "gif", "svg", "ico": return ("photo.fill", kotlinPurple)
        case "pdf": return ("doc.fill", javaRed)
        case "zip", "tar", "gz", "rar": return ("doc.zipper", textGray)
        case "gradle": return ("g.square.fill", shellGreen)
        case "properties", "env": return ("gearshape.fill", textGray)
        case "lock": return ("lock.fill", textGray)
        default: return ("doc.text", textGray)
        }
    }
    
    /// 파일 확장자에 따른 언어 이름 반환 (syntax highlighting용)
    static func languageName(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js": return "javascript"
        case "ts": return "typescript"
        case "py": return "python"
        case "java": return "java"
        case "kt", "kts": return "kotlin"
        case "json": return "json"
        case "html": return "html"
        case "css": return "css"
        case "md": return "markdown"
        case "yaml", "yml": return "yaml"
        case "xml": return "xml"
        case "sh": return "shell"
        case "c", "h": return "c"
        case "cpp", "hpp": return "cpp"
        case "go": return "go"
        case "rs": return "rust"
        case "rb": return "ruby"
        case "php": return "php"
        case "sql": return "sql"
        case "dockerfile": return "dockerfile"
        default: return "plaintext"
        }
    }
    
    /// 언어 표시 이름 반환
    static func languageDisplayName(_ lang: String) -> String {
        switch lang {
        case "swift": return "Swift"
        case "java": return "Java"
        case "kotlin": return "Kotlin"
        case "javascript": return "JavaScript"
        case "typescript": return "TypeScript"
        case "python": return "Python"
        case "json": return "JSON"
        case "html": return "HTML"
        case "css": return "CSS"
        case "markdown": return "Markdown"
        case "yaml": return "YAML"
        case "shell": return "Shell"
        case "dockerfile": return "Dockerfile"
        case "plaintext": return "Plain Text"
        default: return lang.capitalized
        }
    }
}
