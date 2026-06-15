import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Paste the base64 key the Mac menu-bar app copies (Glance → Copy pairing key).
/// QR scanning is the eventual UX; paste works today and keeps the secret off any
/// network. Restyled to match the website's calm dark/blue brand.
struct PairingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var keyText = ""
    @State private var error: String?

    private var trimmed: String { keyText.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack {
            Color.glanceBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero
                    steps
                    keyField
                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(Color.glanceRed)
                    }
                    pairButton
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
        .tint(.glanceBlue)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(Color.glanceSurface).frame(width: 64, height: 64)
                Circle().strokeBorder(Color.glanceBorder, lineWidth: 1).frame(width: 64, height: 64)
                Image(systemName: "lock.iphone")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.glanceBlue)
            }
            Text("Pair with your Mac")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.glanceInk)
            Text("One shared key links the two devices. It never leaves them — no account, no server.")
                .font(.callout)
                .foregroundStyle(Color.glanceMuted)
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 14) {
            step(1, "Click **Glance** in your Mac’s menu bar.")
            step(2, "Choose **Copy pairing key**.")
            step(3, "Paste it below and tap **Pair**.")
        }
        .glanceCard(padding: 18)
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.glanceBlueHi)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.glanceBlue.opacity(0.16)))
            Text(text)
                .font(.callout)
                .foregroundStyle(Color.glanceInk)
            Spacer(minLength: 0)
        }
    }

    private var keyField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PAIRING KEY")
                    .font(.caption.weight(.semibold)).tracking(0.8)
                    .foregroundStyle(Color.glanceFaint)
                Spacer()
                #if canImport(UIKit)
                Button {
                    if let s = UIPasteboard.general.string { keyText = s; error = nil }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .font(.caption.weight(.semibold))
                }
                #endif
            }
            TextField("base64 key", text: $keyText, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(2...4)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Color.glanceInk)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.glanceBg2))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.glanceBorder, lineWidth: 1))
        }
    }

    private var pairButton: some View {
        Button {
            do { try model.pair(base64Key: keyText); error = nil }
            catch { self.error = "That key doesn’t look right — it should be a 32-byte base64 string." }
        } label: {
            Text("Pair")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(trimmed.isEmpty ? Color.glanceSurfaceHi : Color.glanceBlue))
                .foregroundStyle(trimmed.isEmpty ? Color.glanceFaint : Color.white)
        }
        .disabled(trimmed.isEmpty)
    }
}
