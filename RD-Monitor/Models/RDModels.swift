import Foundation

// MARK: - Real-Debrid Data Models

struct RDDownload {
    let id: String
    let filename: String
    let mimeType: String
    let filesize: Int64
    let link: String
    let host: String
    let chunks: Int
    let download: String
    let generated: String
    let type: String?
}

// MARK: - Streaming Models

struct StreamingData {
    let downloadId: String
    let qualities: [StreamQuality]
}

struct StreamQuality: Identifiable {
    let id = UUID()
    let format: String
    let quality: String
    let url: String
    
    var displayName: String {
        return "\(quality) (\(format))"
    }
}

// MARK: - Profile Models (shared between views)

struct UserProfile {
    let id: Int
    let username: String
    let email: String
    let points: Int
    let locale: String
    let avatar: String
    let type: String
    let premium: Int
    let expiration: String
}

struct UserTraffic {
    let left: Int64
    let bytes: Int64
    let links: Int
    let limit: Int64
    let type: String
    let extra: Int64
    let reset: String
} 