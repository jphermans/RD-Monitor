//
//  DashboardView.swift
//  RD-Monitor
//
import SwiftUI
import Charts
import Foundation

struct DashboardView: View {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @AppStorage("rd_demo_mode") var demoMode: Bool = false
    @State private var error: String?
    @State private var timer: Timer?
    @State private var trafficList: [HostTraffic] = []
    @State private var trafficSummary: TrafficSummary?
    @State private var isLoading = true
    @State private var showingTrafficDetails = false
    @Environment(\.colorScheme) var colorScheme
    
    private var isDemoMode: Bool {
        return demoMode || DemoDataService.isDemoMode(apiKey: apiKey)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // App Title with icon and subheadline
                    HStack {
                        Image(systemName: "network")
                            .font(.title)
                            .foregroundColor(.teal)
                        Text("RD-Monitor")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                        
                        if isDemoMode {
                            Text("(Demo)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }

                    Text(isDemoMode ? "Exploring sample data" : "Your Real-Debrid usage at a glance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Traffic Summary Section
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Traffic")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        if isLoading {
                            ProgressView("Loading traffic data...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if let summary = trafficSummary {
                            VStack(spacing: 12) {
                                TrafficRow(
                                    icon: "doc.text.fill",
                                    title: "Today:",
                                    value: formatBytes(summary.todayBytes)
                                )
                                
                                TrafficRow(
                                    icon: "doc.text.fill",
                                    title: "This month:",
                                    value: formatBytes(summary.thisMonthBytes)
                                )
                                
                                TrafficRow(
                                    icon: "doc.text.fill",
                                    title: "Last 31 days:",
                                    value: formatBytes(summary.thisYearBytes)
                                )
                                
                                TrafficRow(
                                    icon: "doc.text.fill",
                                    title: "Last 7 days:",
                                    value: formatBytes(summary.globalBytes)
                                )
                            }
                            
                            HStack {
                                Spacer()
                                Button("Details >>") {
                                    showingTrafficDetails = true
                                }
                                .foregroundColor(.blue)
                                .font(.subheadline)
                            }
                            .padding(.top, 8)
                        } else if let error = error {
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .font(.title2)
                                Text("Error loading traffic data")
                                    .font(.headline)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackgroundColor)
                            .shadow(color: shadowColor, radius: 4, x: 0, y: 2)
                    )

                    Divider()

                    // Host Traffic Chart Section
                    if !trafficList.isEmpty {
                        VStack(spacing: 12) {
                            HStack {
                                Text("🔌 Host Traffic Usage")
                                    .font(.headline)
                                Spacer()
                            }

                            Chart(trafficList) { entry in
                                BarMark(
                                    x: .value("Used", entry.usedGB),
                                    y: .value("Host", entry.host)
                                )
                                .foregroundStyle(.teal)
                                .annotation(position: .trailing) {
                                    Text(String(format: "%.1f GB", entry.usedGB))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .chartXAxisLabel("Used GB")
                            .chartXScale(domain: 0...(trafficList.map { $0.usedGB }.max() ?? 1) * 1.1)
                            .frame(height: 250)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cardBackgroundColor)
                                .shadow(color: shadowColor, radius: 4, x: 0, y: 2)
                        )
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.bar")
                                .font(.title2)
                                .foregroundColor(.gray)
                            Text("No host traffic data available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cardBackgroundColor)
                                .shadow(color: shadowColor, radius: 4, x: 0, y: 2)
                        )
                    }
                }
                .padding()
                .onAppear {
                    fetchTrafficData()
                    startAutoRefresh()
                }
                .onDisappear {
                    timer?.invalidate()
                }
            }
            .defaultBackground()
        }
        .sheet(isPresented: $showingTrafficDetails) {
            TrafficDetailsView()
                .defaultBackground()
        }
    }

    func fetchTrafficData() {
        if isDemoMode {
            fetchDemoTrafficData()
            return
        }
        
        isLoading = true
        error = nil
        
        // Fetch both traffic summary and host traffic
        fetchTrafficSummary()
        fetchHostTraffic()
    }
    
    func fetchDemoTrafficData() {
        isLoading = true
        error = nil
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let demoData = DemoDataService.shared.getDemoTrafficData()
            
            // Extract traffic summary from demo data
            let dailyTraffic = (demoData["daily_traffic"] as? [[String: Any]]) ?? []
            
            // Calculate traffic for different periods
            let calendar = Calendar.current
            let now = Date()
            let today = calendar.startOfDay(for: now)
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? today
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? today
            let thirtyOneDaysAgo = calendar.date(byAdding: .day, value: -31, to: now) ?? today
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            var todayBytes: Int64 = 0
            var thisMonthBytes: Int64 = 0
            var last7DaysBytes: Int64 = 0
            var last31DaysBytes: Int64 = 0
            
            print("Demo traffic data count: \(dailyTraffic.count)")
            
            for traffic in dailyTraffic {
                guard let dateString = traffic["date"] as? String,
                      let date = dateFormatter.date(from: dateString),
                      let bytes = traffic["bytes"] as? Int else {
                    print("Failed to parse traffic entry: \(traffic)")
                    continue
                }
                
                let bytesInt64 = Int64(bytes)
                print("Processing date: \(dateString), bytes: \(bytesInt64)")
                
                if calendar.isDate(date, inSameDayAs: today) {
                    todayBytes += bytesInt64
                    print("Added to today: \(bytesInt64)")
                }
                
                if date >= startOfMonth {
                    thisMonthBytes += bytesInt64
                    print("Added to this month: \(bytesInt64)")
                }
                
                if date >= sevenDaysAgo {
                    last7DaysBytes += bytesInt64
                    print("Added to last 7 days: \(bytesInt64)")
                }
                
                if date >= thirtyOneDaysAgo {
                    last31DaysBytes += bytesInt64
                    print("Added to last 31 days: \(bytesInt64)")
                }
            }
            
            print("Final totals - Today: \(todayBytes), Month: \(thisMonthBytes), 7 days: \(last7DaysBytes), 31 days: \(last31DaysBytes)")
            
            self.trafficSummary = TrafficSummary()
            self.trafficSummary?.todayBytes = todayBytes
            self.trafficSummary?.thisMonthBytes = thisMonthBytes
            self.trafficSummary?.thisYearBytes = last31DaysBytes
            self.trafficSummary?.globalBytes = last7DaysBytes
            
            // Generate demo host traffic
            let hosts = ["mega.nz", "1fichier.com", "rapidgator.net", "turbobit.net", "nitroflare.com", "uploaded.net", "katfile.com"]
            self.trafficList = hosts.enumerated().map { index, host in
                // Generate realistic traffic based on host popularity
                let baseUsage: Double
                if index == 0 {
                    baseUsage = Double.random(in: 45...85)  // Mega - most popular
                } else if index == 1 {
                    baseUsage = Double.random(in: 25...65)  // 1fichier
                } else if index == 2 {
                    baseUsage = Double.random(in: 15...45)  // RapidGator
                } else if index == 3 {
                    baseUsage = Double.random(in: 10...35)  // Turbobit
                } else if index == 4 {
                    baseUsage = Double.random(in: 5...25)   // Nitroflare
                } else if index == 5 {
                    baseUsage = Double.random(in: 2...15)   // Uploaded
                } else {
                    baseUsage = Double.random(in: 1...8)    // Others
                }
                
                let limitGB = Double.random(in: 150...1000)
                return HostTraffic(host: host, usedGB: baseUsage, limitGB: limitGB)
            }.sorted { $0.usedGB > $1.usedGB }
            
            self.isLoading = false
        }
    }
    
    func fetchTrafficSummary() {
        // Only call for non-demo mode
        guard !isDemoMode else { return }
        
        // Calculate date ranges
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? today
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        print("Fetching traffic for periods:")
        print("Today: \(dateFormatter.string(from: today)) to \(dateFormatter.string(from: now))")
        print("Month: \(dateFormatter.string(from: startOfMonth)) to \(dateFormatter.string(from: now))")
        
        // Fetch today's traffic
        fetchTrafficDetails(
            start: dateFormatter.string(from: today),
            end: dateFormatter.string(from: now),
            period: .today
        )
        
        // Fetch this month's traffic
        fetchTrafficDetails(
            start: dateFormatter.string(from: startOfMonth),
            end: dateFormatter.string(from: now),
            period: .thisMonth
        )
        
        // For "Last 31 days" - fetch exactly 31 days
        let thirtyOneDaysAgo = calendar.date(byAdding: .day, value: -31, to: now) ?? startOfMonth
        fetchTrafficDetails(
            start: dateFormatter.string(from: thirtyOneDaysAgo),
            end: dateFormatter.string(from: now),
            period: .thisYear
        )
        
        // For "Last 7 days" - a more recent period
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? today
        fetchTrafficDetails(
            start: dateFormatter.string(from: sevenDaysAgo),
            end: dateFormatter.string(from: now),
            period: .global
        )
    }
    
    func fetchTrafficDetails(start: String, end: String, period: TrafficPeriod) {
        // Only call for non-demo mode
        guard !isDemoMode else { return }
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/traffic/details?start=\(start)&end=\(end)") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error for \(period): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.error = "Network error: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status for \(period): \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 429 {
                    print("Rate limit exceeded for \(period)")
                    DispatchQueue.main.async {
                        self.error = "Rate limit exceeded. Please wait a moment."
                        self.isLoading = false
                    }
                    return
                } else if httpResponse.statusCode != 200 {
                    print("HTTP error for \(period): \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        self.error = "API error: HTTP \(httpResponse.statusCode)"
                        self.isLoading = false
                    }
                    return
                }
            }
            
            guard let data = data else { 
                print("No data received for period \(period)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return 
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
                
                print("Traffic data for \(period): \(json.keys.count) days")
                
                var totalBytes: Int64 = 0
                for (date, dayData) in json {
                    if let dayDict = dayData as? [String: Any] {
                        var dayBytes: Int64 = 0
                        // Handle different possible data types for bytes
                        if let bytes = dayDict["bytes"] as? Int64 {
                            dayBytes = bytes
                        } else if let bytes = dayDict["bytes"] as? Int {
                            dayBytes = Int64(bytes)
                        } else if let bytes = dayDict["bytes"] as? Double {
                            dayBytes = Int64(bytes)
                        } else if let bytesString = dayDict["bytes"] as? String,
                                  let bytes = Int64(bytesString) {
                            dayBytes = bytes
                        }
                        
                        if dayBytes > 0 {
                            print("  \(date): \(dayBytes) bytes")
                        }
                        totalBytes += dayBytes
                    }
                }
                
                print("Total bytes for \(period): \(totalBytes)")
                
                DispatchQueue.main.async {
                    if self.trafficSummary == nil {
                        self.trafficSummary = TrafficSummary()
                    }
                    
                    switch period {
                    case .today:
                        self.trafficSummary?.todayBytes = totalBytes
                    case .thisMonth:
                        self.trafficSummary?.thisMonthBytes = totalBytes
                    case .thisYear:
                        self.trafficSummary?.thisYearBytes = totalBytes
                    case .global:
                        self.trafficSummary?.globalBytes = totalBytes
                    }
                    
                    self.isLoading = false
                }
                
            } catch {
                print("Traffic details parsing error for \(period):", error)
                DispatchQueue.main.async {
                    self.error = "Failed to parse traffic data"
                    self.isLoading = false
                }
            }
        }.resume()
    }

    func fetchHostTraffic() {
        // Only call for non-demo mode (demo data is handled in fetchDemoTrafficData)
        guard !isDemoMode else { return }
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/traffic") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data else { return }
            do {
                let raw = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]

                let list: [HostTraffic] = raw.compactMap { key, value in
                    guard let dict = value as? [String: Any],
                          let type = dict["type"] as? String else {
                        return nil
                    }
                    
                    // Handle different traffic types
                    if type == "gigabytes" {
                        let left = (dict["left"] as? Double) ?? 0.0
                        let limit = (dict["limit"] as? Double) ?? 0.0
                        let bytes = (dict["bytes"] as? Double) ?? 0.0
                        
                        // Calculate used from bytes downloaded, not from limit-left
                        let usedGB = bytes / 1073741824.0 // Convert bytes to GB
                        let limitGB = limit
                        
                        if usedGB > 0 || limitGB > 0 {
                            return HostTraffic(host: key, usedGB: usedGB, limitGB: limitGB)
                        }
                    } else if type == "links" {
                        let links = (dict["links"] as? Int) ?? 0
                        let limit = (dict["limit"] as? Int) ?? 0
                        
                        if links > 0 || limit > 0 {
                            // For links, we'll show as a percentage of limit
                            let usedPercentage = limit > 0 ? Double(links) / Double(limit) * 100 : 0
                            return HostTraffic(host: key, usedGB: usedPercentage, limitGB: 100.0)
                        }
                    }
                    
                    return nil
                }

                DispatchQueue.main.async {
                    self.trafficList = list.sorted { $0.usedGB > $1.usedGB }
                }

            } catch {
                print("Host traffic parsing error:", error)
                DispatchQueue.main.async {
                    self.trafficList = []
                }
            }
        }.resume()
    }

    func startAutoRefresh() {
        // Adjust refresh interval for demo mode
        let interval: TimeInterval = isDemoMode ? 60 : 300 // 1 minute for demo, 5 minutes for real
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            fetchTrafficData()
        }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        if bytes == 0 {
            return "0 B"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .decimal
        formatter.includesUnit = true
        formatter.isAdaptive = true
        
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Adaptive Colors
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.15) : Color.white
    }
    
    private var backgroundColorForScheme: Color {
        colorScheme == .dark ? Color.black.opacity(0.9) : Color.gray.opacity(0.05)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
}

// MARK: - Supporting Types

struct TrafficSummary {
    var todayBytes: Int64 = 0
    var thisMonthBytes: Int64 = 0
    var thisYearBytes: Int64 = 0
    var globalBytes: Int64 = 0
}

enum TrafficPeriod {
    case today, thisMonth, thisYear, global
}

struct TrafficRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            Text(title)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }
}
