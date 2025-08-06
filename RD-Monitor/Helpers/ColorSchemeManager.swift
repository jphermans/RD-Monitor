//
//  ColorSchemeManager.swift
//  RD-Monitor
//
//  Created by Jean-Pierre Hermans on 28/05/2025.
//

import SwiftUI

enum AppColorScheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var iconName: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

class ColorSchemeManager: ObservableObject {
    @AppStorage("app_color_scheme") private var storedColorScheme: String = AppColorScheme.system.rawValue
    
    @Published var selectedScheme: AppColorScheme = .system {
        didSet {
            storedColorScheme = selectedScheme.rawValue
            // Force a small delay to ensure the change is processed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // This helps prevent view state issues during theme transitions
            }
        }
    }
    
    init() {
        // Safely initialize the selected scheme
        if let scheme = AppColorScheme(rawValue: storedColorScheme) {
            selectedScheme = scheme
        } else {
            // Fallback to system if stored value is invalid
            selectedScheme = .system
            storedColorScheme = AppColorScheme.system.rawValue
        }
    }
}

// MARK: - Custom Colors for Dark Mode
extension Color {
    static let appBackground = Color("AppBackground")
    static let cardBackground = Color("CardBackground")
    static let secondaryBackground = Color("SecondaryBackground")
} 