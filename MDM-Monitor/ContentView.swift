//
//  ContentView.swift
//  MDM-Monitor
//
//  Created by George Babichev on 4/2/26.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var monitor: MDMCheckInMonitor

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
                    HStack {
                        Button("Clear") {
                            monitor.clear()
                        }
                        .disabled(monitor.events.isEmpty)

                        if let logFileURL = monitor.logFileURL {
                            Button("Reveal Log File") {
                                NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
                            }
                        }

                        Button("Restart Stream") {
                            monitor.stop()
                            monitor.start()
                        }
                    }
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
    }
}
