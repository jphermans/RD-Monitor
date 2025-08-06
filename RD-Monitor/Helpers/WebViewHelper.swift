import SwiftUI
import SafariServices
#if canImport(WebKit)
import WebKit
#endif

// MARK: - Safari View Controller for iOS
#if os(iOS)
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredControlTintColor = UIColor.systemBlue
        safariVC.preferredBarTintColor = UIColor.systemBackground
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        // No updates needed
    }
}
#endif

// MARK: - Web View for macOS and other platforms
#if os(macOS)
struct WebView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed
    }
}
#endif

// MARK: - Cross-platform In-App Browser
struct InAppBrowser: View {
    let url: URL
    let title: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            #if os(iOS)
            SafariView(url: url)
                .navigationBarHidden(true)
            #elseif os(macOS)
            WebView(url: url)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            #endif
        }
    }
}

// MARK: - Sheet Presentation Helper
struct InAppBrowserSheet: View {
    let url: URL
    let title: String
    @Binding var isPresented: Bool
    
    var body: some View {
        #if os(iOS)
        SafariView(url: url)
        #elseif os(macOS)
        NavigationView {
            WebView(url: url)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            isPresented = false
                        }
                    }
                }
        }
        #endif
    }
} 