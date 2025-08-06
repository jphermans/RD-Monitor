//
//  RDAccount.swift
//  RD-Monitor
//
//  Created by Jean-Pierre Hermans on 28/05/2025.
//

struct RDAccount: Codable {
    let username: String
    let email: String
    let expiration: String
    let points: Int
    let type: String // <- NEW: this reflects "premium"
    let premium: Int // <- but this is a timestamp, ignore it
}
