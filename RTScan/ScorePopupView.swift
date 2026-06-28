import SwiftUI

/// Floating, color-coded score card. Tapping it opens the Rotten Tomatoes page.
struct ScorePopupView: View {
    let match: TitleMatch
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: match.tier.icon)
                .font(.system(size: 28))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(match.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(match.rtPercent)%")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text(match.tier.label)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 20))
            }
        }
        .padding(14)
        .background(match.tier.color)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            openURL(match.rtURL)
        }
        .padding(.horizontal, 16)
    }
}
