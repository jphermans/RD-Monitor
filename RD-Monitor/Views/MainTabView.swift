//
//  MainTabView.swift
//  RD-Monitor
//
//  Created by Jean-Pierre Hermans on 28/05/2025.
//

import SwiftUI

struct MainTabView: View {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @AppStorage("rd_demo_mode") var demoMode: Bool = false
    
    private var isDemoMode: Bool {
        return demoMode || DemoDataService.isDemoMode(apiKey: apiKey)
    }
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Dashboard")
                }
            
            AccountProfileView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Profile")
                }
            
            // Only show torrents, unrestrict, downloads, and streaming tabs in real mode
            if !isDemoMode {
                TorrentsView()
                    .tabItem {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Torrents")
                    }
                
                UnrestrictView()
                    .tabItem {
                        Image(systemName: "link.circle.fill")
                        Text("Unrestrict")
                    }
                
                DownloadsView()
                    .tabItem {
                        Image(systemName: "folder.circle.fill")
                        Text("Downloads")
                    }
                
                StreamingView()
                    .tabItem {
                        Image(systemName: "play.tv.fill")
                        Text("Streaming")
                    }
            }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear.circle.fill")
                    Text("Settings")
                }
            
            SetupView()
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver.fill")
                    Text("Setup")
                }
        }
        .accentColor(.teal)
        .defaultBackground()
    }
}

#Preview {
    MainTabView()
        .defaultBackground()
} 