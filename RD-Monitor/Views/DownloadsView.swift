import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct DownloadsView: View {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @AppStorage("rd_demo_mode") var demoMode: Bool = false
    
    @State private var downloads: [RDDownload] = []
    @State private var isLoading = false
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var hasMorePages = false
    @State private var statusMessage = ""
    @State private var searchText = ""
    @State private var selectedDownloads = Set<String>()
    @State private var showingDeleteAlert = false
    @State private var downloadToDelete: RDDownload?
    @State private var showingBulkDeleteAlert = false
    
    private let itemsPerPage = 50
    
    @Environment(\.colorScheme) var colorScheme
    
    private var isDemoMode: Bool {
        return demoMode || DemoDataService.isDemoMode(apiKey: apiKey)
    }
    
    private var filteredDownloads: [RDDownload] {
        if searchText.isEmpty {
            return downloads
        } else {
            return downloads.filter { download in
                download.filename.localizedCaseInsensitiveContains(searchText) ||
                download.host.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isDemoMode {
                    DemoModeIndicator()
                } else {
                    VStack(spacing: 0) {
                        // Search and controls
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                TextField("Search downloads...", text: $searchText)
                                    .textFieldStyle(.roundedBorder)
                                
                                if !selectedDownloads.isEmpty {
                                    Button("Download (\(selectedDownloads.count))") {
                                        downloadSelectedFiles()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    
                                    Button("Delete Selected") {
                                        showingBulkDeleteAlert = true
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .foregroundColor(.red)
                                }
                            }
                            
                            // Page info and controls
                            HStack {
                                Text("\(downloads.count) downloads")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if totalPages > 1 {
                                    HStack(spacing: 8) {
                                        Button("Previous") {
                                            loadPreviousPage()
                                        }
                                        .disabled(currentPage <= 1 || isLoading)
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        
                                        Text("Page \(currentPage) of \(totalPages)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Button("Next") {
                                            loadNextPage()
                                        }
                                        .disabled(!hasMorePages || isLoading)
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                                
                                Button("Refresh") {
                                    refreshDownloads()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(isLoading)
                                
                                if !filteredDownloads.isEmpty && !isDemoMode {
                                    Button("Download All") {
                                        downloadAllFiles()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                        }
                        .padding()
                        
                        Divider()
                        
                        // Downloads list
                        if isLoading && downloads.isEmpty {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Loading downloads...")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if filteredDownloads.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "tray")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text(searchText.isEmpty ? "No Downloads" : "No Matching Downloads")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                
                                Text(searchText.isEmpty ? "Your download history will appear here" : "Try adjusting your search")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List {
                                ForEach(filteredDownloads, id: \.id) { download in
                                    DownloadRowView(
                                        download: download,
                                        isSelected: selectedDownloads.contains(download.id),
                                        onSelectionToggle: { toggleSelection(download.id) },
                                        onDelete: { 
                                            downloadToDelete = download
                                            showingDeleteAlert = true
                                        }
                                    )
                                }
                            }
                            .listStyle(.plain)
                            .refreshable {
                                await refreshDownloadsAsync()
                            }
                        }
                        
                        // Status message
                        if !statusMessage.isEmpty {
                            HStack {
                                Text(statusMessage)
                                    .font(.caption)
                                    .foregroundColor(statusMessage.contains("✓") ? .green : 
                                                   statusMessage.contains("❌") ? .red : .secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            .defaultBackground()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .background(backgroundColorForScheme)
            .onAppear {
                if !isDemoMode {
                    loadDownloads()
                }
            }
            .alert("Delete Download", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let download = downloadToDelete {
                        deleteDownload(download)
                    }
                }
            } message: {
                if let download = downloadToDelete {
                    Text("Are you sure you want to delete '\(download.filename)' from your downloads list?")
                }
            }
            .alert("Delete Selected Downloads", isPresented: $showingBulkDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete \(selectedDownloads.count) Downloads", role: .destructive) {
                    deleteBulkDownloads()
                }
            } message: {
                Text("Are you sure you want to delete \(selectedDownloads.count) downloads from your list?")
            }
        }
    }
    
    // MARK: - Demo Mode Indicator
    
    private func DemoModeIndicator() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Downloads Not Available")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Download history is only available in real mode with a valid Real-Debrid API key.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Go to Settings") {
                // This would switch to settings tab
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColorForScheme)
    }
    
    // MARK: - API Functions
    
    func loadDownloads() {
        guard !isDemoMode else { return }
        
        isLoading = true
        statusMessage = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/downloads?page=\(currentPage)&limit=\(itemsPerPage)") else {
            statusMessage = "❌ Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.statusMessage = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    // Extract total count from headers if available
                    if let totalCountHeader = httpResponse.value(forHTTPHeaderField: "X-Total-Count"),
                       let totalCount = Int(totalCountHeader) {
                        self.totalPages = max(1, (totalCount + self.itemsPerPage - 1) / self.itemsPerPage)
                        self.hasMorePages = self.currentPage < self.totalPages
                    }
                    
                    switch httpResponse.statusCode {
                    case 200:
                        if let data = data {
                            self.parseDownloads(data)
                        } else {
                            self.statusMessage = "❌ No data received"
                        }
                    case 401:
                        self.statusMessage = "❌ Invalid API key"
                    case 403:
                        self.statusMessage = "❌ Permission denied"
                    case 429:
                        self.statusMessage = "⚠️ Rate limit exceeded"
                    default:
                        self.statusMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    func loadDownloadsWithCompletion(completion: @escaping () -> Void) {
        guard !isDemoMode else { 
            completion()
            return 
        }
        
        isLoading = true
        statusMessage = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/downloads?page=\(currentPage)&limit=\(itemsPerPage)") else {
            statusMessage = "❌ Invalid URL"
            isLoading = false
            completion()
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.statusMessage = "❌ Error: \(error.localizedDescription)"
                    completion()
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    // Extract total count from headers if available
                    if let totalCountHeader = httpResponse.value(forHTTPHeaderField: "X-Total-Count"),
                       let totalCount = Int(totalCountHeader) {
                        self.totalPages = max(1, (totalCount + self.itemsPerPage - 1) / self.itemsPerPage)
                        self.hasMorePages = self.currentPage < self.totalPages
                    }
                    
                    switch httpResponse.statusCode {
                    case 200:
                        if let data = data {
                            self.parseDownloads(data)
                        } else {
                            self.statusMessage = "❌ No data received"
                        }
                    case 401:
                        self.statusMessage = "❌ Invalid API key"
                    case 403:
                        self.statusMessage = "❌ Permission denied"
                    case 429:
                        self.statusMessage = "⚠️ Rate limit exceeded"
                    default:
                        self.statusMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
                
                completion()
            }
        }.resume()
    }
    
    func deleteDownload(_ download: RDDownload) {
        guard !isDemoMode else { return }
        
        isLoading = true
        statusMessage = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/downloads/delete/\(download.id)") else {
            statusMessage = "❌ Invalid URL"
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
                    self.statusMessage = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 204:
                        self.statusMessage = "✓ Download deleted successfully"
                        self.downloads.removeAll { $0.id == download.id }
                        self.selectedDownloads.remove(download.id)
                    case 401:
                        self.statusMessage = "❌ Invalid API key"
                    case 403:
                        self.statusMessage = "❌ Permission denied"
                    case 404:
                        self.statusMessage = "❌ Download not found"
                    case 429:
                        self.statusMessage = "⚠️ Rate limit exceeded"
                    default:
                        self.statusMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Helper Functions
    
    func parseDownloads(_ data: Data) {
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let newDownloads = jsonArray.compactMap { dict -> RDDownload? in
                    guard let id = dict["id"] as? String,
                          let filename = dict["filename"] as? String,
                          let link = dict["link"] as? String,
                          let host = dict["host"] as? String,
                          let download = dict["download"] as? String,
                          let generated = dict["generated"] as? String else {
                        return nil
                    }
                    
                    return RDDownload(
                        id: id,
                        filename: filename,
                        mimeType: dict["mimeType"] as? String ?? "",
                        filesize: dict["filesize"] as? Int64 ?? 0,
                        link: link,
                        host: host,
                        chunks: dict["chunks"] as? Int ?? 1,
                        download: download,
                        generated: generated,
                        type: dict["type"] as? String
                    )
                }
                
                if currentPage == 1 {
                    downloads = newDownloads
                } else {
                    downloads.append(contentsOf: newDownloads)
                }
                
                statusMessage = "✓ Loaded \(newDownloads.count) downloads"
                
                // Auto-clear status message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self.statusMessage.contains("✓") {
                        self.statusMessage = ""
                    }
                }
            } else {
                statusMessage = "❌ Failed to parse downloads"
            }
        } catch {
            statusMessage = "❌ Failed to parse downloads: \(error.localizedDescription)"
        }
    }
    
    func refreshDownloads() {
        currentPage = 1
        downloads.removeAll()
        selectedDownloads.removeAll()
        loadDownloads()
    }
    
    @MainActor
    func refreshDownloadsAsync() async {
        currentPage = 1
        downloads.removeAll()
        selectedDownloads.removeAll()
        
        await withCheckedContinuation { continuation in
            loadDownloadsWithCompletion {
                continuation.resume()
            }
        }
    }
    
    func loadNextPage() {
        guard hasMorePages && !isLoading else { return }
        currentPage += 1
        loadDownloads()
    }
    
    func loadPreviousPage() {
        guard currentPage > 1 && !isLoading else { return }
        currentPage -= 1
        loadDownloads()
    }
    
    func toggleSelection(_ downloadId: String) {
        if selectedDownloads.contains(downloadId) {
            selectedDownloads.remove(downloadId)
        } else {
            selectedDownloads.insert(downloadId)
        }
    }
    
    func deleteBulkDownloads() {
        let downloadsToDelete = downloads.filter { selectedDownloads.contains($0.id) }
        
        for download in downloadsToDelete {
            deleteDownload(download)
        }
        
        selectedDownloads.removeAll()
    }
    
    func downloadSelectedFiles() {
        let downloadsToDownload = downloads.filter { selectedDownloads.contains($0.id) }
        
        guard !downloadsToDownload.isEmpty else { return }
        
        statusMessage = "⬇️ Starting \(downloadsToDownload.count) download(s)..."
        
        #if os(iOS)
        // For iOS, download files directly using URLSession
        downloadMultipleFilesDirectly(downloads: downloadsToDownload)
        #elseif os(macOS)
        // For macOS, open URLs directly
        var openedCount = 0
        for download in downloadsToDownload {
            if let url = URL(string: download.download) {
                NSWorkspace.shared.open(url)
                openedCount += 1
            }
        }
        
        statusMessage = "✓ Started \(openedCount) download(s)"
        
        // Auto-clear status message after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.statusMessage.contains("✓") {
                self.statusMessage = ""
            }
        }
        #endif
        
        // Deselect all after downloading
        selectedDownloads.removeAll()
    }
    
    func downloadAllFiles() {
        let downloadsToDownload = filteredDownloads
        
        guard !downloadsToDownload.isEmpty else { return }
        
        statusMessage = "⬇️ Starting \(downloadsToDownload.count) download(s)..."
        
        #if os(iOS)
        // For iOS, download files directly using URLSession
        downloadMultipleFilesDirectly(downloads: downloadsToDownload)
        #elseif os(macOS)
        // For macOS, open URLs directly
        var openedCount = 0
        for download in downloadsToDownload {
            if let url = URL(string: download.download) {
                NSWorkspace.shared.open(url)
                openedCount += 1
            }
        }
        
        statusMessage = "✓ Started \(openedCount) download(s)"
        
        // Auto-clear status message after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.statusMessage.contains("✓") {
                self.statusMessage = ""
            }
        }
        #endif
    }
    
    #if os(iOS)
    func downloadMultipleFilesDirectly(downloads: [RDDownload]) {
        var successCount = 0
        var failCount = 0
        let totalCount = downloads.count
        
        // Download files with a small delay between each
        for (index, download) in downloads.enumerated() {
            guard let url = URL(string: download.download) else {
                failCount += 1
                continue
            }
            
            // Add delay between downloads to avoid overwhelming the system
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 1.0) {
                let downloadTask = URLSession.shared.downloadTask(with: url) { localURL, response, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            failCount += 1
                            print("Download failed for \(download.filename): \(error.localizedDescription)")
                        } else if let localURL = localURL {
                            // Save to Documents directory
                            self.saveBulkDownloadToFilesApp(localURL: localURL, filename: download.filename) { success in
                                if success {
                                    successCount += 1
                                } else {
                                    failCount += 1
                                }
                                
                                // Update status when all downloads are processed
                                if successCount + failCount == totalCount {
                                    if failCount == 0 {
                                        self.statusMessage = "✓ Downloaded \(successCount) file(s) to Files app"
                                    } else {
                                        self.statusMessage = "⚠️ Downloaded \(successCount), failed \(failCount)"
                                    }
                                    
                                    // Auto-clear status message after 5 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                        if self.statusMessage.contains("✓") || self.statusMessage.contains("⚠️") {
                                            self.statusMessage = ""
                                        }
                                    }
                                }
                            }
                        } else {
                            failCount += 1
                        }
                    }
                }
                
                downloadTask.resume()
            }
        }
    }
    
    func saveBulkDownloadToFilesApp(localURL: URL, filename: String, completion: @escaping (Bool) -> Void) {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(false)
            return
        }
        
        let destinationURL = documentsURL.appendingPathComponent(filename)
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Move downloaded file to Documents directory
            try FileManager.default.moveItem(at: localURL, to: destinationURL)
            completion(true)
        } catch {
            print("Failed to save \(filename): \(error.localizedDescription)")
            completion(false)
        }
    }
    #endif
    
    // MARK: - Adaptive Colors
    private var backgroundColorForScheme: Color {
        colorScheme == .dark ? Color.black.opacity(0.9) : Color.gray.opacity(0.05)
    }
}

// MARK: - Download Row View

struct DownloadRowView: View {
    let download: RDDownload
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var showingActionSheet = false
    @State private var downloadMessage = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: onSelectionToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                // Filename and size
                HStack {
                    Text(download.filename)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    if download.filesize > 0 {
                        Text(formatBytes(download.filesize))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Host and date info
                HStack {
                    Label(download.host, systemImage: "server.rack")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !download.generated.isEmpty {
                        Text(formatDate(download.generated))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // MIME type if available
                if !download.mimeType.isEmpty {
                    Text(download.mimeType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                
                // Download message if any
                if !downloadMessage.isEmpty {
                    Text(downloadMessage)
                        .font(.caption2)
                        .foregroundColor(downloadMessage.contains("✓") ? .green : 
                                       downloadMessage.contains("❌") ? .red : .blue)
                        .padding(.top, 2)
                }
            }
            
            VStack(spacing: 6) {
                // Download button
                Button("Download") {
                    downloadFile()
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                // More options button
                Button("More") {
                    showingActionSheet = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            Button(action: { downloadFile() }) {
                Label("Download File", systemImage: "arrow.down.circle")
            }
            
            Button(action: { copyToClipboard(download.download) }) {
                Label("Copy Download Link", systemImage: "doc.on.doc")
            }
            
            if !download.link.isEmpty {
                Button(action: { copyToClipboard(download.link) }) {
                    Label("Copy Original Link", systemImage: "link")
                }
            }
            
            Button(action: { shareFile() }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(action: onDelete) {
                Label("Delete from History", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
        .confirmationDialog("File Options", isPresented: $showingActionSheet) {
            Button("Download File") {
                downloadFile()
            }
            
            Button("Copy Download Link") {
                copyToClipboard(download.download)
                downloadMessage = "✓ Link copied"
                clearMessageAfterDelay()
            }
            
            if !download.link.isEmpty {
                Button("Copy Original Link") {
                    copyToClipboard(download.link)
                    downloadMessage = "✓ Original link copied"
                    clearMessageAfterDelay()
                }
            }
            
            Button("Share File") {
                shareFile()
            }
            
            Button("Delete from History", role: .destructive) {
                onDelete()
            }
            
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Download Functions
    
    private func downloadFile() {
        guard let url = URL(string: download.download) else {
            downloadMessage = "❌ Invalid download URL"
            clearMessageAfterDelay()
            return
        }
        
        downloadMessage = "⬇️ Starting download..."
        
        #if os(iOS)
        // For iOS, download the file directly and save to Files app
        downloadFileDirectly(from: url)
        #elseif os(macOS)
        // For macOS, open URL which should trigger download
        NSWorkspace.shared.open(url)
        downloadMessage = "✓ Download started"
        clearMessageAfterDelay()
        #endif
    }
    
    #if os(iOS)
    private func downloadFileDirectly(from url: URL) {
        print("🔽 Starting download for: \(url.absoluteString)")
        downloadMessage = "⬇️ Connecting..."
        
        let downloadTask = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            DispatchQueue.main.async {
                print("📥 Download completed for: \(self.download.filename)")
                
                if let error = error {
                    print("❌ Download error: \(error.localizedDescription)")
                    self.downloadMessage = "❌ Download failed: \(error.localizedDescription)"
                    self.clearMessageAfterDelay()
                    return
                }
                
                guard let localURL = localURL else {
                    print("❌ No local URL received")
                    self.downloadMessage = "❌ No file downloaded"
                    self.clearMessageAfterDelay()
                    return
                }
                
                print("📁 Local file downloaded to: \(localURL.path)")
                self.downloadMessage = "⬇️ Saving to Files app..."
                
                // Save to Files app
                self.saveToFilesApp(localURL: localURL)
            }
        }
        
        downloadTask.resume()
        print("🚀 Download task started for: \(download.filename)")
    }
    
    private func saveToFilesApp(localURL: URL) {
        print("💾 Attempting to save file: \(download.filename)")
        
        // Get the Documents directory URL
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Cannot access Documents folder")
            downloadMessage = "❌ Cannot access Documents folder"
            clearMessageAfterDelay()
            return
        }
        
        print("📂 Documents directory: \(documentsURL.path)")
        
        // Create destination URL with the original filename
        let destinationURL = documentsURL.appendingPathComponent(download.filename)
        print("🎯 Destination path: \(destinationURL.path)")
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                print("🗑️ Removing existing file at destination")
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Move downloaded file to Documents directory
            print("📋 Moving file from \(localURL.path) to \(destinationURL.path)")
            try FileManager.default.moveItem(at: localURL, to: destinationURL)
            
            print("✅ File saved successfully to: \(destinationURL.path)")
            downloadMessage = "✓ Downloaded to Files app"
            
            // Show share sheet to let user choose where to save
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.showShareSheet(for: destinationURL)
            }
            
        } catch {
            print("❌ Failed to save file: \(error.localizedDescription)")
            downloadMessage = "❌ Failed to save: \(error.localizedDescription)"
        }
        
        clearMessageAfterDelay()
    }
    
    private func showShareSheet(for fileURL: URL) {
        let activityViewController = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        // Configure for file sharing
        activityViewController.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .postToFacebook,
            .postToTwitter,
            .postToWeibo,
            .postToVimeo,
            .postToTencentWeibo,
            .postToFlickr
        ]
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var presentingController = rootViewController
            while let presentedViewController = presentingController.presentedViewController {
                presentingController = presentedViewController
            }
            
            // For iPad
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = presentingController.view
                popoverController.sourceRect = CGRect(x: presentingController.view.bounds.midX, 
                                                    y: presentingController.view.bounds.midY, 
                                                    width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            presentingController.present(activityViewController, animated: true)
        }
    }
    #endif
    
    // MARK: - Helper Functions
    
    private func shareFile() {
        guard let url = URL(string: download.download) else {
            downloadMessage = "❌ Invalid URL for sharing"
            clearMessageAfterDelay()
            return
        }
        
        #if os(iOS)
        let activityViewController = UIActivityViewController(
            activityItems: [url, download.filename],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var presentingController = rootViewController
            while let presentedViewController = presentingController.presentedViewController {
                presentingController = presentedViewController
            }
            
            // For iPad
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = presentingController.view
                popoverController.sourceRect = CGRect(x: presentingController.view.bounds.midX, 
                                                    y: presentingController.view.bounds.midY, 
                                                    width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            presentingController.present(activityViewController, animated: true)
        }
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
        downloadMessage = "✓ Download link copied for sharing"
        clearMessageAfterDelay()
        #endif
    }
    
    private func clearMessageAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            downloadMessage = ""
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
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

#Preview {
    DownloadsView()
} 