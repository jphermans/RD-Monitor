import SwiftUI
import AVKit
import WebKit
import Foundation

struct StreamingView: View {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @AppStorage("rd_demo_mode") var demoMode: Bool = false
    
    @State private var downloads: [RDDownload] = []
    @State private var isLoading = false
    @State private var statusMessage = ""
    @State private var selectedDownload: RDDownload?
    @State private var streamingData: StreamingData?
    @State private var isLoadingStream = false
    @State private var showingVideoPlayer = false
    @State private var selectedStreamURL: URL?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedQuality: StreamQuality?
    @State private var availableQualities: [StreamQuality] = []
    @State private var showingQualityPicker = false
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    private var isDemoMode: Bool {
        return demoMode || DemoDataService.isDemoMode(apiKey: apiKey)
    }
    
    var body: some View {
        VStack {
            if isDemoMode {
                demoModeMessage
            } else {
                streamingContent
            }
        }
        .navigationTitle("Streaming")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .background(backgroundColorForScheme)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                }
            }
        }
        .onAppear {
            if !isDemoMode {
                fetchDownloads()
            }
        }
        .alert("Streaming Notice", isPresented: $showingAlert) {
            Button("OK") { }
            Button("Return") { 
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingQualityPicker) {
            QualityPickerView(
                qualities: availableQualities,
                selectedQuality: $selectedQuality,
                onSelection: { quality in
                    selectedQuality = quality
                    showingQualityPicker = false
                    if let quality = quality,
                       let downloadId = selectedDownload?.id {
                        streamWithQuality(downloadId: downloadId, quality: quality)
                    }
                },
                onCancel: {
                    showingQualityPicker = false
                    statusMessage = "ℹ️ Stream cancelled"
                }
            )
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            if let streamURL = selectedStreamURL {
                VideoPlayerView(url: streamURL, apiKey: apiKey) {
                    showingVideoPlayer = false
                    selectedStreamURL = nil
                    // Reset orientation when returning
                    #if os(iOS)
                    AppDelegate.orientationLock = .all
                    #endif
                }
            }
        }
    }
    
    // MARK: - Demo Mode Message
    
    private var demoModeMessage: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Streaming Available in Real Mode")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Streaming functionality requires a Real-Debrid API key and is not available in demo mode.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Configure your API key in Settings to access streaming features.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Go to Settings") {
                // This could be enhanced to switch tabs programmatically
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Streaming Content
    
    private var streamingContent: some View {
        VStack(spacing: 0) {
            // Header with status
            if !statusMessage.isEmpty {
                HStack {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(statusColor)
                    Spacer()
                    Button("Clear") {
                        statusMessage = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                
                Divider()
            }
            
            // Main content
            if isLoading {
                loadingView
            } else if downloads.isEmpty {
                emptyState
            } else {
                downloadsList
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading streamable downloads...")
                .foregroundColor(.secondary)
            
            Button("Cancel") {
                isLoading = false
                statusMessage = "❌ Loading cancelled"
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tv.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Streamable Downloads")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("You need to have streamable downloads in your Real-Debrid account to use this feature.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button("Refresh Downloads") {
                    fetchDownloads()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Go to Downloads") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var downloadsList: some View {
        List(downloads, id: \.id) { download in
            StreamingDownloadRowView(
                download: download,
                isLoadingStream: isLoadingStream && selectedDownload?.id == download.id,
                onStreamTap: {
                    selectedDownload = download
                    checkStreamingCapability(for: download)
                }
            )
        }
        .listStyle(.plain)
        .refreshable {
            fetchDownloads()
        }
    }
    
    private var statusColor: Color {
        if statusMessage.contains("✓") {
            return .green
        } else if statusMessage.contains("❌") {
            return .red
        } else if statusMessage.contains("⚠️") {
            return .orange
        } else {
            return .blue
        }
    }
    
    // MARK: - Helper Functions
    
    func fetchDownloads() {
        guard !isDemoMode && !apiKey.isEmpty else { return }
        
        isLoading = true
        statusMessage = ""
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/downloads") else {
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
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.statusMessage = "❌ Invalid response"
                    return
                }
                
                switch httpResponse.statusCode {
                case 200:
                    if let data = data {
                        self.parseDownloads(data: data)
                    }
                case 401:
                    self.statusMessage = "❌ Invalid API key"
                case 403:
                    self.statusMessage = "❌ Access denied"
                case 429:
                    self.statusMessage = "⚠️ Rate limit exceeded - try again later"
                default:
                    self.statusMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
                }
            }
        }.resume()
    }
    
    func parseDownloads(data: Data) {
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                self.downloads = jsonArray.compactMap { dict in
                    guard let id = dict["id"] as? String,
                          let filename = dict["filename"] as? String,
                          let host = dict["host"] as? String,
                          let generated = dict["generated"] as? String else {
                        return nil
                    }
                    
                    // Only include streamable files
                    let streamable = dict["streamable"] as? Int ?? 0
                    if streamable == 0 {
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
                
                if self.downloads.isEmpty {
                    self.statusMessage = "ℹ️ No streamable content found in your downloads"
                } else {
                    self.statusMessage = "✓ Found \(self.downloads.count) streamable file(s)"
                }
            }
        } catch {
            self.statusMessage = "❌ Failed to parse downloads: \(error.localizedDescription)"
        }
    }
    
    func checkStreamingCapability(for download: RDDownload) {
        guard !apiKey.isEmpty else { return }
        
        isLoadingStream = true
        statusMessage = ""
        
        // First, check if we can get transcoding links
        getTranscodingLinks(downloadId: download.id)
    }
    
    func getTranscodingLinks(downloadId: String) {
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/streaming/transcode/\(downloadId)") else {
            statusMessage = "❌ Invalid streaming URL"
            isLoadingStream = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingStream = false
                
                if let error = error {
                    self.statusMessage = "❌ Streaming error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.statusMessage = "❌ Invalid streaming response"
                    return
                }
                
                switch httpResponse.statusCode {
                case 200:
                    if let data = data {
                        self.parseStreamingData(data: data, downloadId: downloadId)
                    }
                case 401:
                    self.statusMessage = "❌ Invalid API key"
                case 403:
                    self.statusMessage = "❌ Streaming access denied"
                case 429:
                    self.alertMessage = "Rate limit exceeded. Real-Debrid allows 250 requests per minute. Please wait a moment before trying again."
                    self.showingAlert = true
                    self.statusMessage = "⚠️ Rate limit exceeded - wait before retrying"
                case 503:
                    self.alertMessage = "This file is not streamable or cannot be processed for streaming."
                    self.showingAlert = true
                default:
                    self.statusMessage = "❌ Streaming API error: HTTP \(httpResponse.statusCode)"
                }
            }
        }.resume()
    }
    
    func parseStreamingData(data: Data, downloadId: String) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var qualities: [StreamQuality] = []
                
                // Parse different streaming formats
                if let apple = json["apple"] as? [String: String] {
                    for (quality, url) in apple {
                        qualities.append(StreamQuality(format: "HLS", quality: quality, url: url))
                    }
                }
                
                if let dash = json["dash"] as? [String: String] {
                    for (quality, url) in dash {
                        qualities.append(StreamQuality(format: "DASH", quality: quality, url: url))
                    }
                }
                
                if let liveMP4 = json["liveMP4"] as? [String: String] {
                    for (quality, url) in liveMP4 {
                        qualities.append(StreamQuality(format: "MP4", quality: quality, url: url))
                    }
                }
                
                if let h264WebM = json["h264WebM"] as? [String: String] {
                    for (quality, url) in h264WebM {
                        qualities.append(StreamQuality(format: "WebM", quality: quality, url: url))
                    }
                }
                
                if qualities.isEmpty {
                    self.alertMessage = "No streaming qualities available for this file."
                    self.showingAlert = true
                } else if qualities.count == 1 {
                    // Single quality available, stream directly
                    if let streamURL = URL(string: qualities.first!.url) {
                        self.selectedStreamURL = streamURL
                        self.showingVideoPlayer = true
                    }
                } else {
                    // Multiple qualities available, show picker
                    self.availableQualities = qualities.sorted { 
                        qualityOrder($0.quality) < qualityOrder($1.quality)
                    }
                    self.showingQualityPicker = true
                }
            }
        } catch {
            self.statusMessage = "❌ Failed to parse streaming data: \(error.localizedDescription)"
        }
    }
    
    func streamWithQuality(downloadId: String, quality: StreamQuality) {
        if let streamURL = URL(string: quality.url) {
            selectedStreamURL = streamURL
            showingVideoPlayer = true
        }
    }
    
    func qualityOrder(_ quality: String) -> Int {
        switch quality.lowercased() {
        case "2160", "4k", "2160p": return 0
        case "1440", "1440p": return 1
        case "1080", "1080p": return 2
        case "720", "720p": return 3
        case "480", "480p": return 4
        case "360", "360p": return 5
        case "240", "240p": return 6
        default: return 7
        }
    }
    
    // MARK: - Adaptive Colors
    private var backgroundColorForScheme: Color {
        colorScheme == .dark ? Color.black.opacity(0.9) : Color.gray.opacity(0.05)
    }
}

// MARK: - Supporting Views

struct StreamingDownloadRowView: View {
    let download: RDDownload
    let isLoadingStream: Bool
    let onStreamTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(download.filename)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    Text(download.host)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    
                    if download.filesize > 0 {
                        Text(formatFileSize(download.filesize))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Text("Generated: \(formatDate(download.generated))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onStreamTap) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Stream")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .disabled(isLoadingStream)
            
            if isLoadingStream {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
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
}

struct QualityPickerView: View {
    let qualities: [StreamQuality]
    @Binding var selectedQuality: StreamQuality?
    let onSelection: (StreamQuality?) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(qualities) { quality in
                Button(action: {
                    onSelection(quality)
                }) {
                    HStack {
                        Text(quality.displayName)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedQuality?.id == quality.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

struct VideoPlayerView: View {
    let url: URL
    let apiKey: String
    let onDismiss: () -> Void
    
    @State private var isLoading = true
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var streamFailed = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if streamFailed {
                // Stream failed view
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Stream Failed")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("This file cannot be streamed or is not compatible.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        Button("Return to Streaming") {
                            onDismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button("Open in Browser") {
                            openInBrowser()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.white)
                    }
                }
                .padding()
            } else if isLoading {
                // Loading view
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Loading stream...")
                        .foregroundColor(.white)
                        .font(.headline)
                    
                    Text("Using web player for compatibility")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                    
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                    .buttonStyle(.bordered)
                    .padding(.top)
                }
                .padding()
            } else {
                // Web-based video player
                WebVideoPlayer(url: url, apiKey: apiKey, onError: { error in
                    errorMessage = error
                    streamFailed = true
                })
                .onAppear {
                    #if os(iOS)
                    // Force landscape orientation using modern API
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
                        windowScene.requestGeometryUpdate(geometryPreferences) { error in
                            if error != nil {
                                print("Failed to request geometry update: \(error)")
                            }
                        }
                    }
                    AppDelegate.orientationLock = .landscape
                    #endif
                }
                .onDisappear {
                    #if os(iOS)
                    // Allow all orientations when leaving using modern API
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .all)
                        windowScene.requestGeometryUpdate(geometryPreferences) { error in
                            if error != nil {
                                print("Failed to reset geometry: \(error)")
                            }
                        }
                    }
                    AppDelegate.orientationLock = .all
                    #endif
                }
            }
            
            // Always-visible close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
            
            // Return button in bottom left when not loading
            if !isLoading && !streamFailed {
                VStack {
                    Spacer()
                    HStack {
                        Button(action: onDismiss) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                        }
                        .padding()
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .alert("Streaming Error", isPresented: $showingError) {
            Button("Return") { onDismiss() }
            Button("Open in Browser") { openInBrowser() }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func setupPlayer() {
        print("🎬 Setting up web player for URL: \(url)")
        
        // Simulate loading time for web player setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
        }
        
        // Timeout after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if isLoading {
                print("⏰ Web player timeout reached")
                streamFailed = true
                isLoading = false
            }
        }
    }
    
    private func openInBrowser() {
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
        onDismiss()
    }
}

// MARK: - Web Video Player

struct WebVideoPlayer: UIViewRepresentable {
    let url: URL
    let apiKey: String
    let onError: (String) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .black
        webView.isOpaque = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Create a request with authentication headers
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        // Load the video URL directly instead of HTML
        webView.load(request)
        
        // Alternative: If direct loading doesn't work, try JavaScript approach
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if webView.url == nil || webView.url?.absoluteString.isEmpty == true {
                self.loadVideoWithJavaScript(webView: webView)
            }
        }
    }
    
    private func loadVideoWithJavaScript(webView: WKWebView) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { 
                    margin: 0; 
                    padding: 0; 
                    background: black; 
                    display: flex; 
                    justify-content: center; 
                    align-items: center; 
                    height: 100vh; 
                }
                video { 
                    width: 100%; 
                    height: 100%; 
                    object-fit: contain; 
                }
                .error {
                    color: white;
                    text-align: center;
                    font-family: Arial, sans-serif;
                }
            </style>
        </head>
        <body>
            <video id="videoPlayer" controls autoplay playsinline>
                <source src="\(url.absoluteString)" type="video/mp4">
                Your browser does not support the video tag.
            </video>
            
            <script>
                const video = document.getElementById('videoPlayer');
                
                // Add authorization header using fetch
                fetch('\(url.absoluteString)', {
                    headers: {
                        'Authorization': 'Bearer \(apiKey)',
                        'User-Agent': 'RD-Monitor-iOS/1.0'
                    }
                })
                .then(response => {
                    if (response.ok) {
                        return response.blob();
                    }
                    throw new Error('Network response was not ok');
                })
                .then(blob => {
                    const videoURL = URL.createObjectURL(blob);
                    video.src = videoURL;
                    video.play();
                })
                .catch(error => {
                    console.error('Error loading video:', error);
                    document.body.innerHTML = '<div class="error"><h2>Error Loading Video</h2><p>Unable to load the stream. Try opening in browser.</p></div>';
                });
                
                video.addEventListener('error', function(e) {
                    console.error('Video error:', e);
                    document.body.innerHTML = '<div class="error"><h2>Video Error</h2><p>The video format may not be supported. Try opening in browser.</p></div>';
                });
                
                video.addEventListener('loadstart', function() {
                    console.log('Video load started');
                });
                
                video.addEventListener('canplay', function() {
                    console.log('Video can play');
                    video.play();
                });
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onError: onError)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let onError: (String) -> Void
        
        init(onError: @escaping (String) -> Void) {
            self.onError = onError
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView failed to load: \(error.localizedDescription)")
            onError("Failed to load video: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView navigation failed: \(error.localizedDescription)")
            onError("Video playback failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView finished loading")
        }
    }
}

#if os(iOS)
// MARK: - Orientation Management
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}
#endif

#Preview {
    StreamingView()
} 