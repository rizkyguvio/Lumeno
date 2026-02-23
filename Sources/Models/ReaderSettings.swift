import Foundation
import SwiftUI

struct ReaderSettings: Codable, Equatable {
    var fontSize: Double = 18.0
    var fontFamily: String = "Original"
    var lineSpacing: Double = 1.6
    var letterSpacing: Double = 0.0
    var wordSpacing: Double = 0.0
    var horizontalPadding: Double = 24.0
    var isJustified: Bool = true
    var isBold: Bool = false
    
    static let fonts = [
        "Original",
        "San Francisco",
        "Charter",
        "Proxima Nova",
        "Publico",
        "Canela"
    ]
}
