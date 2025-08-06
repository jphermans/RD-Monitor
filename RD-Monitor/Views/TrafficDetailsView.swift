//
//  TrafficDetailsView.swift
//  RD-Monitor
//
//  Created by Jean-Pierre Hermans on 28/05/2025.
//

import SwiftUI

struct TrafficDetailsView: View {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @AppStorage("rd_demo_mode") var demoMode: Bool = false
    @State private var trafficDetails: [TrafficDay] = []
    @State private var isLoading = true
    @State private var error: String?
    @Environment(\.colorScheme) var colorScheme
    
    private var isDemoMode: Bool {
        return demoMode || DemoDataService.isDemoMode(apiKey: apiKey)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView("Loading traffic details...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if let error = error {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.title2)
                            Text("Error loading traffic details")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else if trafficDetails.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.bar")
                                .font(.title2)
                                .foregroundColor(.gray)
                            Text("No traffic data available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(trafficDetails.sorted { $0.date > $1.date }, id: \.date) { day in
                                TrafficDayView(day: day)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(isDemoMode ? "Traffic Details (Demo)" : "Traffic Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .background(backgroundColorForScheme)
            .onAppear {
                fetchTrafficDetails()
            }
        }
    }
    
    func fetchTrafficDetails() {
        if isDemoMode {
            fetchDemoTrafficDetails()
            return
        }
        
        isLoading = true
        error = nil
        
        // Fetch last 31 days of traffic details
        let calendar = Calendar.current
        let now = Date()
        let thirtyOneDaysAgo = calendar.date(byAdding: .day, value: -31, to: now) ?? now
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startDate = dateFormatter.string(from: thirtyOneDaysAgo)
        let endDate = dateFormatter.string(from: now)
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/traffic/details?start=\(startDate)&end=\(endDate)") else {
            error = "Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.error = "Network error: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                DispatchQueue.main.async {
                    self.error = "API error: HTTP \(httpResponse.statusCode)"
                    self.isLoading = false
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.error = "No data received"
                    self.isLoading = false
                }
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
                
                var details: [TrafficDay] = []
                
                for (dateString, dayData) in json {
                    guard let dayDict = dayData as? [String: Any] else { continue }
                    
                    var hosts: [TrafficHost] = []
                    var totalBytes: Int64 = 0
                    
                    // Parse hosts data
                    if let hostsDict = dayDict["hosts"] as? [String: Any] {
                        for (hostName, hostData) in hostsDict {
                            if let hostDict = hostData as? [String: Any],
                               let bytes = hostDict["bytes"] as? Int64 {
                                hosts.append(TrafficHost(name: hostName, bytes: bytes))
                                totalBytes += bytes
                            }
                        }
                    }
                    
                    // If no hosts data, try to get total bytes directly
                    if totalBytes == 0 {
                        if let bytes = dayDict["bytes"] as? Int64 {
                            totalBytes = bytes
                            hosts.append(TrafficHost(name: "Real-Debrid", bytes: bytes))
                        } else if let bytes = dayDict["bytes"] as? Int {
                            totalBytes = Int64(bytes)
                            hosts.append(TrafficHost(name: "Real-Debrid", bytes: Int64(bytes)))
                        } else if let bytes = dayDict["bytes"] as? Double {
                            totalBytes = Int64(bytes)
                            hosts.append(TrafficHost(name: "Real-Debrid", bytes: Int64(bytes)))
                        }
                    }
                    
                    if totalBytes > 0 {
                        details.append(TrafficDay(
                            date: dateString,
                            hosts: hosts.sorted { $0.bytes > $1.bytes },
                            totalBytes: totalBytes
                        ))
                    }
                }
                
                DispatchQueue.main.async {
                    self.trafficDetails = details
                    self.isLoading = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.error = "Failed to parse traffic data"
                    self.isLoading = false
                }
            }
        }.resume()
    }
    
    func fetchDemoTrafficDetails() {
        isLoading = true
        error = nil
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let demoData = DemoDataService.shared.getDemoTrafficData()
            
            print("Demo data keys: \(demoData.keys)")
            
            guard let dailyTraffic = demoData["daily_traffic"] as? [[String: Any]] else {
                print("Failed to get daily_traffic from demo data")
                print("Demo data: \(demoData)")
                self.error = "Invalid demo data format"
                self.isLoading = false
                return
            }
            
            print("Daily traffic count: \(dailyTraffic.count)")
            
            var detailsDict: [String: [TrafficHost]] = [:]
            
            // Group traffic by date and sometimes add multiple hosts per day
            for traffic in dailyTraffic {
                guard let dateString = traffic["date"] as? String,
                      let bytes = traffic["bytes"] as? Int,
                      let host = traffic["host"] as? String else {
                    print("Failed to parse traffic entry: \(traffic)")
                    continue
                }
                
                print("Processing traffic: date=\(dateString), host=\(host), bytes=\(bytes)")
                
                let trafficHost = TrafficHost(name: host, bytes: Int64(bytes))
                
                if var existingHosts = detailsDict[dateString] {
                    existingHosts.append(trafficHost)
                    detailsDict[dateString] = existingHosts
                } else {
                    detailsDict[dateString] = [trafficHost]
                    
                    // 30% chance to add a second host for this day (more realistic)
                    if Double.random(in: 0...1) < 0.3 {
                        let additionalHosts = ["mega.nz", "1fichier.com", "rapidgator.net", "turbobit.net"]
                        if let randomHost = additionalHosts.randomElement(), randomHost != host {
                            let additionalBytes = Int64(Double.random(in: 0.1...0.8) * Double(bytes))
                            let additionalTrafficHost = TrafficHost(name: randomHost, bytes: additionalBytes)
                            detailsDict[dateString]?.append(additionalTrafficHost)
                        }
                    }
                }
            }
            
            print("Processed \(detailsDict.count) unique dates")
            
            // Convert to TrafficDay objects
            var details: [TrafficDay] = []
            for (dateString, hosts) in detailsDict {
                let sortedHosts = hosts.sorted { $0.bytes > $1.bytes }
                let totalBytes = sortedHosts.reduce(0) { $0 + $1.bytes }
                
                details.append(TrafficDay(
                    date: dateString,
                    hosts: sortedHosts,
                    totalBytes: totalBytes
                ))
            }
            
            print("Created \(details.count) traffic days")
            
            self.trafficDetails = details
            self.isLoading = false
        }
    }
    
    // MARK: - Adaptive Colors
    private var backgroundColorForScheme: Color {
        colorScheme == .dark ? Color.black.opacity(0.9) : Color.gray.opacity(0.05)
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.15) : Color.white
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
}

struct TrafficDayView: View {
    let day: TrafficDay
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Date header
            Text(formatDate(day.date))
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            
            // Hosts table
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Hoster")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Downloaded")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.teal)
                
                // Host rows
                ForEach(Array(day.hosts.enumerated()), id: \.offset) { index, host in
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.teal)
                                .frame(width: 8, height: 8)
                            
                            Text(host.name)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(formatBytes(host.bytes))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(index % 2 == 0 ? alternatingRowColor : cardBackgroundColor)
                }
                
                // Total row
                HStack {
                    Text("Total:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(formatBytes(day.totalBytes))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.teal)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(cardBackgroundColor)
                    .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
            )
        }
    }
    
    // MARK: - Adaptive Colors
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.15) : Color.white
    }
    
    private var alternatingRowColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        
        return dateString
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .decimal
        formatter.includesUnit = true
        formatter.isAdaptive = true
        
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Types

struct TrafficDay {
    let date: String
    let hosts: [TrafficHost]
    let totalBytes: Int64
}

struct TrafficHost {
    let name: String
    let bytes: Int64
} 