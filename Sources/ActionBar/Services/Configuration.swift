import Foundation

enum Configuration {
    // Register your GitHub OAuth App at: https://github.com/settings/applications/new
    // Enable "Device Authorization Flow" in the app settings.
    static let gitHubClientId = "Ov23liOGopIGJtkCifp2"

    static let gitHubScopes = "repo workflow"

    static let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    static let accessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!
    static let verificationURL = URL(string: "https://github.com/login/device")!

    static let defaultPollInterval: TimeInterval = 30
    static let defaultActivePollInterval: TimeInterval = 10
    static let keychainServiceName = "com.jpmarr.ActionBar"
    static let keychainAccountName = "github-token"
}
