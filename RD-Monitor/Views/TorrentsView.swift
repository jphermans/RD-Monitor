import SwiftUI

struct TorrentsView: View {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @AppStorage("rd_demo_mode") var demoMode: Bool = false
    @State private var torrents: [RDTorrent] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showingAddTorrent = false
    @State private var showingAddMagnet = false
    @State private var newTorrentURL = ""
    @State private var newMagnetLink = ""
    @State private var isAddingTorrent = false
    @State private var addMessage = ""
    @State private var refreshTimer: Timer?
    @Environment(\.colorScheme) var colorScheme
    
    private var isDemoMode: Bool {
        return demoMode || DemoDataService.isDemoMode(apiKey: apiKey)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isDemoMode {
                    // Demo mode indicator
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Torrents Not Available")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Torrent management is only available in real mode with a valid Real-Debrid API key.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Go to Settings") {
                            // This would switch to settings tab, but for now just a button
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColorForScheme)
                } else {
                    // Real mode torrent management
                    if isLoading {
                        ProgressView("Loading torrents...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = error {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            
                            Text("Error Loading Torrents")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(error)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Retry") {
                                fetchTorrents()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Torrents list
                        List {
                            Section(header: HStack {
                                Text("Active Torrents (\(torrents.count))")
                                Spacer()
                                Button("Refresh") {
                                    fetchTorrents()
                                }
                                .font(.caption)
                            }) {
                                if torrents.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "tray")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                        Text("No active torrents")
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                } else {
                                    ForEach(torrents, id: \.id) { torrent in
                                        NavigationLink(destination: TorrentDetailView(torrent: torrent)) {
                                            TorrentRowView(torrent: torrent) {
                                                // Delete action
                                                deleteTorrent(torrent.id)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .background(Color.clear)
                        .refreshable {
                            fetchTorrents()
                        }
                    }
                }
            }
            .navigationTitle("Torrents")
            .defaultBackground()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if !isDemoMode {
                    #if os(iOS)
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: { showingAddTorrent = true }) {
                                Label("Add Torrent File", systemImage: "doc.badge.plus")
                            }
                            
                            Button(action: { showingAddMagnet = true }) {
                                Label("Add Magnet Link", systemImage: "link.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    #else
                    ToolbarItemGroup(placement: .primaryAction) {
                        Menu {
                            Button(action: { showingAddTorrent = true }) {
                                Label("Add Torrent File", systemImage: "doc.badge.plus")
                            }
                            
                            Button(action: { showingAddMagnet = true }) {
                                Label("Add Magnet Link", systemImage: "link.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    #endif
                }
            }
            .onAppear {
                if !isDemoMode {
                    fetchTorrents()
                    startAutoRefresh()
                }
            }
            .onDisappear {
                stopAutoRefresh()
            }
            .alert("Add Torrent File", isPresented: $showingAddTorrent) {
                TextField("Torrent file URL", text: $newTorrentURL)
                Button("Cancel", role: .cancel) { 
                    newTorrentURL = ""
                }
                Button("Add") {
                    addTorrentFromURL()
                }
                .disabled(newTorrentURL.isEmpty)
            } message: {
                Text("Enter the URL of a torrent file to add it to your Real-Debrid account.")
            }
            .alert("Add Magnet Link", isPresented: $showingAddMagnet) {
                TextField("Magnet link", text: $newMagnetLink)
                Button("Cancel", role: .cancel) { 
                    newMagnetLink = ""
                }
                Button("Add") {
                    addMagnetLink()
                }
                .disabled(newMagnetLink.isEmpty)
            } message: {
                Text("Enter a magnet link to add it to your Real-Debrid account.")
            }
        }
    }
    
    // MARK: - API Functions
    
    func fetchTorrents() {
        guard !isDemoMode && !apiKey.isEmpty else { return }
        
        isLoading = true
        error = nil
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents") else {
            error = "Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, requestError in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = requestError {
                    self.error = "Network error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        if let data = data {
                            self.parseTorrentsResponse(data)
                        } else {
                            self.error = "No data received"
                        }
                    case 401:
                        self.error = "Invalid API key"
                    case 403:
                        self.error = "Access denied - check your account status"
                    case 429:
                        self.error = "Rate limit exceeded - please wait"
                    default:
                        self.error = "API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    func parseTorrentsResponse(_ data: Data) {
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                self.torrents = jsonArray.compactMap { dict in
                    guard let id = dict["id"] as? String,
                          let filename = dict["filename"] as? String,
                          let status = dict["status"] as? String else {
                        return nil
                    }
                    
                    let hash = dict["hash"] as? String ?? ""
                    let bytes = (dict["bytes"] as? Int64) ?? 0
                    let originalBytes = (dict["original_bytes"] as? Int64) ?? 0
                    let host = dict["host"] as? String ?? "Real-Debrid"
                    let split = dict["split"] as? Int ?? 1
                    let progress = dict["progress"] as? Int ?? 0
                    let added = dict["added"] as? String ?? ""
                    let ended = dict["ended"] as? String
                    let speed = (dict["speed"] as? Int64) ?? 0
                    let seeders = dict["seeders"] as? Int ?? 0
                    
                    // Parse files array
                    var files: [RDTorrentFile] = []
                    if let filesArray = dict["files"] as? [[String: Any]] {
                        files = filesArray.compactMap { fileDict in
                            guard let fileId = fileDict["id"] as? Int,
                                  let path = fileDict["path"] as? String,
                                  let bytes = fileDict["bytes"] as? Int64,
                                  let selected = fileDict["selected"] as? Int else {
                                return nil
                            }
                            return RDTorrentFile(id: fileId, path: path, bytes: bytes, selected: selected == 1)
                        }
                    }
                    
                    // Parse links array
                    var links: [String] = []
                    if let linksArray = dict["links"] as? [String] {
                        links = linksArray
                    }
                    
                    return RDTorrent(
                        id: id,
                        filename: filename,
                        originalFilename: dict["original_filename"] as? String,
                        hash: hash,
                        bytes: bytes,
                        originalBytes: originalBytes,
                        host: host,
                        split: split,
                        progress: progress,
                        status: status,
                        added: added,
                        files: files,
                        links: links,
                        ended: ended,
                        speed: speed,
                        seeders: seeders
                    )
                }
            } else {
                self.error = "Invalid response format"
            }
        } catch {
            self.error = "Failed to parse response: \(error.localizedDescription)"
        }
    }
    
    func addTorrentFromURL() {
        guard !newTorrentURL.isEmpty else { return }
        
        isAddingTorrent = true
        addMessage = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/addTorrent") else {
            addMessage = "❌ Invalid URL"
            isAddingTorrent = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // For simplicity, we'll use the URL method - in a real implementation,
        // you'd want to download and upload the actual torrent file
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // This is a simplified implementation - real torrent file upload would be more complex
        let postData = "--\(boundary)\r\nContent-Disposition: form-data; name=\"url\"\r\n\r\n\(newTorrentURL)\r\n--\(boundary)--\r\n"
        request.httpBody = postData.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isAddingTorrent = false
                
                if let error = error {
                    self.addMessage = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 201, 200:
                        self.addMessage = "✓ Torrent added successfully"
                        self.newTorrentURL = ""
                        // Refresh torrents list
                        self.fetchTorrents()
                    case 400:
                        self.addMessage = "❌ Invalid torrent file"
                    case 401:
                        self.addMessage = "❌ Invalid API key"
                    case 403:
                        self.addMessage = "❌ Access denied or quota exceeded"
                    case 429:
                        self.addMessage = "⚠️ Rate limit exceeded"
                    default:
                        self.addMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    func addMagnetLink() {
        guard !newMagnetLink.isEmpty else { return }
        
        isAddingTorrent = true
        addMessage = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/addMagnet") else {
            addMessage = "❌ Invalid URL"
            isAddingTorrent = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let postData = "magnet=\(newMagnetLink.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = postData.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isAddingTorrent = false
                
                if let error = error {
                    self.addMessage = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 201, 200:
                        self.addMessage = "✓ Magnet link added successfully"
                        self.newMagnetLink = ""
                        // Refresh torrents list
                        self.fetchTorrents()
                    case 400:
                        self.addMessage = "❌ Invalid magnet link"
                    case 401:
                        self.addMessage = "❌ Invalid API key"
                    case 403:
                        self.addMessage = "❌ Access denied or quota exceeded"
                    case 429:
                        self.addMessage = "⚠️ Rate limit exceeded"
                    default:
                        self.addMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    func deleteTorrent(_ torrentId: String) {
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/delete/\(torrentId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 {
                    // Successfully deleted, refresh the list
                    self.fetchTorrents()
                }
            }
        }.resume()
    }
    
    func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            fetchTorrents()
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Adaptive Colors
    private var backgroundColorForScheme: Color {
        colorScheme == .dark ? Color.black.opacity(0.9) : Color.gray.opacity(0.05)
    }
}

// MARK: - Torrent Row View

struct TorrentRowView: View {
    let torrent: RDTorrent
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with name and status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(torrent.filename)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let originalFilename = torrent.originalFilename {
                        Text("Original: \(originalFilename)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    StatusBadge(status: torrent.status)
                    
                    Text("\(torrent.progress)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            
            // Progress bar
            ProgressView(value: Double(torrent.progress), total: 100)
                .accentColor(statusColor(for: torrent.status))
            
            // Details
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Size: \(formatBytes(torrent.bytes))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if torrent.speed > 0 {
                        Text("Speed: \(formatBytes(torrent.speed))/s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Files: \(torrent.files.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if torrent.seeders > 0 {
                        Text("Seeders: \(torrent.seeders)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Action buttons
            HStack {
                if !torrent.links.isEmpty {
                    Button("Download Links (\(torrent.links.count))") {
                        // Show download links
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button("Delete") {
                    onDelete()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "downloaded":
            return .green
        case "downloading":
            return .blue
        case "waiting":
            return .orange
        case "error":
            return .red
        default:
            return .gray
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .decimal
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(statusColor.opacity(0.2))
            )
            .foregroundColor(statusColor)
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "downloaded":
            return .green
        case "downloading":
            return .blue
        case "waiting":
            return .orange
        case "error":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Supporting Types

struct RDTorrent {
    let id: String
    let filename: String
    let originalFilename: String?
    let hash: String
    let bytes: Int64
    let originalBytes: Int64
    let host: String
    let split: Int
    let progress: Int
    let status: String
    let added: String
    let files: [RDTorrentFile]
    let links: [String]
    let ended: String?
    let speed: Int64
    let seeders: Int
}

struct RDTorrentFile {
    let id: Int
    let path: String
    let bytes: Int64
    let selected: Bool
}

#Preview {
    TorrentsView()
} 