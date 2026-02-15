import Foundation

enum Constants {
    enum Docker {
        static let path = "/usr/local/bin/docker"
        static let baseImage = "alpine:latest"
        static let workspacePath = "/workspace"
    }
    
    enum Keychain {
        static let service = "com.zero.ide"
        static let account = "github_token"
    }
    
    enum GitHub {
        static let pageSize = 30
    }
    
    enum UI {
        static let sidebarMinWidth: CGFloat = 220
        static let sidebarIdealWidth: CGFloat = 260
        static let sidebarMaxWidth: CGFloat = 400
    }

    enum Preferences {
        static let selectedOrgLogin = "com.zero.ide.last_selected_org_login"
        static let telemetryOptIn = "com.zero.ide.telemetry_opt_in"
    }
}
