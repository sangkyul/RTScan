import SwiftUI

/// Tier of a Rotten Tomatoes score, used to color-code the popup.
enum ScoreTier {
    case certifiedFresh   // >= 75%
    case fresh            // 60-74%
    case mixed            // 40-59%
    case rotten           // < 40%

    init(percent: Int) {
        switch percent {
        case 75...: self = .certifiedFresh
        case 60..<75: self = .fresh
        case 40..<60: self = .mixed
        default: self = .rotten
        }
    }

    var color: Color {
        switch self {
        case .certifiedFresh: return Color(red: 0.0, green: 0.55, blue: 0.2)
        case .fresh: return Color(red: 0.2, green: 0.75, blue: 0.3)
        case .mixed: return Color(red: 0.95, green: 0.65, blue: 0.1)
        case .rotten: return Color(red: 0.85, green: 0.15, blue: 0.15)
        }
    }

    var icon: String {
        switch self {
        case .certifiedFresh: return "checkmark.seal.fill"
        case .fresh: return "circle.fill"
        case .mixed: return "minus.circle.fill"
        case .rotten: return "xmark.seal.fill"
        }
    }

    var label: String {
        switch self {
        case .certifiedFresh: return "Certified Fresh"
        case .fresh: return "Fresh"
        case .mixed: return "Mixed"
        case .rotten: return "Rotten"
        }
    }
}

/// A resolved title match with its Rotten Tomatoes score.
struct TitleMatch: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let year: String?
    let rtPercent: Int
    let rtURL: URL

    var tier: ScoreTier { ScoreTier(percent: rtPercent) }

    static func == (lhs: TitleMatch, rhs: TitleMatch) -> Bool {
        lhs.title == rhs.title && lhs.rtPercent == rhs.rtPercent
    }
}
