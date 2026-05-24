import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            RoundedRectangle(cornerRadius: 20)
                .fill(.secondary.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                )

            VStack(spacing: 4) {
                Text("Jisticle")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("A native macOS GitHub Gist client built with SwiftUI.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Link("github.com/adamghill/jisticle", destination: URL(string: "https://github.com/adamghill/jisticle")!)
                    .font(.callout)

                Text("© 2025 Adam Hill. All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}

#Preview {
    AboutView()
}
