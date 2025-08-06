import SwiftUI

struct TorrentDetailView: View {
    let torrent: RDTorrent
    @AppStorage("rd_api_key") var apiKey: String = ""
    @State private var isLoading = false
    @State private var message = ""
    @State private var selectedFiles: Set<Int> = []
    @State private var showingLinks = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(torrent.filename)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let originalFilename = torrent.originalFilename {
                            Text("Original: \(originalFilename)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        StatusBadge(status: torrent.status)
                    }
                    
                    // Progress Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Progress")
                                .font(.headline)
                            Spacer()
                            Text("\(torrent.progress)%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        ProgressView(value: Double(torrent.progress), total: 100)
                            .accentColor(statusColor(for: torrent.status))
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Size: \(formatBytes(torrent.bytes))")
                                if torrent.speed > 0 {
                                    Text("Speed: \(formatBytes(torrent.speed))/s")
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Seeders: \(torrent.seeders)")
                                Text("Added: \(formatDate(torrent.added))")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    // Files Section
                    if !torrent.files.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Files (\(torrent.files.count))")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if selectedFiles.count > 0 {
                                    Button("Select Files") {
                                        selectTorrentFiles()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(isLoading)
                                }
                            }
                            
                            ForEach(Array(torrent.files.enumerated()), id: \.offset) { index, file in
                                FileRowView(
                                    file: file,
                                    isSelected: selectedFiles.contains(file.id)
                                ) { selected in
                                    if selected {
                                        selectedFiles.insert(file.id)
                                    } else {
                                        selectedFiles.remove(file.id)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Download Links Section
                    if !torrent.links.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Download Links (\(torrent.links.count))")
                                .font(.headline)
                            
                            ForEach(Array(torrent.links.enumerated()), id: \.offset) { index, link in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Link \(index + 1)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(link)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Copy") {
                                        #if os(iOS)
                                        UIPasteboard.general.string = link
                                        #elseif os(macOS)
                                        NSPasteboard.general.setString(link, forType: .string)
                                        #endif
                                        message = "Link copied to clipboard"
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                }
                                .padding(.vertical, 4)
                                
                                if index < torrent.links.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    
                    // Actions Section
                    VStack(spacing: 12) {
                        if torrent.status.lowercased() == "waiting" {
                            Button("Start Download") {
                                startTorrentDownload()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading)
                        }
                        
                        Button("Delete Torrent") {
                            deleteTorrent()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        .disabled(isLoading)
                    }
                    
                    // Message
                    if !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(message.contains("✓") ? .green : .red)
                    }
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Torrent Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .background(backgroundColorForScheme)
        .onAppear {
            // Pre-select already selected files
            selectedFiles = Set(torrent.files.filter { $0.selected }.map { $0.id })
        }
    }
    
    // MARK: - API Functions
    
    func selectTorrentFiles() {
        guard !apiKey.isEmpty && !selectedFiles.isEmpty else { return }
        
        isLoading = true
        message = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/selectFiles/\(torrent.id)") else {
            message = "❌ Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let fileIds = selectedFiles.map { String($0) }.joined(separator: ",")
        let postData = "files=\(fileIds)"
        request.httpBody = postData.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.message = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 204, 200:
                        self.message = "✓ Files selected successfully"
                    case 400:
                        self.message = "❌ Invalid file selection"
                    case 401:
                        self.message = "❌ Invalid API key"
                    case 403:
                        self.message = "❌ Access denied"
                    case 429:
                        self.message = "⚠️ Rate limit exceeded"
                    default:
                        self.message = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    func startTorrentDownload() {
        guard !apiKey.isEmpty else { return }
        
        isLoading = true
        message = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/info/\(torrent.id)") else {
            message = "❌ Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.message = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        self.message = "✓ Torrent processing initiated"
                    case 401:
                        self.message = "❌ Invalid API key"
                    case 403:
                        self.message = "❌ Access denied"
                    case 404:
                        self.message = "❌ Torrent not found"
                    case 429:
                        self.message = "⚠️ Rate limit exceeded"
                    default:
                        self.message = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    func deleteTorrent() {
        guard !apiKey.isEmpty else { return }
        
        isLoading = true
        message = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/torrents/delete/\(torrent.id)") else {
            message = "❌ Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.message = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 204:
                        self.message = "✓ Torrent deleted successfully"
                        // Close the detail view after successful deletion
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    case 401:
                        self.message = "❌ Invalid API key"
                    case 403:
                        self.message = "❌ Access denied"
                    case 404:
                        self.message = "❌ Torrent not found"
                    case 429:
                        self.message = "⚠️ Rate limit exceeded"
                    default:
                        self.message = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Helper Functions
    
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
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private var backgroundColorForScheme: Color {
        colorScheme == .dark ? Color.black.opacity(0.9) : Color.gray.opacity(0.05)
    }
}

// MARK: - File Row View

struct FileRowView: View {
    let file: RDTorrentFile
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                onToggle(!isSelected)
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: file.path).lastPathComponent)
                    .font(.subheadline)
                    .lineLimit(2)
                
                Text("\(ByteCountFormatter().string(fromByteCount: file.bytes)) • \(file.path)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TorrentDetailView(torrent: RDTorrent(
        id: "1",
        filename: "Sample.Torrent.1080p.mkv",
        originalFilename: "Sample Torrent 1080p.mkv",
        hash: "abc123",
        bytes: 1073741824,
        originalBytes: 1073741824,
        host: "Real-Debrid",
        split: 1,
        progress: 75,
        status: "downloading",
        added: "2024-01-01T12:00:00Z",
        files: [
            RDTorrentFile(id: 1, path: "/Sample.Torrent.1080p.mkv", bytes: 1073741824, selected: true),
            RDTorrentFile(id: 2, path: "/Sample.Torrent.1080p.srt", bytes: 50000, selected: false)
        ],
        links: ["https://download.real-debrid.com/sample1"],
        ended: nil,
        speed: 5242880,
        seeders: 10
    ))
} 