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
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Circle()
                        .fill(monitor.isRunning ? (monitor.events.isEmpty ? Color.orange : Color.green) : Color.red)
                        .frame(width: 8, height: 8)
                    Text("MDM Check-In Monitor")
                        .font(.headline)
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Status bar
            HStack {
                Text(monitor.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("\(monitor.events.count) event\(monitor.events.count == 1 ? "" : "s")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.secondary.opacity(0.06))

            Divider()

            // Events list
            if monitor.events.isEmpty {
                VStack(spacing: 16) {
                    Spacer()

                    ZStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.3))
                            .scaleEffect(1.2)

                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                            .opacity(pulseOpacity)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            pulseOpacity = 0.4
                        }
                    }

                    Text("Waiting for check-ins")
                        .font(.title2.weight(.semibold))
                    Text("The monitor is active and listening for `mdmclient` Declarative Management requests.\nEvents will appear here as they occur.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    if !monitor.isRunning {
                        Text("The log stream is currently stopped.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.orange.opacity(0.1), in: Capsule())
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(monitor.events.reversed()) { event in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(event.message.prefix(19))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(event.message.dropFirst(20))
                            .font(.body)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }

            // Footer with log path
            if let logFileURL = monitor.logFileURL {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(5)
                    Text(logFileURL.path)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
                    } label: {
                        Label("Reveal in Finder", systemImage: "arrow.up.forward.app")
                            .labelStyle(.iconOnly)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .padding(5)
                    .help("Open log folder in Finder")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.secondary.opacity(0.06))
            }

            if let errorText = monitor.errorText {
                Divider()
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
                .padding(12)
            }
        }
        .frame(minWidth: 680, minHeight: 420)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .alert("Clear All Events?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                monitor.clear()
            }
        } message: {
            Text("This will delete the entire log file and remove all recorded events. This action cannot be undone.")
        }
        .toolbar {
            
#if DEBUG
            Button("Simulate Check-In", systemImage: "ladybug") {
                monitor.simulateCheckIn()
            }
            .help("Simulate an MDM check-in event")
#endif
            
            Menu {
                Button("Restart Service", systemImage: "arrow.clockwise") {
                    monitor.restart()
                }

                Button("Stop Monitor", systemImage: "stop.fill") {
                    monitor.stop()
                }
                .disabled(!monitor.isRunning)

                Button("Start Monitor", systemImage: "play.fill") {
                    monitor.start()
                }
                .disabled(monitor.isRunning)

                Divider()
                
                Button("Clear Log", systemImage: "eraser") {
                    showClearConfirmation = true
                }
                .disabled(monitor.events.isEmpty)

                if let logFileURL = monitor.logFileURL {
                    Button("Reveal Log File", systemImage: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
                    }
                }
            } label: {
                Label("Settings", systemImage: "gearshape")
            } primaryAction: {
                showSettings = true
            }
            .help("Open settings or monitor actions")
            .sheet(isPresented: $showSettings) {
                SettingsView(monitor: monitor)
            }

        }
    }
}

struct SettingsView: View {
    @ObservedObject var monitor: MDMCheckInMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var showFolderPicker = false

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.orange.opacity(0.14))
                        .frame(width: 52, height: 52)

                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.title2.weight(.semibold))
                    Text("Choose where check-in events are written and manage the saved log location.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Log File Location", systemImage: "doc.text")
                        .font(.headline)
                    Text("The monitor appends new check-ins to this file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Current log file")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    if let logFileURL = monitor.logFileURL {
                        Text(logFileURL.path)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.quaternary, lineWidth: 1)
                            }
                    } else {
                        Text("No log file configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.quaternary, lineWidth: 1)
                            }
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Change Folder") {
                    showFolderPicker = true
                }
                .buttonStyle(.borderedProminent)

                Button("Reset to Default") {
                    monitor.resetToDefaultLogFile()
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.escape)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.regularMaterial)
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(.orange.opacity(0.16))
                        .frame(width: 220, height: 220)
                        .blur(radius: 18)
                        .offset(x: -34, y: -46)
                }
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                }
        }
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
