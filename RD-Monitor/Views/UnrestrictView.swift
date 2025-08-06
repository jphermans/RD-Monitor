import SwiftUI

struct UnrestrictView: View {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @AppStorage("rd_demo_mode") var demoMode: Bool = false
    @AppStorage("rd_default_remote_traffic") var defaultRemoteTraffic: Bool = false
    
    @State private var selectedTab = 0
    @State private var linkToCheck = ""
    @State private var linkToUnrestrict = ""
    @State private var folderLink = ""
    @State private var containerLink = ""
    @State private var linkPassword = ""
    @State private var useRemoteTraffic = false
    
    @State private var isProcessing = false
    @State private var processMessage = ""
    @State private var checkResult: LinkCheckResult?
    @State private var unrestrictResults: [UnrestrictResult] = []
    @State private var folderResults: [FolderResult] = []
    @State private var containerResults: [String] = []
    
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
                        
                        Text("Unrestrict Not Available")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Link unrestricting and file decryption is only available in real mode with a valid Real-Debrid API key.")
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
                    // Real mode unrestrict tools
                    VStack(spacing: 0) {
                        // Tab Picker
                        Picker("Unrestrict Options", selection: $selectedTab) {
                            Text("Check Link").tag(0)
                            Text("Unrestrict").tag(1)
                            Text("Folder").tag(2)
                            Text("Container").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        
                        // Tab Content
                        TabView(selection: $selectedTab) {
                            // Check Link Tab
                            CheckLinkView(
                                linkToCheck: $linkToCheck,
                                linkPassword: $linkPassword,
                                isProcessing: $isProcessing,
                                processMessage: $processMessage,
                                checkResult: $checkResult,
                                onCheck: checkLink
                            )
                            .tag(0)
                            
                            // Unrestrict Link Tab
                            UnrestrictLinkView(
                                linkToUnrestrict: $linkToUnrestrict,
                                linkPassword: $linkPassword,
                                useRemoteTraffic: $useRemoteTraffic,
                                defaultRemoteTraffic: defaultRemoteTraffic,
                                isProcessing: $isProcessing,
                                processMessage: $processMessage,
                                unrestrictResults: $unrestrictResults,
                                onUnrestrict: unrestrictLink
                            )
                            .tag(1)
                            
                            // Folder Links Tab
                            FolderLinkView(
                                folderLink: $folderLink,
                                isProcessing: $isProcessing,
                                processMessage: $processMessage,
                                folderResults: $folderResults,
                                onProcess: unrestrictFolder
                            )
                            .tag(2)
                            
                            // Container Files Tab
                            ContainerFileView(
                                containerLink: $containerLink,
                                isProcessing: $isProcessing,
                                processMessage: $processMessage,
                                containerResults: $containerResults,
                                onProcess: decryptContainer
                            )
                            .tag(3)
                        }
                        #if os(iOS)
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        #endif
                    }
                }
            }
            .navigationTitle("Unrestrict")
            .defaultBackground()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .background(backgroundColorForScheme)
            .onAppear {
                useRemoteTraffic = defaultRemoteTraffic
            }
        }
    }
    
    // MARK: - API Functions
    
    func checkLink() {
        guard !linkToCheck.isEmpty else { return }
        
        isProcessing = true
        processMessage = ""
        checkResult = nil
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/unrestrict/check") else {
            processMessage = "❌ Invalid URL"
            isProcessing = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var postData = "link=\(linkToCheck.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if !linkPassword.isEmpty {
            postData += "&password=\(linkPassword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        request.httpBody = postData.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isProcessing = false
                
                if let error = error {
                    self.processMessage = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        if let data = data,
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            self.parseCheckResult(json)
                            self.processMessage = "✓ Link checked successfully"
                        } else {
                            self.processMessage = "❌ Failed to parse response"
                        }
                    case 503:
                        self.processMessage = "❌ File unavailable"
                    case 400:
                        self.processMessage = "❌ Invalid link format"
                    default:
                        self.processMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    func unrestrictLink() {
        guard !linkToUnrestrict.isEmpty else { return }
        
        isProcessing = true
        processMessage = ""
        unrestrictResults = []
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/unrestrict/link") else {
            processMessage = "❌ Invalid URL"
            isProcessing = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var postData = "link=\(linkToUnrestrict.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if !linkPassword.isEmpty {
            postData += "&password=\(linkPassword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        postData += "&remote=\(useRemoteTraffic ? 1 : 0)"
        request.httpBody = postData.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isProcessing = false
                
                if let error = error {
                    self.processMessage = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        if let data = data {
                            self.parseUnrestrictResult(data)
                            self.processMessage = "✓ Link unrestricted successfully"
                        } else {
                            self.processMessage = "❌ No data received"
                        }
                    case 401:
                        self.processMessage = "❌ Invalid API key"
                    case 403:
                        self.processMessage = "❌ Permission denied"
                    case 400:
                        self.processMessage = "❌ Invalid link or unsupported hoster"
                    case 429:
                        self.processMessage = "⚠️ Rate limit exceeded"
                    default:
                        self.processMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    func unrestrictFolder() {
        guard !folderLink.isEmpty else { return }
        
        isProcessing = true
        processMessage = ""
        folderResults = []
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/unrestrict/folder") else {
            processMessage = "❌ Invalid URL"
            isProcessing = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let postData = "link=\(folderLink.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = postData.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isProcessing = false
                
                if let error = error {
                    self.processMessage = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        if let data = data,
                           let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                            self.parseFolderResults(jsonArray)
                            self.processMessage = "✓ Folder processed successfully - found \(self.folderResults.count) files"
                        } else {
                            self.processMessage = "❌ Failed to parse folder response"
                        }
                    case 401:
                        self.processMessage = "❌ Invalid API key"
                    case 403:
                        self.processMessage = "❌ Permission denied"
                    case 400:
                        self.processMessage = "❌ Invalid folder link"
                    case 429:
                        self.processMessage = "⚠️ Rate limit exceeded"
                    default:
                        self.processMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    func decryptContainer() {
        guard !containerLink.isEmpty else { return }
        
        isProcessing = true
        processMessage = ""
        containerResults = []
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/unrestrict/containerLink") else {
            processMessage = "❌ Invalid URL"
            isProcessing = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let postData = "link=\(containerLink.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = postData.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isProcessing = false
                
                if let error = error {
                    self.processMessage = "❌ Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        if let data = data,
                           let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [String] {
                            self.containerResults = jsonArray
                            self.processMessage = "✓ Container decrypted successfully - found \(jsonArray.count) links"
                        } else {
                            self.processMessage = "❌ Failed to parse container response"
                        }
                    case 400:
                        self.processMessage = "❌ Invalid container file or link"
                    case 401:
                        self.processMessage = "❌ Invalid API key"
                    case 403:
                        self.processMessage = "❌ Permission denied - premium account required"
                    case 503:
                        self.processMessage = "❌ Service unavailable"
                    case 429:
                        self.processMessage = "⚠️ Rate limit exceeded"
                    default:
                        self.processMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Parsing Functions
    
    func parseCheckResult(_ json: [String: Any]) {
        let host = json["host"] as? String ?? "Unknown"
        let link = json["link"] as? String ?? ""
        let filename = json["filename"] as? String ?? "Unknown"
        let filesize = json["filesize"] as? Int64 ?? 0
        let supported = json["supported"] as? Int ?? 0
        
        checkResult = LinkCheckResult(
            host: host,
            link: link,
            filename: filename,
            filesize: filesize,
            supported: supported == 1
        )
    }
    
    func parseUnrestrictResult(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Single link result
                if let download = json["download"] as? String {
                    let result = UnrestrictResult(
                        id: json["id"] as? String ?? "",
                        filename: json["filename"] as? String ?? "Unknown",
                        filesize: json["filesize"] as? Int64 ?? 0,
                        link: json["link"] as? String ?? "",
                        host: json["host"] as? String ?? "Unknown",
                        chunks: json["chunks"] as? Int ?? 1,
                        crc: json["crc"] as? Int ?? 0,
                        download: download,
                        streamable: json["streamable"] as? Int ?? 0
                    )
                    unrestrictResults = [result]
                }
            } else if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                // Multiple links result (e.g., YouTube)
                unrestrictResults = jsonArray.compactMap { dict in
                    guard let download = dict["download"] as? String else { return nil }
                    
                    return UnrestrictResult(
                        id: dict["id"] as? String ?? "",
                        filename: dict["filename"] as? String ?? "Unknown",
                        filesize: dict["filesize"] as? Int64 ?? 0,
                        link: dict["link"] as? String ?? "",
                        host: dict["host"] as? String ?? "Unknown",
                        chunks: dict["chunks"] as? Int ?? 1,
                        crc: dict["crc"] as? Int ?? 0,
                        download: download,
                        streamable: dict["streamable"] as? Int ?? 0
                    )
                }
            }
        } catch {
            processMessage = "❌ Failed to parse unrestrict response: \(error.localizedDescription)"
        }
    }
    
    func parseFolderResults(_ jsonArray: [[String: Any]]) {
        folderResults = jsonArray.compactMap { dict in
            guard let download = dict["download"] as? String else { return nil }
            
            return FolderResult(
                filename: dict["filename"] as? String ?? "Unknown",
                filesize: dict["filesize"] as? Int64 ?? 0,
                download: download
            )
        }
    }
    
    // MARK: - Adaptive Colors
    private var backgroundColorForScheme: Color {
        colorScheme == .dark ? Color.black.opacity(0.9) : Color.gray.opacity(0.05)
    }
}

// MARK: - Check Link View

struct CheckLinkView: View {
    @Binding var linkToCheck: String
    @Binding var linkPassword: String
    @Binding var isProcessing: Bool
    @Binding var processMessage: String
    @Binding var checkResult: LinkCheckResult?
    let onCheck: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Check Link Availability")
                        .font(.headline)
                    
                    Text("Check if a file is downloadable from the hoster without using your account.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        TextField("Enter hoster link to check", text: $linkToCheck)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Password (if required)", text: $linkPassword)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Check Link") {
                            onCheck()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(linkToCheck.isEmpty || isProcessing)
                    }
                }
                
                if let result = checkResult {
                    CheckResultView(result: result)
                }
                
                if !processMessage.isEmpty {
                    Text(processMessage)
                        .font(.caption)
                        .foregroundColor(processMessage.contains("✓") ? .green : .red)
                }
                
                if isProcessing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking link...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Unrestrict Link View

struct UnrestrictLinkView: View {
    @Binding var linkToUnrestrict: String
    @Binding var linkPassword: String
    @Binding var useRemoteTraffic: Bool
    let defaultRemoteTraffic: Bool
    @Binding var isProcessing: Bool
    @Binding var processMessage: String
    @Binding var unrestrictResults: [UnrestrictResult]
    let onUnrestrict: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unrestrict Hoster Link")
                        .font(.headline)
                    
                    Text("Generate direct download links from supported hosters.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        TextField("Enter hoster link to unrestrict", text: $linkToUnrestrict)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Password (if required)", text: $linkPassword)
                            .textFieldStyle(.roundedBorder)
                        
                        Toggle("Use Remote Traffic", isOn: $useRemoteTraffic)
                        
                        Text("Remote traffic uses dedicated servers and lifts account sharing protections")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Unrestrict Link") {
                            onUnrestrict()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(linkToUnrestrict.isEmpty || isProcessing)
                    }
                }
                
                if !unrestrictResults.isEmpty {
                    UnrestrictResultsView(results: unrestrictResults)
                }
                
                if !processMessage.isEmpty {
                    Text(processMessage)
                        .font(.caption)
                        .foregroundColor(processMessage.contains("✓") ? .green : .red)
                }
                
                if isProcessing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Unrestricting link...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            useRemoteTraffic = defaultRemoteTraffic
        }
    }
}

// MARK: - Folder Link View

struct FolderLinkView: View {
    @Binding var folderLink: String
    @Binding var isProcessing: Bool
    @Binding var processMessage: String
    @Binding var folderResults: [FolderResult]
    let onProcess: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unrestrict Folder Link")
                        .font(.headline)
                    
                    Text("Extract individual download links from hoster folder links.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        TextField("Enter folder link", text: $folderLink)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Process Folder") {
                            onProcess()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(folderLink.isEmpty || isProcessing)
                    }
                }
                
                if !folderResults.isEmpty {
                    FolderResultsView(results: folderResults)
                }
                
                if !processMessage.isEmpty {
                    Text(processMessage)
                        .font(.caption)
                        .foregroundColor(processMessage.contains("✓") ? .green : .red)
                }
                
                if isProcessing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing folder...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Container File View

struct ContainerFileView: View {
    @Binding var containerLink: String
    @Binding var isProcessing: Bool
    @Binding var processMessage: String
    @Binding var containerResults: [String]
    let onProcess: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Decrypt Container Files")
                        .font(.headline)
                    
                    Text("Decrypt container files (RSDF, CCF, CCF3, DLC) and extract download links.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        TextField("Enter container file URL", text: $containerLink)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Decrypt Container") {
                            onProcess()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(containerLink.isEmpty || isProcessing)
                    }
                }
                
                if !containerResults.isEmpty {
                    ContainerResultsView(results: containerResults)
                }
                
                if !processMessage.isEmpty {
                    Text(processMessage)
                        .font(.caption)
                        .foregroundColor(processMessage.contains("✓") ? .green : .red)
                }
                
                if isProcessing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Decrypting container...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Result Views

struct CheckResultView: View {
    let result: LinkCheckResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Check Result")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Status:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(result.supported ? "✓ Supported" : "❌ Not Supported")
                        .foregroundColor(result.supported ? .green : .red)
                }
                
                HStack {
                    Text("Host:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(result.host)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Filename:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(result.filename)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text("Size:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatBytes(result.filesize))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .decimal
        return formatter.string(fromByteCount: bytes)
    }
}

struct UnrestrictResultsView: View {
    let results: [UnrestrictResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unrestricted Links (\(results.count))")
                .font(.headline)
            
            ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(result.filename)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Button("Copy") {
                            copyToClipboard(result.download)
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    
                    HStack {
                        Text("Size: \(formatBytes(result.filesize))")
                        Spacer()
                        Text("Host: \(result.host)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Text(result.download)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
                
                if index < results.count - 1 {
                    Divider()
                }
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .decimal
        return formatter.string(fromByteCount: bytes)
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

struct FolderResultsView: View {
    let results: [FolderResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Folder Contents (\(results.count) files)")
                .font(.headline)
            
            ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(result.filename)
                            .font(.subheadline)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Button("Copy") {
                            copyToClipboard(result.download)
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    
                    Text("Size: \(formatBytes(result.filesize))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                
                if index < results.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.1))
        )
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .decimal
        return formatter.string(fromByteCount: bytes)
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

struct ContainerResultsView: View {
    let results: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Decrypted Links (\(results.count))")
                .font(.headline)
            
            ForEach(Array(results.enumerated()), id: \.offset) { index, link in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Link \(index + 1)")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(link)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button("Copy") {
                        copyToClipboard(link)
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
                
                if index < results.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.1))
        )
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

// MARK: - Supporting Types

struct LinkCheckResult {
    let host: String
    let link: String
    let filename: String
    let filesize: Int64
    let supported: Bool
}

struct UnrestrictResult {
    let id: String
    let filename: String
    let filesize: Int64
    let link: String
    let host: String
    let chunks: Int
    let crc: Int
    let download: String
    let streamable: Int
}

struct FolderResult {
    let filename: String
    let filesize: Int64
    let download: String
}

#Preview {
    UnrestrictView()
} 