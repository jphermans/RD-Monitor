//
//  RD_MonitorApp.swift
//  RD-Monitor
//
//  Created by Jean-Pierre Hermans on 28/05/2025.
//
// RealDebridMonitorApp.swift
import SwiftUI

@main
struct RealDebridMonitorApp: App {
    @AppStorage("rd_api_key") var apiKey: String = ""
    @AppStorage("rd_pin_code") var storedPin: String = ""
    @AppStorage("rd_use_face_id") var useFaceID: Bool = false
    @StateObject private var colorSchemeManager = ColorSchemeManager()

    @State private var authenticated = false
    @State private var showSetup = false
    @State private var showPinPrompt = false
    @State private var pinAttempt = ""

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(colorSchemeManager.selectedScheme.colorScheme)
                .environmentObject(colorSchemeManager)
        }
    }

    // MARK: - Entry point wrapper
    @ViewBuilder
    func RootView() -> some View {
        if showSetup {
            SetupView()
                .defaultBackground()
        } else if authenticated {
            MainTabView()
                .defaultBackground()
        } else {
            ProgressView("Authenticating...")
                .onAppear {
                    authenticate()
                }
                .defaultBackground()
                .sheet(isPresented: $showPinPrompt) {
                    VStack(spacing: 20) {
                        Image("RDtitle")
                            .resizable()
                            .scaledToFit()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(25)
                        
                        Text("Enter PIN to Unlock")
                            .font(.headline)

                        SecureField("PIN", text: $pinAttempt)
                            .keyboardType(.numberPad)
                            .padding()
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.5) // 50% breedte
                            .multilineTextAlignment(.center) // tekst in het midden
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))

                        Button("Unlock") {
                            if pinAttempt == storedPin {
                                authenticated = true
                                showPinPrompt = false
                            }
                        }
                        .disabled(pinAttempt.count != 4)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .defaultBackground()
                }
        }
    }

    // MARK: - Authentication Logic
    func authenticate() {
        if apiKey.isEmpty {
            showSetup = true
        } else if useFaceID {
            BiometricHelper.authenticate { success in
                if success {
                    authenticated = true
                } else if !storedPin.isEmpty {
                    showPinPrompt = true
                } else {
                    showSetup = true
                }
            }
        } else if !storedPin.isEmpty {
            showPinPrompt = true
        } else {
            showSetup = true
        }
    }
}
