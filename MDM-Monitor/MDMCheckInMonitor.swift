//
//  MDMCheckInMonitor.swift
//  MDM-Monitor
//
//  Created by Codex on 4/2/26.
//

import Combine
import Foundation

struct CheckInEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let rawLogLine: String
}

@MainActor
final class MDMCheckInMonitor: ObservableObject {
    @Published private(set) var events: [CheckInEvent] = []
    @Published private(set) var statusText = "Starting log stream..."
    @Published private(set) var errorText: String?

    private let predicate = #"process == "mdmclient""#
    private let targetText = "Processing server request: DeclarativeManagement for"
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var buffer = Data()
    private var stderrBuffer = Data()

    func start() {
        guard process == nil else { return }

        errorText = nil
        buffer.removeAll(keepingCapacity: true)
        stderrBuffer.removeAll(keepingCapacity: true)

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = [
            "stream",
            "--style", "compact",
            "--info",
            "--predicate", predicate
        ]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor [weak self, data] in
                self?.consume(data)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor [weak self, data] in
                self?.consumeError(data)
            }
        }

        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { @MainActor [weak self, status] in
                guard let self else { return }
                self.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self.errorPipe?.fileHandleForReading.readabilityHandler = nil
                self.process = nil
                self.outputPipe = nil
                self.errorPipe = nil
                self.updateStatusAfterExit(status: status)
            }
        }

        do {
            try process.run()
            self.process = process
            self.outputPipe = outputPipe
            self.errorPipe = errorPipe
            statusText = "Watching mdmclient logs for Declarative Management server requests..."
        } catch {
            let message = "Failed to start log stream: \(error.localizedDescription)"
            statusText = message
            errorText = message
        }
    }

    func stop() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        outputPipe = nil
        errorPipe = nil
        statusText = "Log stream stopped."
    }

    func clear() {
        events.removeAll()
    }

    private func consume(_ data: Data) {
        buffer.append(data)

        while let newlineRange = buffer.range(of: Data([0x0A])) {
            let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)
            buffer.removeSubrange(0...newlineRange.lowerBound)

            guard let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !line.isEmpty
            else {
                continue
            }

            handle(line)
        }
    }

    private func handle(_ line: String) {
        guard line.contains(targetText) else { return }

        let timestamp = Date()
        let event = CheckInEvent(
            timestamp: timestamp,
            message: "\(dateFormatter.string(from: timestamp)) Device checked in with MDM",
            rawLogLine: line
        )

        events.append(event)
        statusText = "Last event at \(dateFormatter.string(from: timestamp))"
    }

    private func consumeError(_ data: Data) {
        stderrBuffer.append(data)
    }

    private func updateStatusAfterExit(status: Int32) {
        let stderrText = String(data: stderrBuffer, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if status == 77 {
            let detail = stderrText?.isEmpty == false
                ? stderrText!
                : "macOS denied access to the live system log."

            let message = "Permission denied while reading system logs. Run the app from an admin-approved context or test `/usr/bin/log stream` in Terminal with `sudo`."
            statusText = message
            errorText = "\(message)\n\nDetails: \(detail)"
            return
        }

        if let stderrText, !stderrText.isEmpty {
            statusText = "Log stream exited with code \(status)."
            errorText = stderrText
            return
        }

        errorText = nil
        statusText = status == 0
            ? "Log stream stopped."
            : "Log stream exited with code \(status)."
    }

    deinit {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
    }
}
