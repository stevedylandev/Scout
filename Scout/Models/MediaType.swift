//
//  MediaType.swift
//  Scout
//

import Foundation

enum MediaType {
    case image
    case audio
    case unsupported

    init(mimeType: String) {
        let mime = mimeType.lowercased().trimmingCharacters(in: .whitespaces)

        if mime.hasPrefix("image/") {
            self = .image
        } else if mime.hasPrefix("audio/") {
            self = .audio
        } else {
            self = .unsupported
        }
    }

    static func isTextContent(_ mimeType: String) -> Bool {
        let mime = mimeType.lowercased().trimmingCharacters(in: .whitespaces)
        return mime.hasPrefix("text/")
    }

    static func isMediaContent(_ mimeType: String) -> Bool {
        let type = MediaType(mimeType: mimeType)
        return type != .unsupported
    }
}

struct MediaContent {
    let data: Data
    let mimeType: String
    let sourceURL: String

    var mediaType: MediaType {
        MediaType(mimeType: mimeType)
    }

    var suggestedFilename: String {
        if let url = URL(string: sourceURL) {
            let filename = url.lastPathComponent
            if !filename.isEmpty && filename != "/" {
                return filename
            }
        }

        // Generate filename based on MIME type
        let ext = fileExtension
        let timestamp = Int(Date().timeIntervalSince1970)
        return "titan_\(timestamp).\(ext)"
    }

    var fileExtension: String {
        let mime = mimeType.lowercased()

        // Image types
        if mime.contains("jpeg") || mime.contains("jpg") { return "jpg" }
        if mime.contains("png") { return "png" }
        if mime.contains("gif") { return "gif" }
        if mime.contains("webp") { return "webp" }
        if mime.contains("svg") { return "svg" }

        // Audio types
        if mime.contains("mpeg") || mime.contains("mp3") { return "mp3" }
        if mime.contains("ogg") { return "ogg" }
        if mime.contains("wav") { return "wav" }
        if mime.contains("flac") { return "flac" }
        if mime.contains("aac") { return "aac" }
        if mime.contains("m4a") { return "m4a" }

        // Fallback
        if mime.hasPrefix("image/") { return "jpg" }
        if mime.hasPrefix("audio/") { return "mp3" }

        return "bin"
    }
}
