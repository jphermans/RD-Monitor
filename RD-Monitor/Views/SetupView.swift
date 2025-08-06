//
//  SetupView.swift
//  RD-Monitor
//
//  Created by Jean-Pierre Hermans on 28/05/2025.
//
import SwiftUI

struct SetupView: View {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @AppStorage("rd_pin_code") var storedPin: String = ""
    @AppStorage("rd_use_face_id") var useFaceID: Bool = false
    @AppStorage("rd_warning_days") var warningDays: Int = 7
    @AppStorage("rd_demo_mode") var demoMode: Bool = false
    @EnvironmentObject var colorSchemeManager: ColorSchemeManager

    @State private var tempKey: String = ""
    @State private var tempPin: String = ""
    @State private var faceIDEnabled: Bool = false
    @State private var tempWarningDays: Int = 7
    @State private var tempDemoMode: Bool = false
    @State private var saved = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account Setup")) {
                    Toggle("Demo Mode", isOn: $tempDemoMode)
                        .onChange(of: tempDemoMode) { value in
                            if value {
                                tempKey = "demo"
                            } else if tempKey == "demo" {
                                tempKey = ""
                            }
                        }
                    
                    if tempDemoMode {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Demo Mode Enabled")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Experience the app with sample data without needing a Real-Debrid account.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        SecureField("Real-Debrid API Key", text: $tempKey)
                            .onChange(of: tempKey) { value in
                                if value.lowercased() == "demo" {
                                    tempDemoMode = true
                                }
                            }
                        
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Need an API Key?")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("You can find your API key in your Real-Debrid account settings, or type 'demo' to try the app.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(header: Text("Security Options")) {
                    Toggle("Use Face ID / Touch ID", isOn: $faceIDEnabled)
                    SecureField("4-digit PIN (fallback)", text: $tempPin)
                }
                
                Section(header: Text("Notifications")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expiration Warning")
                            .fontWeight(.medium)
                        
                        Text("Get warned when your account expires in:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Stepper(value: $tempWarningDays, in: 1...30) {
                                HStack {
                                    Text("\(tempWarningDays)")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.teal)
                                    Text(tempWarningDays == 1 ? "day" : "days")
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Appearance")) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Choose your preferred theme")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("Applied instantly")
                                .font(.caption)
                                .foregroundColor(.teal)
                                .italic()
                        }
                        
                        HStack(spacing: 16) {
                            ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                                ColorSchemeOption(
                                    scheme: scheme,
                                    isSelected: colorSchemeManager.selectedScheme == scheme
                                ) {
                                    // Apply theme immediately
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        colorSchemeManager.selectedScheme = scheme
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 8)
                }

                Button("Save Settings & Continue") {
                    apiKey = tempKey
                    storedPin = tempPin
                    useFaceID = faceIDEnabled
                    warningDays = tempWarningDays
                    demoMode = tempDemoMode
                    saved = true
                }
                .disabled(tempKey.isEmpty || (faceIDEnabled == false && tempPin.count != 4))

                if saved {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(tempDemoMode ? 
                             "Demo mode enabled! Explore the app with sample data." : 
                             "Settings saved! You can now use the app.")
                            .foregroundColor(.green)
                    }
                    .multilineTextAlignment(.center)
                }
            }
            .background(Color.clear)
            .navigationTitle("Setup")
            .defaultBackground()
            .onAppear {
                tempKey = apiKey
                tempPin = storedPin
                faceIDEnabled = useFaceID
                tempWarningDays = warningDays
                tempDemoMode = demoMode || DemoDataService.isDemoMode(apiKey: apiKey)
            }
        }
    }
}

struct ColorSchemeOption: View {
    let scheme: AppColorScheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: scheme.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .teal)
                
                Text(scheme.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.teal : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.teal, lineWidth: isSelected ? 0 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
