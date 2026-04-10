//
//  AboutView.swift
//  MDM-Monitor
//

#if os(macOS)
import SwiftUI

struct LiveAppIconView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var refreshID = UUID()

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .scaledToFit()
            .id(refreshID)
            .frame(width: 72, height: 72)
            .onChange(of: colorScheme) { _, _ in
                DispatchQueue.main.async {
                    refreshID = UUID()
                }
            }
    }
}

struct AboutView: View {
    @ObservedObject private var updateCenter = AppUpdateCenter.shared
    private let developerWebsiteURL = URL(string: "https://georgebabichev.com")

    var body: some View {
        VStack(spacing: 18) {
            LiveAppIconView()

            VStack(spacing: 4) {
                Text(appName)
                    .font(.title.weight(.semibold))
                Text("Local check-in monitoring for MDM")
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                AboutRow(label: "Version", value: appVersion)
                AboutRow(label: "Build", value: appBuild)
                AboutRow(label: "Developer", value: "George Babichev")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let developerWebsiteURL {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.orange.opacity(0.12))
                            .frame(width: 64, height: 64)
                        if let devPhoto = NSImage(named: "gbabichev") {
                            Image(nsImage: devPhoto)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 64, height: 64)
                                                    .offset(y: 6)
                                                    .clipShape(Circle())
                                                    .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        }
                        else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(.secondary)
                        }

                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("George Babichev")
                            .font(.headline)
                        Link("georgebabichev.com", destination: developerWebsiteURL)
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            Text("MDM Monitor watches for normalized device check-ins, logs them locally, and can raise desktop notifications when new MDM or JAMF Pro activity is detected.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Button {
                    updateCenter.checkForUpdates(trigger: .manual)
                } label: {
                    Label("Check for Updates…", systemImage: "arrow.triangle.2.circlepath.circle")
                }
                .disabled(updateCenter.isChecking)

                if let lastStatusMessage = updateCenter.lastStatusMessage {
                    Text(lastStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
        Bundle.main.infoDictionary?["CFBundleName"] as? String ??
        "MDM Monitor"
    }
}

private struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}
#endif
