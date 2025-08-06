import SwiftUI

struct BackgroundColorModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                colorScheme == .dark ? Color(red: 0.1, green: 0.3, blue: 0.35) : Color(.systemTeal).opacity(0.1)
            )
    }
}

extension View {
    func defaultBackground() -> some View {
        modifier(BackgroundColorModifier())
    }
} 
