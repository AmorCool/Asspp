import Foundation

enum StoreAuthenticationError: LocalizedError {
    case codeRequired
    case invalidCode
    case invalidConfiguration
    case invalidRedirect
    case serviceResponse(Int)
    case rejected(String)
    case tooManyAttempts

    var needsCode: Bool {
        switch self {
        case .codeRequired, .invalidCode: true
        default: false
        }
    }

    var errorDescription: String? {
        switch self {
        case .codeRequired:
            String(localized: "Enter the verification code sent by Apple, then authenticate again.")
        case .invalidCode:
            String(localized: "The verification code was rejected. Enter a new code and try again.")
        case .invalidConfiguration:
            String(localized: "Apple returned an unsupported login configuration. Update the app and try again.")
        case .invalidRedirect:
            String(localized: "Apple returned an invalid login redirect. No credentials were forwarded.")
        case let .serviceResponse(status):
            String(localized: "Apple's login service returned an unexpected response (HTTP \(status)). This response does not indicate an incorrect password or a missing verification code. Try again later.")
        case let .rejected(message): message
        case .tooManyAttempts:
            String(localized: "Apple's login service exceeded the retry limit. Try again later.")
        }
    }
}

/// Pure protocol rules, shared by production requests and regression checks.
enum StoreAuthenticationProtocol {
    static let authenticationPath = "/WebObjects/MZFinance.woa/wa/authenticate"

    static func authenticationURL(_ value: String) throws -> URL {
        guard let url = URL(string: value), url.scheme == "https",
              url.user == nil, url.password == nil, url.fragment == nil,
              url.port == nil || url.port == 443,
              let host = url.host?.lowercased(),
              host == "buy.itunes.apple.com" || host.range(of: #"^p[0-9]+-buy\.itunes\.apple\.com$"#, options: .regularExpression) != nil,
              url.path == authenticationPath
        else { throw StoreAuthenticationError.invalidRedirect }
        return url
    }

    static func plist(_ data: Data) -> [String: Any]? {
        var payload = data
        // bag.xml wraps a plist in Document/Protocol; login replies are ordinary plists.
        if let xml = String(data: data, encoding: .utf8),
           let start = xml.range(of: "<plist"), let end = xml.range(of: "</plist>"),
           start.lowerBound < end.upperBound {
            payload = Data(xml[start.lowerBound ..< end.upperBound].utf8)
        }
        return (try? PropertyListSerialization.propertyList(from: payload, format: nil)) as? [String: Any]
    }

    static func body(email: String, password: String, code: String, guid: String, attempt: Int) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: [
            "appleId": email,
            "password": password + code.filter { !$0.isWhitespace },
            "guid": guid,
            "attempt": String(attempt),
            "rmp": "0",
            "why": "signIn",
        ], format: .xml, options: 0)
    }

    static func retryable(status: Int, data: Data) -> Bool {
        // Only retry unstructured transient responses, never a credential/2FA rejection.
        guard plist(data) == nil else { return false }
        return status == 204 || status == 404 || (500 ... 599).contains(status)
    }

    static func rejection(_ plist: [String: Any], code: String) -> StoreAuthenticationError? {
        let failure = string(plist["failureType"])
        let message = string(plist["customerMessage"])
        if failure.isEmpty, code.isEmpty, message == "MZFinance.BadLogin.Configurator_message" {
            return .codeRequired
        }
        if failure == "5005" { return .invalidCode }
        if !failure.isEmpty { return .rejected(message.isEmpty ? "Apple rejected the login (\(failure))." : message) }
        if message == "Your account is disabled." || message == "MZFinance.AccountDisabled_message" { return .rejected(message) }
        return nil
    }

    static func storeIdentifier(_ header: String) -> String {
        String(header.split(whereSeparator: { $0 == "-" || $0 == "," }).first ?? "")
    }

    static func string(_ value: Any?) -> String {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }
}
