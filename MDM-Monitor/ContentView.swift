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
    @State private var showClearConfirmation = false
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.10),
                    Color.clear,
                    Color.secondary.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                headerCard

                if let errorText = monitor.errorText {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Log Access Error", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        Text(errorText)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.orange.opacity(0.18), lineWidth: 1)
                    }
                }

                Group {
                    if monitor.events.isEmpty {
                        emptyState
                    } else {
                        eventList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                }

                if let logFileURL = monitor.logFileURL {
                    footerBar(for: logFileURL)
                }
            }
            .padding(18)
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

    private var statusColor: Color {
        monitor.isRunning ? (monitor.events.isEmpty ? .orange : .green) : .red
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(statusColor.opacity(0.16))
                        .frame(width: 56, height: 56)

                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text("MDM Check-In Monitor")
                            .font(.title2.weight(.semibold))

                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            Text(monitor.isRunning ? "Active" : "Stopped")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(statusColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor.opacity(0.12), in: Capsule())
                    }

                    Text("Monitor Declarative Management check-ins and keep the local event log within reach.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                statPill(
                    title: "Status",
                    value: monitor.statusText,
                    icon: "waveform.path.ecg",
                    compact: false
                )

                statPill(
                    title: "Count",
                    value: "\(monitor.events.count)",
                    icon: "number",
                    compact: true
                )
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        }
    }

    private func statPill(title: String, value: String, icon: String, compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: compact ? 16 : 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(compact ? .headline.monospacedDigit().weight(.semibold) : .callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, 10)
        .frame(maxWidth: compact ? 116 : .infinity, alignment: .leading)
        .background(.background.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.10))
                    .frame(width: 120, height: 120)

                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 50))
                    .foregroundStyle(statusColor.opacity(0.28))
                    .scaleEffect(1.2)

                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 50))
                    .foregroundStyle(statusColor)
                    .opacity(pulseOpacity)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.4
                }
            }

            Text(monitor.isRunning ? "Waiting for check-ins" : "Monitor paused")
                .font(.title2.weight(.semibold))

            Text(
                monitor.isRunning
                ? "The monitor is active and listening for `mdmclient` Declarative Management requests. Events will appear here as they occur."
                : "The log stream is currently stopped. Start monitoring from the toolbar menu to resume capturing events."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .frame(maxWidth: 420)

            if !monitor.isRunning {
                Text("Log stream stopped")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.10), in: Capsule())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var eventList: some View {
        List(monitor.events.reversed()) { event in
            HStack(alignment: .top, spacing: 12) {
                Text(event.message.prefix(19))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 118, alignment: .leading)

                Text(event.message.dropFirst(20))
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 8)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.vertical, 8)
    }

    private func footerBar(for logFileURL: URL) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Log file")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(logFileURL.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
            } label: {
                Label("Reveal in Finder", systemImage: "arrow.up.forward.app")
                    .labelStyle(.iconOnly)
                    .font(.caption)
                    .padding(8)
            }
        }
        .buttonStyle(.plain)
        .help("Open log folder in Finder")
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
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
                VStack(alignment: .leading, spacing: 10) {
                    Label("Monitoring Source", systemImage: "dot.radiowaves.left.and.right")
                        .font(.headline)

                    Text("Choose whether to watch Apple MDM requests from `mdmclient` or JAMF Pro activity from `/var/log/jamf.log`.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Monitoring Source", selection: Binding(
                        get: { monitor.monitoringMode },
                        set: { monitor.setMonitoringMode($0) }
                    )) {
                        ForEach(MonitoringMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

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
