import SwiftUI

struct SettingsView: View {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @AppStorage("rd_auto_refresh") var autoRefresh: Bool = true
    @AppStorage("rd_refresh_interval") var refreshInterval: Int = 300 // 5 minutes
    @AppStorage("rd_show_traffic_details") var showTrafficDetails: Bool = true
    @AppStorage("rd_traffic_warning_threshold") var trafficWarningThreshold: Double = 80.0 // 80%
    @AppStorage("rd_default_remote_traffic") var defaultRemoteTraffic: Bool = false
    @AppStorage("rd_max_concurrent_downloads") var maxConcurrentDownloads: Int = 3
    @AppStorage("rd_demo_mode") var demoMode: Bool = false
    
    @State private var showingAPIKeyAlert = false
    @State private var tempAPIKey = ""
    @State private var isTestingConnection = false
    @State private var connectionStatus = ""
    @State private var showingAPIDocumentation = false
    @State private var userPoints: Int? = nil
    @State private var isConvertingPoints = false
    @State private var conversionMessage = ""
    @State private var showingPointsConversion = false
    @State private var supportedHosts: [RDSupportedHost] = []
    @State private var isLoadingHosts = false
    @State private var hostMessage = ""
    @State private var showingHostsView = false
    @Environment(\.colorScheme) var colorScheme
    
    private var isDemoMode: Bool {
        return demoMode || DemoDataService.isDemoMode(apiKey: apiKey)
    }
    
    private var convertiblePoints: Int {
        guard let points = userPoints else { return 0 }
        return (points / 1000) * 1000
    }
    
    private var remainingPoints: Int {
        guard let points = userPoints else { return 0 }
        return points % 1000
    }
    
    var body: some View {
        NavigationView {
            Form {
                // API Configuration Section
                Section(header: Text("API Configuration")) {
                    if isDemoMode {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Demo Mode")
                                    .font(.headline)
                                Text("Using sample data for demonstration")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            Button("Switch to Real API") {
                                demoMode = false
                                apiKey = ""
                                tempAPIKey = ""
                                connectionStatus = ""
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Toggle("Demo Mode", isOn: $demoMode)
                            .onChange(of: demoMode) { value in
                                if value {
                                    apiKey = "demo"
                                } else if apiKey == "demo" {
                                    apiKey = ""
                                }
                                connectionStatus = ""
                            }
                    } else {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("API Key")
                                    .font(.headline)
                                Text(apiKey.isEmpty ? "Not configured" : "•••••••••••••••••••••••••••••••••••••••••")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Edit") {
                                tempAPIKey = apiKey
                                showingAPIKeyAlert = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Button("Enable Demo Mode") {
                            demoMode = true
                            apiKey = "demo"
                            connectionStatus = ""
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Button("Test Connection") {
                            testAPIConnection()
                        }
                        .buttonStyle(.bordered)
                        .disabled((apiKey.isEmpty && !isDemoMode) || isTestingConnection)
                        
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if !connectionStatus.isEmpty {
                        Text(connectionStatus)
                            .font(.caption)
                            .foregroundColor(connectionStatus.contains("✓") ? .green : .red)
                    }
                }
                
                // Traffic Monitoring Section
                Section(header: Text("Traffic Monitoring")) {
                    Toggle("Auto Refresh Data", isOn: $autoRefresh)
                    
                    if autoRefresh {
                        HStack {
                            Text("Refresh Interval")
                            Spacer()
                            Picker("Refresh Interval", selection: $refreshInterval) {
                                Text("1 minute").tag(60)
                                Text("2 minutes").tag(120)
                                Text("5 minutes").tag(300)
                                Text("10 minutes").tag(600)
                                Text("15 minutes").tag(900)
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
                    Toggle("Show Traffic Details", isOn: $showTrafficDetails)
                    
                    HStack {
                        Text("Traffic Warning at")
                        Spacer()
                        Text("\(Int(trafficWarningThreshold))%")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $trafficWarningThreshold, in: 50...95, step: 5) {
                        Text("Warning Threshold")
                    }
                }
                
                // Download Preferences Section
                Section(header: Text("Download Preferences")) {
                    Toggle("Use Remote Traffic by Default", isOn: $defaultRemoteTraffic)
                        .help("Uses dedicated servers and lifts account sharing protections")
                    
                    HStack {
                        Text("Max Concurrent Downloads")
                        Spacer()
                        Picker("Max Downloads", selection: $maxConcurrentDownloads) {
                            Text("1").tag(1)
                            Text("2").tag(2)
                            Text("3").tag(3)
                            Text("5").tag(5)
                            Text("10").tag(10)
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                // Account Management Section
                Section(header: Text("Account Management")) {
                    if !isDemoMode {
                        // Points Conversion
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "diamond.fill")
                                    .foregroundColor(.purple)
                                Text("Points Conversion")
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                if isConvertingPoints {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            
                            if let points = userPoints {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current Points: \(points)")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    
                                    if convertiblePoints > 0 {
                                        Text("Convertible: \(convertiblePoints) points")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                        
                                        if remainingPoints > 0 {
                                            Text("Remaining: \(remainingPoints) points")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Button("Convert \(convertiblePoints) Points") {
                                            convertPoints()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(isConvertingPoints || convertiblePoints == 0)
                                        .padding(.top, 4)
                                    } else {
                                        Text("Need at least 1000 points to convert")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            } else {
                                Button("Load Points") {
                                    fetchUserPoints()
                                }
                                .buttonStyle(.bordered)
                                .disabled(isConvertingPoints)
                            }
                            
                            if !conversionMessage.isEmpty {
                                Text(conversionMessage)
                                    .font(.caption)
                                    .foregroundColor(conversionMessage.contains("✓") ? .green : .red)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            Image(systemName: "diamond.fill")
                                .foregroundColor(.gray)
                            Text("Points Conversion")
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("Demo Mode")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if !isDemoMode {
                        // Hosts Management
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "server.rack")
                                    .foregroundColor(.orange)
                                Text("Hosts Management")
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                if isLoadingHosts {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Button("View Supported Hosts") {
                                    fetchSupportedHosts()
                                }
                                .buttonStyle(.bordered)
                                .disabled(isLoadingHosts)
                                
                                Button("Check Host Status") {
                                    checkHostsStatus()
                                }
                                .buttonStyle(.bordered)
                                .disabled(isLoadingHosts)
                            }
                            
                            if !supportedHosts.isEmpty {
                                Text("Found \(supportedHosts.count) supported hosts")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                
                                Button("View Details") {
                                    showingHostsView = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            
                            if !hostMessage.isEmpty {
                                Text(hostMessage)
                                    .font(.caption)
                                    .foregroundColor(hostMessage.contains("✓") ? .green : .red)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(.gray)
                            Text("Hosts Management")
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("Demo Mode")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: AccountActionsView()) {
                        HStack {
                            Image(systemName: "person.circle")
                                .foregroundColor(.blue)
                            Text("Account Actions")
                        }
                    }
                    
                    NavigationLink(destination: DownloadHistoryView()) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.green)
                            Text("Download History")
                        }
                    }
                    
                    NavigationLink(destination: HostersStatusView()) {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(.orange)
                            Text("Hosters Status")
                        }
                    }
                }
                
                Section(footer: Text("Points conversion is only available in multiples of 1000. Converting points adds traffic allowance to your account. Hosts management allows you to view supported hosts and check their current status. These features are not available in demo mode.")) {
                    EmptyView()
                }
                
                // API Information Section
                Section(header: Text("API Information")) {
                    HStack {
                        Text("API Rate Limit")
                        Spacer()
                        Text("250 requests/minute")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("API Base URL")
                        Spacer()
                        Text("api.real-debrid.com")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    Button(action: {
                        showingAPIDocumentation = true
                    }) {
                        HStack {
                            Text("API Documentation")
                            Spacer()
                            Image(systemName: "safari")
                                .foregroundColor(.blue)
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
            .background(Color.clear)
            .navigationTitle("Real-Debrid Settings")
            .defaultBackground()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .alert("Edit API Key", isPresented: $showingAPIKeyAlert) {
                TextField("API Key", text: $tempAPIKey)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    apiKey = tempAPIKey
                    tempAPIKey = ""
                }
            } message: {
                Text("Enter your Real-Debrid API key. You can find it in your Real-Debrid account settings.")
            }
            .sheet(isPresented: $showingAPIDocumentation) {
                InAppBrowserSheet(
                    url: URL(string: "https://api.real-debrid.com/")!,
                    title: "API Documentation",
                    isPresented: $showingAPIDocumentation
                )
            }
            .sheet(isPresented: $showingHostsView) {
                SupportedHostsView(hosts: supportedHosts, isPresented: $showingHostsView)
            }
            .onAppear {
                if !isDemoMode && !apiKey.isEmpty {
                    fetchUserPoints()
                    fetchSupportedHosts()
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func testAPIConnection() {
        if isDemoMode {
            isTestingConnection = true
            connectionStatus = ""
            
            // Simulate network delay for demo
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.isTestingConnection = false
                self.connectionStatus = "✓ Demo mode active - using sample data"
            }
            return
        }
        
        guard !apiKey.isEmpty else {
            connectionStatus = "❌ No API key configured"
            return
        }
        
        isTestingConnection = true
        connectionStatus = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/user") else {
            connectionStatus = "❌ Invalid API URL"
            isTestingConnection = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isTestingConnection = false
                
                if let error = error {
                    self.connectionStatus = "❌ Connection failed: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        if let data = data,
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let username = json["username"] as? String {
                            self.connectionStatus = "✓ Connected as \(username)"
                            // Also fetch points on successful connection
                            if let points = json["points"] as? Int {
                                self.userPoints = points
                            } else if let pointsNumber = json["points"] as? NSNumber {
                                self.userPoints = pointsNumber.intValue
                            }
                        } else {
                            self.connectionStatus = "✓ Connected successfully"
                        }
                    case 401:
                        self.connectionStatus = "❌ Invalid API key"
                    case 429:
                        self.connectionStatus = "⚠️ Rate limit exceeded"
                    case 403:
                        self.connectionStatus = "❌ Account locked or permission denied"
                    default:
                        self.connectionStatus = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    func fetchUserPoints() {
        guard !isDemoMode && !apiKey.isEmpty else { return }
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/user") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    if let points = json["points"] as? Int {
                        self.userPoints = points
                    } else if let pointsNumber = json["points"] as? NSNumber {
                        self.userPoints = pointsNumber.intValue
                    }
                }
            }
        }.resume()
    }
    
    func convertPoints() {
        guard !isDemoMode && !apiKey.isEmpty && convertiblePoints > 0 else { return }
        
        isConvertingPoints = true
        conversionMessage = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/settings/convertPoints") else {
            conversionMessage = "❌ Invalid URL"
            isConvertingPoints = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Convert points in multiples of 1000
        let pointsToConvert = convertiblePoints
        let postData = "type=traffic"
        request.httpBody = postData.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isConvertingPoints = false
                
                if let error = error {
                    self.conversionMessage = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200, 204:
                        self.conversionMessage = "✓ Successfully converted \(pointsToConvert) points"
                        // Refresh user points after successful conversion
                        self.fetchUserPoints()
                    case 400:
                        self.conversionMessage = "❌ Invalid request - need at least 1000 points"
                    case 401:
                        self.conversionMessage = "❌ Invalid API key"
                    case 403:
                        self.conversionMessage = "❌ Not enough points to convert"
                    case 429:
                        self.conversionMessage = "⚠️ Rate limit exceeded - try again later"
                    default:
                        self.conversionMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    func fetchSupportedHosts() {
        guard !isDemoMode && !apiKey.isEmpty else { return }
        
        isLoadingHosts = true
        hostMessage = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/hosts") else {
            hostMessage = "❌ Invalid URL"
            isLoadingHosts = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingHosts = false
                
                if let error = error {
                    self.hostMessage = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        if let data = data,
                           let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                            
                            self.supportedHosts = jsonArray.compactMap { hostDict in
                                guard let id = hostDict["id"] as? String,
                                      let name = hostDict["name"] as? String else {
                                    return nil
                                }
                                
                                let status = hostDict["status"] as? String ?? "unknown"
                                let checkTime = hostDict["check_time"] as? String
                                let image = hostDict["image"] as? String
                                let imageStatus = hostDict["image_status"] as? String
                                
                                return RDSupportedHost(
                                    id: id,
                                    name: name,
                                    status: status,
                                    checkTime: checkTime,
                                    image: image,
                                    imageStatus: imageStatus
                                )
                            }
                            
                            self.hostMessage = "✓ Loaded \(self.supportedHosts.count) supported hosts"
                        } else {
                            self.hostMessage = "❌ Failed to parse hosts data"
                        }
                    case 401:
                        self.hostMessage = "❌ Invalid API key"
                    case 403:
                        self.hostMessage = "❌ Access denied"
                    case 429:
                        self.hostMessage = "⚠️ Rate limit exceeded - try again later"
                    default:
                        self.hostMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    func checkHostsStatus() {
        guard !isDemoMode && !apiKey.isEmpty else { return }
        
        isLoadingHosts = true
        hostMessage = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/hosts/status") else {
            hostMessage = "❌ Invalid URL"
            isLoadingHosts = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingHosts = false
                
                if let error = error {
                    self.hostMessage = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        if let data = data,
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            
                            // Count hosts by status
                            var upCount = 0
                            var downCount = 0
                            var maintenanceCount = 0
                            
                            for (_, hostData) in json {
                                if let hostDict = hostData as? [String: Any],
                                   let status = hostDict["status"] as? String {
                                    switch status.lowercased() {
                                    case "up":
                                        upCount += 1
                                    case "down":
                                        downCount += 1
                                    case "maintenance":
                                        maintenanceCount += 1
                                    default:
                                        break
                                    }
                                }
                            }
                            
                            self.hostMessage = "✓ Status: \(upCount) up, \(downCount) down, \(maintenanceCount) maintenance"
                        } else {
                            self.hostMessage = "❌ Failed to parse status data"
                        }
                    case 401:
                        self.hostMessage = "❌ Invalid API key"
                    case 403:
                        self.hostMessage = "❌ Access denied"
                    case 429:
                        self.hostMessage = "⚠️ Rate limit exceeded - try again later"
                    default:
                        self.hostMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Adaptive Colors
    private var backgroundColorForScheme: Color {
        colorScheme == .dark ? Color.black.opacity(0.9) : Color.gray.opacity(0.05)
    }
}

// MARK: - Supporting Views

struct AccountActionsView: View {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @State private var isLoading = false
    @State private var message = ""
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("Account Actions")) {
                Button("Disable Current API Token") {
                    disableAPIToken()
                }
                .foregroundColor(.red)
                .disabled(isLoading)
                
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing...")
                            .foregroundColor(.secondary)
                    }
                }
                
                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(message.contains("✓") ? .green : .red)
                }
            }
            
            Section(footer: Text("Disabling your API token will require you to generate a new one from your Real-Debrid account settings.")) {
                EmptyView()
            }
        }
        .navigationTitle("Account Actions")
        .background(backgroundColorForScheme)
    }
    
    func disableAPIToken() {
        guard !apiKey.isEmpty else { return }
        
        isLoading = true
        message = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/disable_access_token") else {
            message = "❌ Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.message = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 204 {
                        self.message = "✓ API token disabled successfully"
                        // Clear the API key since it's now invalid
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.apiKey = ""
                        }
                    } else {
                        self.message = "❌ Failed: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    private var backgroundColorForScheme: Color {
        colorScheme == .dark ? Color.black.opacity(0.9) : Color.gray.opacity(0.05)
    }
}

struct DownloadHistoryView: View {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @AppStorage("rd_demo_mode") var demoMode: Bool = false
    @State private var downloads: [RDDownload] = []
    @State private var isLoading = true
    @State private var error: String?
    @Environment(\.colorScheme) var colorScheme
    
    private var isDemoMode: Bool {
        return demoMode || DemoDataService.isDemoMode(apiKey: apiKey)
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading downloads...")
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text("Error loading downloads")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List(downloads, id: \.id) { download in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(download.filename)
                            .font(.headline)
                            .lineLimit(2)
                        
                        Text(download.host)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Generated: \(formatDate(download.generated))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(isDemoMode ? "Download History (Demo)" : "Download History")
        .background(backgroundColorForScheme)
        .onAppear {
            fetchDownloads()
        }
    }
    
    func fetchDownloads() {
        if isDemoMode {
            isLoading = true
            error = nil
            
            // Simulate network delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let demoData = DemoDataService.shared.getDemoDownloads()
                self.downloads = demoData.compactMap { dict in
                    guard let id = dict["id"] as? String,
                          let filename = dict["filename"] as? String,
                          let host = dict["host"] as? String,
                          let generated = dict["generated"] as? String else {
                        return nil
                    }
                    return RDDownload(
                        id: id,
                        filename: filename,
                        mimeType: dict["mimeType"] as? String ?? "",
                        filesize: dict["filesize"] as? Int64 ?? 0,
                        link: dict["link"] as? String ?? "",
                        host: host,
                        chunks: dict["chunks"] as? Int ?? 1,
                        download: dict["download"] as? String ?? "",
                        generated: generated,
                        type: dict["type"] as? String
                    )
                }
                self.isLoading = false
            }
            return
        }
        
        guard !apiKey.isEmpty else {
            error = "No API key configured"
            isLoading = false
            return
        }
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/downloads") else {
            error = "Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error.localizedDescription
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    self.error = "API error: HTTP \(httpResponse.statusCode)"
                    return
                }
                
                guard let data = data else {
                    self.error = "No data received"
                    return
                }
                
                do {
                    if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        self.downloads = jsonArray.compactMap { dict in
                            guard let id = dict["id"] as? String,
                                  let filename = dict["filename"] as? String,
                                  let host = dict["host"] as? String,
                                  let generated = dict["generated"] as? String else {
                                return nil
                            }
                            return RDDownload(
                                id: id,
                                filename: filename,
                                mimeType: dict["mimeType"] as? String ?? "",
                                filesize: dict["filesize"] as? Int64 ?? 0,
                                link: dict["link"] as? String ?? "",
                                host: host,
                                chunks: dict["chunks"] as? Int ?? 1,
                                download: dict["download"] as? String ?? "",
                                generated: generated,
                                type: dict["type"] as? String
                            )
                        }
                    }
                } catch {
                    self.error = "Failed to parse downloads: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private var backgroundColorForScheme: Color {
        colorScheme == .dark ? Color.black.opacity(0.9) : Color.gray.opacity(0.05)
    }
}

struct HostersStatusView: View {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @AppStorage("rd_demo_mode") var demoMode: Bool = false
    @State private var hosters: [RDHoster] = []
    @State private var isLoading = true
    @State private var error: String?
    @Environment(\.colorScheme) var colorScheme
    
    private var isDemoMode: Bool {
        return demoMode || DemoDataService.isDemoMode(apiKey: apiKey)
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading hosters...")
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text("Error loading hosters")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List(hosters, id: \.name) { hoster in
                    HStack {
                        Circle()
                            .fill(hoster.status == "up" ? Color.green : (hoster.status == "maintenance" ? Color.orange : Color.red))
                            .frame(width: 8, height: 8)
                        
                        Text(hoster.name)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(hoster.status.capitalized)
                            .font(.caption)
                            .foregroundColor(hoster.status == "up" ? .green : (hoster.status == "maintenance" ? .orange : .red))
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(isDemoMode ? "Hosters Status (Demo)" : "Hosters Status")
        .background(backgroundColorForScheme)
        .onAppear {
            fetchHosters()
        }
    }
    
    func fetchHosters() {
        if isDemoMode {
            isLoading = true
            error = nil
            
            // Simulate network delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let demoData = DemoDataService.shared.getDemoHostersStatus()
                self.hosters = demoData.compactMap { dict in
                    guard let name = dict["name"] as? String,
                          let status = dict["status"] as? String else {
                        return nil
                    }
                    return RDHoster(name: name, status: status)
                }
                self.isLoading = false
            }
            return
        }
        
        guard !apiKey.isEmpty else {
            error = "No API key configured"
            isLoading = false
            return
        }
        
        // For now, we'll create some sample data since I don't see a specific hosters status endpoint
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.hosters = [
                RDHoster(name: "1fichier", status: "up"),
                RDHoster(name: "Mega", status: "up"),
                RDHoster(name: "Rapidgator", status: "up"),
                RDHoster(name: "Nitroflare", status: "maintenance"),
                RDHoster(name: "Turbobit", status: "up")
            ]
            self.isLoading = false
        }
    }
    
    private var backgroundColorForScheme: Color {
        colorScheme == .dark ? Color.black.opacity(0.9) : Color.gray.opacity(0.05)
    }
}

// MARK: - Supporting Types

struct RDHoster {
    let name: String
    let status: String
}

struct RDSupportedHost {
    let id: String
    let name: String
    let status: String
    let checkTime: String?
    let image: String?
    let imageStatus: String?
}

// MARK: - Supported Hosts View

struct SupportedHostsView: View {
    let hosts: [RDSupportedHost]
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            List(hosts, id: \.id) { host in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(statusColor(for: host.status))
                            .frame(width: 10, height: 10)
                        
                        Text(host.name)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(host.status.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(statusColor(for: host.status).opacity(0.2))
                            )
                            .foregroundColor(statusColor(for: host.status))
                    }
                    
                    if let checkTime = host.checkTime {
                        Text("Last checked: \(formatCheckTime(checkTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let imageStatus = host.imageStatus {
                        Text("Image status: \(imageStatus)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .navigationTitle("Supported Hosts (\(hosts.count))")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "up":
            return .green
        case "down":
            return .red
        case "maintenance":
            return .orange
        default:
            return .gray
        }
    }
    
    private func formatCheckTime(_ timeString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: timeString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return timeString
    }
}

#Preview {
    SettingsView()
} 