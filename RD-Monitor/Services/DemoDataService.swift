import Foundation

class DemoDataService {
    static let shared = DemoDataService()
    
    private init() {}
    
    // MARK: - Demo User Data
    func getDemoUserInfo() -> [String: Any] {
        // Calculate a future expiration date (6 months from now)
        let futureDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
        let isoFormatter = ISO8601DateFormatter()
        let expirationDate = isoFormatter.string(from: futureDate)
        
        return [
            "id": 12345,
            "username": "demo_user",
            "email": "demo@example.com",
            "points": 1250,
            "locale": "en",
            "avatar": "retire",
            "type": "premium",
            "premium": 1,
            "expiration": expirationDate
        ]
    }
    
    // MARK: - Demo Traffic Data with More Variety
    func getDemoTrafficData() -> [String: Any] {
        // Current date for realistic timestamps
        let now = Date()
        let calendar = Calendar.current
        
        // Generate demo traffic data for the last 30 days with more variety
        var dailyTraffic: [[String: Any]] = []
        let hosts = ["mega.nz", "1fichier.com", "rapidgator.net", "turbobit.net", "nitroflare.com", "uploaded.net", "katfile.com"]
        
        // Generate dates from today backwards to 30 days ago
        for i in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            // Generate more realistic traffic patterns
            let dayOfWeek = calendar.component(.weekday, from: date)
            let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
            
            // Weekend traffic is typically higher
            let baseTrafficGB = isWeekend ? Double.random(in: 8...25) : Double.random(in: 2...18)
            
            // Add some random spikes for special days
            let hasSpike = Double.random(in: 0...1) < 0.15 // 15% chance of traffic spike
            let downloadGB = hasSpike ? baseTrafficGB * Double.random(in: 1.5...3.0) : baseTrafficGB
            
            // Random host selection weighted by popularity
            let hostWeights = [0.3, 0.25, 0.2, 0.15, 0.05, 0.03, 0.02] // Mega is most popular
            let randomValue = Double.random(in: 0...1)
            var cumulativeWeight = 0.0
            var selectedHost = hosts[0]
            
            for (index, weight) in hostWeights.enumerated() {
                cumulativeWeight += weight
                if randomValue <= cumulativeWeight {
                    selectedHost = hosts[index]
                    break
                }
            }
            
            // Ensure we have some traffic for today (i == 0)
            let finalTrafficGB = (i == 0) ? max(downloadGB, 2.0) : downloadGB
            
            dailyTraffic.append([
                "date": dateString,
                "bytes": Int(finalTrafficGB * 1024 * 1024 * 1024), // Convert GB to bytes
                "host": selectedHost,
                "type": "download"
            ])
            
            print("Generated demo traffic for \(dateString): \(finalTrafficGB) GB on \(selectedHost)")
        }
        
        // Calculate totals
        let totalUsed = dailyTraffic.reduce(0) { sum, traffic in
            sum + (traffic["bytes"] as? Int ?? 0)
        }
        
        print("Total demo traffic generated: \(totalUsed) bytes (\(Double(totalUsed) / (1024*1024*1024)) GB)")
        
        return [
            "left": max(0, (1000 * 1024 * 1024 * 1024) - totalUsed), // 1TB - used
            "used": totalUsed,
            "limit": 1000 * 1024 * 1024 * 1024, // 1 TB limit
            "type": "premium",
            "reset": "daily",
            "daily_traffic": dailyTraffic // Don't reverse, keep chronological order (newest first)
        ]
    }
    
    // MARK: - Demo Downloads
    func getDemoDownloads() -> [[String: Any]] {
        let demoFiles = [
            // Open Source Software
            ("Ubuntu_22.04_Desktop.iso", "ubuntu.com", "2024-01-15T10:30:00.000Z"),
            ("LibreOffice_7.6.4_Win_x86-64.msi", "libreoffice.org", "2024-01-14T15:45:00.000Z"),
            ("GIMP_2.10.36_setup.exe", "gimp.org", "2024-01-13T09:20:00.000Z"),
            ("Blender_4.0.2_windows-x64.zip", "blender.org", "2024-01-12T18:30:00.000Z"),
            ("VLC_media_player_3.0.19_win64.exe", "videolan.org", "2024-01-11T12:15:00.000Z"),
            
            // Free Books (Public Domain)
            ("Complete_Works_of_Shakespeare.pdf", "gutenberg.org", "2024-01-10T20:45:00.000Z"),
            ("Alice_in_Wonderland_Lewis_Carroll.epub", "archive.org", "2024-01-09T14:20:00.000Z"),
            ("Project_Gutenberg_Classic_Collection.zip", "gutenberg.org", "2024-01-08T11:30:00.000Z"),
            ("1984_George_Orwell_Public_Domain.pdf", "archive.org", "2024-01-07T16:45:00.000Z"),
            
            // Royalty-Free Music
            ("Royalty_Free_Classical_Collection_FLAC.zip", "freemusicarchive.org", "2024-01-06T13:20:00.000Z"),
            ("CC_Licensed_Ambient_Music_Pack.flac", "ccmixter.org", "2024-01-05T10:15:00.000Z"),
            ("Open_Source_Game_Soundtrack.ogg", "opengameart.org", "2024-01-04T21:30:00.000Z"),
            
            // Development Tools
            ("Visual_Studio_Code_1.85.0_win32-x64.zip", "code.visualstudio.com", "2024-01-03T08:45:00.000Z"),
            ("Docker_Desktop_4.26.1_win.exe", "docker.com", "2024-01-02T14:20:00.000Z"),
            ("Node.js_v20.10.0_win-x64.zip", "nodejs.org", "2024-01-01T19:30:00.000Z"),
            
            // Linux Distributions
            ("Fedora_39_Workstation_x86_64.iso", "fedoraproject.org", "2023-12-30T12:00:00.000Z"),
            ("Debian_12.4_amd64_DVD.iso", "debian.org", "2023-12-29T09:30:00.000Z"),
            ("Manjaro_23.1.2_KDE_minimal_x86_64.iso", "manjaro.org", "2023-12-28T16:15:00.000Z"),
            
            // Educational Content
            ("MIT_OpenCourseWare_Computer_Science.zip", "ocw.mit.edu", "2023-12-27T11:45:00.000Z"),
            ("Khan_Academy_Math_Videos_Collection.mp4", "khanacademy.org", "2023-12-26T15:20:00.000Z"),
            
            // Creative Commons Media
            ("BBC_Nature_Documentary_CC_BY.mkv", "archive.org", "2023-12-25T20:10:00.000Z"),
            ("Wikipedia_Offline_English_2024.zim", "kiwix.org", "2023-12-24T14:30:00.000Z")
        ]
        
        return demoFiles.enumerated().map { index, file in
            return [
                "id": "demo_\(index + 1)",
                "filename": file.0,
                "host": file.1,
                "generated": file.2,
                "download": "https://demo.real-debrid.com/d/\(index + 1)/\(file.0)",
                "size": generateRealisticFileSize(for: file.0)
            ]
        }
    }
    
    // MARK: - Demo Hosters Status
    func getDemoHostersStatus() -> [[String: Any]] {
        let hosters = [
            ("1fichier", "up", 98.5),
            ("Mega", "up", 99.2),
            ("Rapidgator", "up", 97.8),
            ("Turbobit", "up", 96.5),
            ("Nitroflare", "maintenance", 0.0),
            ("Uploaded", "up", 99.1),
            ("Katfile", "down", 0.0),
            ("Wdupload", "up", 95.2),
            ("Ddownload", "up", 94.8),
            ("Fboom", "up", 98.9)
        ]
        
        return hosters.map { hoster in
            return [
                "name": hoster.0,
                "status": hoster.1,
                "uptime": hoster.2,
                "check_time": ISO8601DateFormatter().string(from: Date())
            ]
        }
    }
    
    // MARK: - Demo Torrents
    func getDemoTorrents() -> [[String: Any]] {
        let torrents = [
            ("Ubuntu 22.04 LTS Desktop", "ubuntu-22.04-desktop-amd64.iso", "downloaded", 100, "2024-01-15T10:30:00.000Z"),
            ("Linux Mint 21.3", "linuxmint-21.3-cinnamon-64bit.iso", "downloading", 65, "2024-01-15T11:00:00.000Z"),
            ("Debian 12.4 DVD", "debian-12.4.0-amd64-DVD-1.iso", "waiting", 0, "2024-01-15T11:15:00.000Z"),
            ("CentOS Stream 9", "CentOS-Stream-9-latest-x86_64-dvd1.iso", "error", 0, "2024-01-15T11:30:00.000Z")
        ]
        
        return torrents.enumerated().map { index, torrent in
            return [
                "id": "demo_torrent_\(index + 1)",
                "filename": torrent.0,
                "original_filename": torrent.1,
                "hash": "demo_hash_\(index + 1)",
                "bytes": Int.random(in: 1_000_000_000...4_000_000_000),
                "original_bytes": Int.random(in: 1_000_000_000...4_000_000_000),
                "host": "real-debrid.com",
                "split": 1,
                "progress": torrent.3,
                "status": torrent.2,
                "added": torrent.4,
                "files": [[
                    "id": index + 1,
                    "path": "/\(torrent.1)",
                    "bytes": Int.random(in: 1_000_000_000...4_000_000_000),
                    "selected": 1
                ]],
                "links": torrent.2 == "downloaded" ? ["https://demo.real-debrid.com/d/\(index + 1)/\(torrent.1)"] : [],
                "ended": torrent.2 == "downloaded" ? torrent.4 : nil
            ]
        }
    }
    
    // MARK: - Helper Methods
    static func isDemoMode(apiKey: String) -> Bool {
        return apiKey.lowercased() == "demo"
    }
    
    static func simulateNetworkDelay() async {
        // Simulate realistic network delay (0.5 to 2 seconds)
        let delay = Double.random(in: 0.5...2.0)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
    
    // MARK: - Helper for Realistic File Sizes
    private func generateRealisticFileSize(for filename: String) -> Int {
        let lowercaseFilename = filename.lowercased()
        
        switch true {
        case lowercaseFilename.contains(".iso"):
            // Linux ISOs: 700MB - 4GB
            return Int.random(in: 700_000_000...4_000_000_000)
        case lowercaseFilename.contains(".msi") || lowercaseFilename.contains(".exe"):
            // Installers: 50MB - 500MB
            return Int.random(in: 50_000_000...500_000_000)
        case lowercaseFilename.contains(".pdf"):
            // PDFs: 1MB - 50MB
            return Int.random(in: 1_000_000...50_000_000)
        case lowercaseFilename.contains(".epub"):
            // E-books: 500KB - 10MB
            return Int.random(in: 500_000...10_000_000)
        case lowercaseFilename.contains(".zip") && (lowercaseFilename.contains("collection") || lowercaseFilename.contains("pack")):
            // Collections: 100MB - 2GB
            return Int.random(in: 100_000_000...2_000_000_000)
        case lowercaseFilename.contains(".flac") || lowercaseFilename.contains(".ogg"):
            // Audio files: 10MB - 200MB
            return Int.random(in: 10_000_000...200_000_000)
        case lowercaseFilename.contains(".mp4") || lowercaseFilename.contains(".mkv"):
            // Video files: 500MB - 8GB
            return Int.random(in: 500_000_000...8_000_000_000)
        case lowercaseFilename.contains(".zim"):
            // Wikipedia offline: 50GB - 100GB
            return Int.random(in: 50_000_000_000...100_000_000_000)
        default:
            // Default: 10MB - 1GB
            return Int.random(in: 10_000_000...1_000_000_000)
        }
    }
} 