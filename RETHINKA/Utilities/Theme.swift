//
//  Theme.swift
//  RETHINKA
//
//  Created by Aston Walsh on 11/10/2025.
//

import Foundation
import SwiftUI

struct Theme {
    // Colours
    static let primary = Color(hex: "0b6374")
    static let secondary = Color(hex: "599191")
    static let background = Color(.systemBackground)
    static let cardBackground = Color(.secondarySystemBackground)
    
    // Circular Button Style
    struct CircularButton: ButtonStyle {
        var backgroundColor: Color = Theme.primary
        var foregroundColor: Color = .white
        var size: CGFloat = 60
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .frame(width: size, height: size)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .clipShape(Circle())
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
    
    // Card Style
    struct CardModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding()
                .background(Theme.cardBackground)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    // Primary Button Style
    struct PrimaryButton: ButtonStyle {
        var isDisabled: Bool = false
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .frame(maxWidth: .infinity)
                .padding()
                .background(isDisabled ? Color.gray : Theme.primary)
                .foregroundColor(.white)
                .cornerRadius(25)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

// Color Extension I had to use for a Hex related, will probably replace all this later with something else
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// View Extensions
extension View {
    func cardStyle() -> some View {
        modifier(Theme.CardModifier())
    }
}
