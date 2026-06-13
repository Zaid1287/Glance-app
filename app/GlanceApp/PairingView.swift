import SwiftUI

/// Paste the base64 key the Mac menu-bar app copies (Glance → Copy pairing key).
/// QR scanning is the eventual UX; paste works today and keeps the secret off any
/// network.
struct PairingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var keyText = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Pair with your Mac").font(.title2).bold()
                    Text("On your Mac, click Glance in the menu bar → Copy pairing key, then paste it below. Both devices share this key — it never leaves your devices.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Section("Pairing key") {
                    TextField("base64 key", text: $keyText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...4)
                        .font(.system(.footnote, design: .monospaced))
                }
                if let error {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
                Button("Pair") {
                    do { try model.pair(base64Key: keyText) }
                    catch { self.error = "That key doesn't look right — it should be a 32-byte base64 string." }
                }
                .disabled(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("Glance")
        }
    }
}
