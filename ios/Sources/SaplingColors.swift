import SwiftUI
import UIKit

enum SaplingColors {
    // Primary brand — Field Journal forest green
    static let brand = Color(red: 0.290, green: 0.404, blue: 0.255)       // #4a6741
    static let brandUI = UIColor(red: 0.290, green: 0.404, blue: 0.255, alpha: 1)

    // Accent — amber, like afternoon light through leaves
    static let accent = Color(red: 0.769, green: 0.525, blue: 0.227)      // #c4863a
    static let accentUI = UIColor(red: 0.769, green: 0.525, blue: 0.227, alpha: 1)

    // Bark — warm brown for trail lines and tertiary elements
    static let bark = Color(red: 0.478, green: 0.408, blue: 0.251)        // #7a6840
    static let barkUI = UIColor(red: 0.478, green: 0.408, blue: 0.251, alpha: 1)

    // Field Journal background palette
    static let parchment = Color(red: 0.957, green: 0.941, blue: 0.910)   // #f4f0e8 — sheet/card backgrounds
    static let stone = Color(red: 0.929, green: 0.914, blue: 0.878)       // #ede9e0 — stat card backgrounds
    static let ink = Color(red: 0.176, green: 0.165, blue: 0.133)         // #2d2a22 — primary text

    // Trail line on map — warm terracotta, high-visibility over any basemap
    static let trail = Color(red: 0.69, green: 0.47, blue: 0.34)
    static let trailUI = UIColor(red: 0.69, green: 0.47, blue: 0.34, alpha: 1)

    // Recording states
    static let recording = brand
    static let stopRecording = Color(red: 0.76, green: 0.31, blue: 0.27)

    // Seed type colors — earthy, semantically distinct
    static let water = Color(red: 0.33, green: 0.55, blue: 0.65)          // mountain stream blue
    static let waterUI = UIColor(red: 0.33, green: 0.55, blue: 0.65, alpha: 1)

    static let camp = Color(red: 0.62, green: 0.36, blue: 0.18)           // campfire ember
    static let campUI = UIColor(red: 0.62, green: 0.36, blue: 0.18, alpha: 1)

    static let beauty = Color(red: 0.769, green: 0.525, blue: 0.141)      // golden hour
    static let beautyUI = UIColor(red: 0.769, green: 0.525, blue: 0.141, alpha: 1)

    static let service = Color(red: 0.35, green: 0.52, blue: 0.58)        // weathered slate blue
    static let serviceUI = UIColor(red: 0.35, green: 0.52, blue: 0.58, alpha: 1)

    static let custom = Color(red: 0.58, green: 0.53, blue: 0.48)         // driftwood warm gray
    static let customUI = UIColor(red: 0.58, green: 0.53, blue: 0.48, alpha: 1)
}
