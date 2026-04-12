import SwiftUI

struct ProfileButtonView: View {
    let firstName: String?
    let photoURL: URL?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.space1) {
                profileImage
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())

                if let name = firstName {
                    Text(name)
                        .font(Typography.labelMD)
                        .foregroundStyle(Color("textPrimary"))
                        .lineLimit(1)
                }
            }
        }
        .accessibilityIdentifier("SettingsButton")
    }

    @ViewBuilder
    private var profileImage: some View {
        if let photoURL {
            AsyncImage(url: photoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    initialsOrIcon
                @unknown default:
                    initialsOrIcon
                }
            }
        } else {
            initialsOrIcon
        }
    }

    @ViewBuilder
    private var initialsOrIcon: some View {
        if let initial = firstName?.first.map(String.init) {
            Circle()
                .fill(Color("accentPrimary"))
                .overlay(
                    Text(initial.uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                )
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color("textSecondary"))
        }
    }
}

#Preview("With name — initials avatar") {
    ProfileButtonView(
        firstName: "Andres",
        photoURL: nil,
        action: {}
    )
    .padding()
    .background(Color("bgPrimary"))
}

#Preview("No name, no photo — icon fallback") {
    ProfileButtonView(
        firstName: nil,
        photoURL: nil,
        action: {}
    )
    .padding()
    .background(Color("bgPrimary"))
}

#Preview("Dark mode") {
    ProfileButtonView(
        firstName: "Andres",
        photoURL: nil,
        action: {}
    )
    .padding()
    .background(Color("bgPrimary"))
    .preferredColorScheme(.dark)
}
