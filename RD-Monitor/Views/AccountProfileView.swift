//
//  AccountProfileView.swift
//  RD-Monitor
//
//  Created by Jean-Pierre Hermans on 28/05/2025.
//

import SwiftUI
import Foundation

// Local account structure for this view
struct AccountInfo {
    let username: String
    let email: String
    let expiration: String
    let points: Int
    let type: String
    let premium: Int
    let avatar: String?
}

struct AccountProfileView: View {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @AppStorage("rd_warning_days") var warningDays: Int = 7
    @AppStorage("rd_demo_mode") var demoMode: Bool = false
    @State private var account: AccountInfo?
    @State private var error: String?
    @State private var isLoading = true
    @Environment(\.colorScheme) var colorScheme
    
    private var isDemoMode: Bool {
        return demoMode || DemoDataService.isDemoMode(apiKey: apiKey)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        HStack {
                            Text("Account Profile")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
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
                        
                        Text(isDemoMode ? "Sample account profile for demonstration" : "Your Real-Debrid account information")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Warning Banner
                    if let account = account, shouldShowWarning(account.expiration) {
                        WarningBanner(
                            daysLeft: daysLeft(account.expiration),
                            warningDays: warningDays
                        )
                    }
                    
                    if isLoading {
                        ProgressView("Loading account information...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = error {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            
                            Text("Error Loading Account")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(error)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Retry") {
                                fetchAccount()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else if let account = account {
                        VStack(spacing: 20) {
                            // Avatar and Username Section
                            VStack(spacing: 12) {
                                // User Avatar
                                if isDemoMode && account.avatar == "retire" {
                                    // Use local asset for demo mode
                                    Image("retire")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                                        )
                                } else if let avatarURL = account.avatar, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        // Loading placeholder
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 100, height: 100)
                                            .overlay(
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                            )
                                    }
                                } else {
                                    // Fallback gradient circle with initials
                                    Circle()
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [.blue, .purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Text(String(account.username.prefix(2)).uppercased())
                                                .font(.title)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        )
                                }
                                
                                Text(account.username)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            
                            // Account Details Card
                            VStack(spacing: 16) {
                                // Email
                                AccountDetailRow(
                                    icon: "envelope.fill",
                                    iconColor: .blue,
                                    title: "Email",
                                    value: account.email
                                )
                                
                                Divider()
                                
                                // Expiration Date
                                AccountDetailRow(
                                    icon: "calendar",
                                    iconColor: .orange,
                                    title: "Expires",
                                    value: formatDate(account.expiration)
                                )
                                
                                Divider()
                                
                                // Remaining Days
                                let remainingDays = daysLeft(account.expiration)
                                AccountDetailRow(
                                    icon: "clock.fill",
                                    iconColor: remainingDays < 5 ? .red : .green,
                                    title: "Remaining",
                                    value: daysLeftText(account.expiration)
                                )
                                
                                Divider()
                                
                                // Premium Status
                                HStack {
                                    HStack(spacing: 8) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                        Text("Premium Status")
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Premium Badge
                                    HStack(spacing: 4) {
                                        Image(systemName: isPremium(account.expiration) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(isPremium(account.expiration) ? .green : .red)
                                        Text(isPremium(account.expiration) ? "Active" : "Inactive")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(isPremium(account.expiration) ? .green.opacity(0.1) : .red.opacity(0.1))
                                    )
                                }
                                
                                Divider()
                                
                                // Points
                                AccountDetailRow(
                                    icon: "diamond.fill",
                                    iconColor: .purple,
                                    title: "Points",
                                    value: "\(account.points)"
                                )
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(cardBackgroundColor)
                                    .shadow(color: shadowColor, radius: 8, x: 0, y: 2)
                            )
                        }
                        .padding(.horizontal)
                    } else {
                        // Fallback state
                        VStack(spacing: 16) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("No Account Data")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Unable to load account information")
                                .foregroundColor(.secondary)
                            
                            Button("Load Account") {
                                fetchAccount()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .defaultBackground()
            .refreshable {
                fetchAccount()
            }
        }
        .onAppear {
            fetchAccount()
        }
        .onChange(of: colorScheme) { oldValue, newValue in
            // Ensure profile loads after theme change if no data is present
            if account == nil && !isLoading && error != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    fetchAccount()
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func fetchAccount() {
        if isDemoMode {
            fetchDemoAccount()
            return
        }
        
        isLoading = true
        error = nil
        
        print("Starting fetchAccount with API key: \(apiKey.isEmpty ? "EMPTY" : "Present (\(apiKey.count) chars)")")
        
        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.error = "No API key configured. Please set your API key in settings."
                self.isLoading = false
            }
            return
        }
        
        guard let url = URL(string: "https://api.real-debrid.com/rest/1.0/user") else {
            DispatchQueue.main.async {
                self.error = "Invalid URL"
                self.isLoading = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        print("Making request to: \(url)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("Network error: \(error)")
                    self.error = "Network error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Response: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 401 {
                        self.error = "Invalid API key. Please check your API key in settings."
                        return
                    } else if httpResponse.statusCode == 429 {
                        self.error = "Rate limit exceeded. Please wait a moment."
                        return
                    } else if httpResponse.statusCode != 200 {
                        self.error = "API error: HTTP \(httpResponse.statusCode)"
                        return
                    }
                }
                
                guard let data = data else {
                    print("No data received")
                    self.error = "No data received from server"
                    return
                }
                
                do {
                    print("Raw API response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                    
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("Parsed JSON: \(json)")
                        
                        guard let username = json["username"] as? String,
                              let email = json["email"] as? String,
                              let expiration = json["expiration"] as? String else {
                            print("Missing required fields: username=\(json["username"] as Any), email=\(json["email"] as Any), expiration=\(json["expiration"] as Any)")
                            self.error = "Missing required account fields"
                            return
                        }
                        
                        // Handle points as either Int or NSNumber
                        let points: Int
                        if let pointsInt = json["points"] as? Int {
                            points = pointsInt
                        } else if let pointsNumber = json["points"] as? NSNumber {
                            points = pointsNumber.intValue
                        } else {
                            print("Points field type: \(type(of: json["points"]))")
                            points = 0
                        }
                        
                        // Handle premium as either Int or NSNumber  
                        let premium: Int
                        if let premiumInt = json["premium"] as? Int {
                            premium = premiumInt
                        } else if let premiumNumber = json["premium"] as? NSNumber {
                            premium = premiumNumber.intValue
                        } else {
                            print("Premium field type: \(type(of: json["premium"]))")
                            premium = 0
                        }
                        
                        let avatar: String?
                        if let avatarString = json["avatar"] as? String {
                            avatar = avatarString
                            print("Avatar URL found: \(avatarString)")
                        } else {
                            avatar = nil
                            print("No avatar URL in response")
                        }
                        
                        let account = AccountInfo(
                            username: username,
                            email: email,
                            expiration: expiration,
                            points: points,
                            type: json["type"] as? String ?? "premium",
                            premium: premium,
                            avatar: avatar
                        )
                        
                        print("Successfully created account: \(account)")
                        self.account = account
                    } else {
                        self.error = "Invalid JSON format"
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                    self.error = "Failed to parse account data: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func fetchDemoAccount() {
        isLoading = true
        error = nil
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let demoUserData = DemoDataService.shared.getDemoUserInfo()
            
            guard let username = demoUserData["username"] as? String,
                  let email = demoUserData["email"] as? String,
                  let expiration = demoUserData["expiration"] as? String,
                  let points = demoUserData["points"] as? Int,
                  let type = demoUserData["type"] as? String,
                  let premium = demoUserData["premium"] as? Int else {
                self.error = "Invalid demo data format"
                self.isLoading = false
                return
            }
            
            let avatar = demoUserData["avatar"] as? String
            
            let account = AccountInfo(
                username: username,
                email: email,
                expiration: expiration,
                points: points,
                type: type,
                premium: premium,
                avatar: avatar
            )
            
            self.account = account
            self.isLoading = false
        }
    }
    
    func formatDate(_ raw: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "dd-MM-yyyy HH:mm"
        displayFormatter.locale = Locale(identifier: "en_US_POSIX")
        displayFormatter.timeZone = TimeZone.current

        if let date = isoFormatter.date(from: raw) {
            return displayFormatter.string(from: date)
        } else {
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: raw) {
                return displayFormatter.string(from: date)
            }
        }
        return "Invalid date"
    }
    
    func isPremium(_ isoDate: String) -> Bool {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let expirationDate = isoFormatter.date(from: isoDate) ??
                                ISO8601DateFormatter().date(from: isoDate) {
            return expirationDate > Date()
        }
        return false
    }

    func daysLeft(_ isoDate: String) -> Int {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let expirationDate = isoFormatter.date(from: isoDate) ??
                                    ISO8601DateFormatter().date(from: isoDate) else {
            return 0
        }

        let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return max(0, days)
    }

    func daysLeftText(_ isoDate: String) -> String {
        let days = daysLeft(isoDate)
        return days == 0 ? "Expired" : "\(days) day\(days == 1 ? "" : "s") left"
    }
    
    func shouldShowWarning(_ isoDate: String) -> Bool {
        let days = daysLeft(isoDate)
        return days <= warningDays && days > 0
    }
    
    // MARK: - Adaptive Colors
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white
    }
    
    private var backgroundColorForScheme: Color {
        colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.1)
    }
}

// MARK: - Account Detail Row Component

struct AccountDetailRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Warning Banner Component

struct WarningBanner: View {
    let daysLeft: Int
    let warningDays: Int
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Account Expiring Soon!")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your account expires in \(daysLeft) \(daysLeft == 1 ? "day" : "days"). Please renew to continue using Real-Debrid.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.red, .red.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: shadowColor, radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.2)
    }
}

#Preview {
    AccountProfileView()
} 