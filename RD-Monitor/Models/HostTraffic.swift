//
//  TrafficEntry.swift
//  RD-Monitor
//
//  Created by Jean-Pierre Hermans on 28/05/2025.
//
import Foundation

struct HostTraffic: Identifiable {
    let id = UUID()
    let host: String
    let usedGB: Double
    let limitGB: Double
}
