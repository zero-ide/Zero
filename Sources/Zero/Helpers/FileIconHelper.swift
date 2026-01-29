import SwiftUI

enum FileIconHelper {
    /// 파일 확장자에 따른 아이콘 이름과 색상 반환
    static func iconInfo(for filename: String, isDirectory: Bool) -> (name: String, color: Color) {
        if isDirectory {
            return ("folder.fill", .yellow)
        }
        
        let ext = (filename as NSString).pathExtension.lowercased()
        let name = filename.lowercased()
        
        // Special files
        if name == "dockerfile" { return ("shippingbox.fill", .blue) }
        if name == "readme.md" { return ("book.fill", .blue) }
        if name == ".gitignore" { return ("eye.slash", .orange) }
        if name.contains("license") { return ("doc.text.fill", .green) }
        
        switch ext {
        case "swift": return ("swift", .orange)
        case "java": return ("cup.and.saucer.fill", .red)
        case "kt", "kts": return ("k.square.fill", .purple)
        case "js": return ("j.square.fill", .yellow)
        case "ts": return ("t.square.fill", .blue)
        case "py": return ("p.square.fill", .cyan)
        case "rb": return ("r.square.fill", .red)
        case "go": return ("g.square.fill", .cyan)
        case "rs": return ("r.square.fill", .orange)
        case "json": return ("curlybraces", .yellow)
        case "xml", "plist": return ("chevron.left.forwardslash.chevron.right", .orange)
        case "html": return ("globe", .orange)
        case "css", "scss", "sass": return ("paintbrush.fill", .pink)
        case "md", "markdown": return ("doc.richtext.fill", .blue)
        case "yml", "yaml": return ("list.bullet.rectangle.fill", .pink)
        case "sh", "bash", "zsh": return ("terminal.fill", .green)
        case "sql": return ("cylinder.fill", .blue)
        case "png", "jpg", "jpeg", "gif", "svg", "ico": return ("photo.fill", .purple)
        case "pdf": return ("doc.fill", .red)
        case "zip", "tar", "gz", "rar": return ("doc.zipper", .gray)
        case "gradle": return ("g.square.fill", .green)
        case "properties": return ("gearshape.fill", .gray)
        case "env": return ("key.fill", .yellow)
        case "lock": return ("lock.fill", .gray)
        default: return ("doc.fill", .secondary)
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
