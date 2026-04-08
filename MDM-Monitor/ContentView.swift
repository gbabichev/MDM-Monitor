//
//  ContentView.swift
//  MDM-Monitor
//
//  Created by George Babichev on 4/2/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var monitor: MDMCheckInMonitor
    @State private var showSettings = false
    @State private var selectedDirectoryURL: URL?
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MDM Check-In Monitor")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Shows a new line whenever `mdmclient` logs a Declarative Management server request.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text("\(monitor.events.count) event\(monitor.events.count == 1 ? "" : "s")")
                        .font(.headline)
                }
            }

            Text(monitor.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let logFileURL = monitor.logFileURL {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Log file")
                        .font(.footnote.weight(.semibold))
                    Text(logFileURL.path)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            if let errorText = monitor.errorText {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Log Access Error", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text(errorText)
                        .font(.callout)
                        .textSelection(.enabled)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }

            if monitor.events.isEmpty {
                ContentUnavailableView(
                    "No Check-Ins Yet",
                    systemImage: "dot.radiowaves.left.and.right",
                    description: Text("The app is waiting for a matching `mdmclient` log entry.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(monitor.events.reversed()) { event in
                    Text(event.message)
                        .font(.body.monospaced())
                        .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 420)
        .toolbar {
            Menu("Actions", systemImage: "ellipsis.circle") {
                Button("Settings", systemImage: "gearshape") {
                    showSettings = true
                }

                Divider()

                Button("Clear", systemImage: "eraser") {
                    showClearConfirmation = true
                }
                .disabled(monitor.events.isEmpty)
                .alert("Clear All Events?", isPresented: $showClearConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) {
                        monitor.clear()
                    }
                } message: {
                    Text("This will delete the entire log file and remove all recorded events. This action cannot be undone.")
                }

                if monitor.logFileURL != nil {
                    Button("Reveal Log File", systemImage: "folder") {
                        if let logFileURL = monitor.logFileURL {
                            NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
                        }
                    }
                }
            }
            .help("Additional actions")
            .sheet(isPresented: $showSettings) {
                SettingsView(monitor: monitor)
            }

            Button("Restart Stream", systemImage: "arrow.clockwise") {
                monitor.stop()
                monitor.start()
            }
            .help("Restart the log stream")

            #if DEBUG
            Button("Simulate Check-In", systemImage: "ladybug") {
                monitor.simulateCheckIn()
            }
            .help("Simulate an MDM check-in event")
            #endif
        }
    }
}

struct SettingsView: View {
    @ObservedObject var monitor: MDMCheckInMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var showFolderPicker = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Log File Location")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Current log file:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let logFileURL = monitor.logFileURL {
                        Text(logFileURL.path)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack(spacing: 12) {
                Button("Change Folder") {
                    showFolderPicker = true
                }

                Button("Reset to Default") {
                    monitor.resetToDefaultLogFile()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
        }
        .padding()
        .frame(width: 420)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let folderURL = urls.first {
                let newLogURL = folderURL.appendingPathComponent("MDM-CheckIns.log")
                monitor.setCustomLogFile(to: newLogURL)
            }
        }
    }
}
