//
//  ErrorPageView.swift
//  Titan
//

import SwiftUI

enum GeminiErrorType {
    case temporaryFailure(code: Int, meta: String)
    case permanentFailure(code: Int, meta: String)
    case clientCertificate(code: Int, meta: String)
    case tooManyRedirects
    case networkError(String)
    case invalidResponse
    case invalidURL

    var title: String {
        switch self {
        case .temporaryFailure(let code, _):
            switch code {
            case 40: return "Temporary Failure"
            case 41: return "Server Unavailable"
            case 42: return "CGI Error"
            case 43: return "Proxy Error"
            case 44: return "Slow Down"
            default: return "Temporary Failure"
            }
        case .permanentFailure(let code, _):
            switch code {
            case 50: return "Permanent Failure"
            case 51: return "Not Found"
            case 52: return "Gone"
            case 53: return "Proxy Request Refused"
            case 59: return "Bad Request"
            default: return "Error"
            }
        case .clientCertificate(let code, _):
            switch code {
            case 60: return "Certificate Required"
            case 61: return "Certificate Not Authorized"
            case 62: return "Certificate Not Valid"
            default: return "Certificate Error"
            }
        case .tooManyRedirects:
            return "Too Many Redirects"
        case .networkError:
            return "Connection Failed"
        case .invalidResponse:
            return "Invalid Response"
        case .invalidURL:
            return "Invalid URL"
        }
    }

    var statusCode: String? {
        switch self {
        case .temporaryFailure(let code, _),
             .permanentFailure(let code, _),
             .clientCertificate(let code, _):
            return "(\(code))"
        default:
            return nil
        }
    }

    var meta: String? {
        switch self {
        case .temporaryFailure(_, let meta),
             .permanentFailure(_, let meta),
             .clientCertificate(_, let meta):
            return meta.isEmpty ? nil : meta
        case .networkError(let message):
            return message
        default:
            return nil
        }
    }

    var explanation: String {
        switch self {
        case .temporaryFailure(let code, _):
            switch code {
            case 40:
                return "The server encountered a temporary problem and couldn't complete your request."
            case 41:
                return "The server is currently unavailable, possibly due to maintenance or high load."
            case 42:
                return "A script on the server failed to execute properly."
            case 43:
                return "There was an error communicating through a proxy server."
            case 44:
                return "You're making requests too quickly. The server needs you to slow down."
            default:
                return "The server encountered a temporary issue processing your request."
            }
        case .permanentFailure(let code, _):
            switch code {
            case 50:
                return "The server cannot fulfill this request. The issue is permanent."
            case 51:
                return "The page you requested doesn't exist on this server."
            case 52:
                return "This content used to exist but has been permanently removed."
            case 53:
                return "This server does not accept proxy requests."
            case 59:
                return "The server couldn't understand your request. The URL may be malformed."
            default:
                return "The server cannot process this request."
            }
        case .clientCertificate(let code, _):
            switch code {
            case 60:
                return "This page requires a client certificate for authentication."
            case 61:
                return "Your certificate is not authorized to access this resource."
            case 62:
                return "Your certificate is invalid or has expired."
            default:
                return "There's an issue with certificate authentication."
            }
        case .tooManyRedirects:
            return "The page redirected too many times, possibly in a loop."
        case .networkError:
            return "Unable to establish a connection to the server."
        case .invalidResponse:
            return "The server sent a response that couldn't be understood."
        case .invalidURL:
            return "The URL you entered isn't valid for the Gemini protocol."
        }
    }

    var suggestions: [String] {
        switch self {
        case .temporaryFailure(let code, _):
            switch code {
            case 41:
                return [
                    "Wait a few minutes and try again",
                    "Check if the site is down for others",
                    "Try a different page on the same site"
                ]
            case 44:
                return [
                    "Wait before making another request",
                    "Avoid refreshing repeatedly"
                ]
            default:
                return [
                    "Try again in a few moments",
                    "The issue may resolve itself"
                ]
            }
        case .permanentFailure(let code, _):
            switch code {
            case 51:
                return [
                    "Check the URL for typos",
                    "The page may have moved",
                    "Try the site's homepage"
                ]
            case 52:
                return [
                    "This content has been removed",
                    "Try searching for similar content",
                    "Check for an archived version"
                ]
            case 59:
                return [
                    "Check the URL format",
                    "Ensure special characters are encoded",
                    "Try a simpler URL"
                ]
            default:
                return [
                    "Double-check the URL",
                    "Try a different page"
                ]
            }
        case .clientCertificate(let code, _):
            switch code {
            case 60:
                return [
                    "Client certificates are not yet supported",
                    "Some Gemini sites require authentication"
                ]
            default:
                return [
                    "Certificate authentication failed",
                    "Contact the site administrator"
                ]
            }
        case .tooManyRedirects:
            return [
                "The site may have a configuration issue",
                "Try accessing the page directly",
                "Contact the site administrator"
            ]
        case .networkError:
            return [
                "Check your internet connection",
                "Verify the hostname is correct",
                "The server may be offline"
            ]
        case .invalidResponse:
            return [
                "The server may not support Gemini",
                "Try again later",
                "Report the issue to the site owner"
            ]
        case .invalidURL:
            return [
                "URLs should start with gemini://",
                "Check for typos in the address",
                "Ensure the hostname is valid"
            ]
        }
    }

    var icon: String {
        switch self {
        case .temporaryFailure(let code, _):
            if code == 44 {
                return "hourglass"
            }
            return "clock.badge.exclamationmark"
        case .permanentFailure(let code, _):
            if code == 51 {
                return "questionmark.folder"
            }
            if code == 52 {
                return "trash"
            }
            return "xmark.circle"
        case .clientCertificate:
            return "lock.shield"
        case .tooManyRedirects:
            return "arrow.triangle.2.circlepath"
        case .networkError:
            return "wifi.slash"
        case .invalidResponse:
            return "doc.badge.ellipsis"
        case .invalidURL:
            return "link.badge.plus"
        }
    }
}

struct ErrorPageView: View {
    let errorType: GeminiErrorType
    let onRetry: (() -> Void)?

    @EnvironmentObject private var themeSettings: ThemeSettings

    init(errorType: GeminiErrorType, onRetry: (() -> Void)? = nil) {
        self.errorType = errorType
        self.onRetry = onRetry
    }

    private var errorColor: Color {
        switch errorType {
        case .temporaryFailure:
            return .orange
        case .permanentFailure:
            return .red
        case .clientCertificate:
            return .purple
        case .tooManyRedirects:
            return .yellow
        case .networkError, .invalidResponse, .invalidURL:
            return .gray
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: errorType.icon)
                .font(.system(size: 60))
                .foregroundColor(errorColor)

            // Title and status code
            VStack(spacing: 4) {
                Text(errorType.title)
                    .font(.system(.title2, design: themeSettings.fontDesign.fontDesign))
                    .fontWeight(.bold)
                    .foregroundColor(themeSettings.textColor)

                if let code = errorType.statusCode {
                    Text(code)
                        .font(.system(.subheadline, design: themeSettings.fontDesign.fontDesign))
                        .foregroundColor(.secondary)
                }
            }

            // Server message if present and different from title
            if let meta = errorType.meta,
               meta.lowercased() != errorType.title.lowercased() {
                Text(meta)
                    .font(.system(.caption, design: themeSettings.fontDesign.fontDesign))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }

            // Explanation
            Text(errorType.explanation)
                .font(.system(.body, design: themeSettings.fontDesign.fontDesign))
                .foregroundColor(themeSettings.textColor.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Suggestions
            VStack(alignment: .leading, spacing: 8) {
                ForEach(errorType.suggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(errorColor)
                        Text(suggestion)
                            .font(.system(.callout, design: themeSettings.fontDesign.fontDesign))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 32)

            // Retry button for temporary errors
            if let onRetry = onRetry, canRetry {
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.system(.body, design: themeSettings.fontDesign.fontDesign))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(themeSettings.accentColor)
                    )
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private var canRetry: Bool {
        switch errorType {
        case .temporaryFailure, .networkError:
            return true
        default:
            return false
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 40) {
            ErrorPageView(errorType: .permanentFailure(code: 51, meta: "Resource not found"))

            Divider()

            ErrorPageView(errorType: .temporaryFailure(code: 44, meta: "Please wait 30 seconds"), onRetry: {})

            Divider()

            ErrorPageView(errorType: .networkError("Connection refused"))
        }
    }
    .environmentObject(ThemeSettings())
}
