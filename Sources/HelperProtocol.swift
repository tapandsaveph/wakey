import Foundation

@objc protocol SleepHelperProtocol {
    func setSleepDisabled(_ disabled: Bool, reply: @escaping @Sendable (Bool, String?) -> Void)
}

enum HelperConfiguration {
    static let service = "app.wakey.mac.helper.distribution"
    static let plist = "app.wakey.mac.helper.distribution.plist"
    static func requirement(identifier: String) -> String {
        "anchor apple generic and certificate leaf = H\"\(BuildIdentity.certificate)\" and identifier \"\(identifier)\""
    }
}
