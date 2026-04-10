//
//  MDMCheckInMonitor.swift
//  MDM-Monitor
//
//  Created by Codex on 4/2/26.
//

import Combine
import Foundation

enum MonitoringMode: String, CaseIterable, Identifiable {
    case mdmclient
    case jamfPro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mdmclient:
            return "Intune / mdmclient"
        case .jamfPro:
            return "JAMF Pro"
        }
    }

    var statusDescription: String {
        switch self {
        case .mdmclient:
            return "Watching mdmclient logs for Declarative Management server requests..."
        case .jamfPro:
            return "Watching /var/log/jamf.log for JAMF Pro activity..."
        }
    }

    var stoppedDescription: String {
        switch self {
        case .mdmclient:
            return "mdmclient monitoring stopped."
        case .jamfPro:
            return "JAMF Pro monitoring stopped."
        }
    }
}

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
    @Published private(set) var logFileURL: URL?
    @Published private(set) var isRunning = false
    @Published private(set) var monitoringMode: MonitoringMode
    @Published private(set) var notificationsEnabled: Bool

    let liveEventPublisher = PassthroughSubject<CheckInEvent, Never>()

    private let cooldownInterval: TimeInterval = 120
    private let modeDefaultsKey = "monitoringMode"
    private let notificationsDefaultsKey = "notificationsEnabled"
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
    private var lastLoggedTimestamp: Date?

    init() {
        monitoringMode = MonitoringMode(rawValue: UserDefaults.standard.string(forKey: modeDefaultsKey) ?? "") ?? .mdmclient
        notificationsEnabled = UserDefaults.standard.object(forKey: notificationsDefaultsKey) as? Bool ?? true
        prepareLogFile()
        loadPersistedEvents()
        start()
    }

    func setNotificationsEnabled(_ isEnabled: Bool) {
        guard notificationsEnabled != isEnabled else { return }
        notificationsEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: notificationsDefaultsKey)
    }

    func setMonitoringMode(_ mode: MonitoringMode) {
        guard monitoringMode != mode else { return }
        UserDefaults.standard.set(mode.rawValue, forKey: modeDefaultsKey)

        Task { @MainActor [weak self] in
            self?.applyMonitoringMode(mode)
        }
    }

    private func applyMonitoringMode(_ mode: MonitoringMode) {
        guard monitoringMode != mode else { return }
        monitoringMode = mode
        restart()
    }

    func start() {
        guard process == nil else { return }

        errorText = nil
        buffer.removeAll(keepingCapacity: true)
        stderrBuffer.removeAll(keepingCapacity: true)

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        switch monitoringMode {
        case .mdmclient:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
            process.arguments = [
                "stream",
                "--style", "compact",
                "--info",
                "--predicate", #"process == "mdmclient""#
            ]
        case .jamfPro:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
            process.arguments = [
                "-n", "0",
                "-F", "/var/log/jamf.log"
            ]
        }
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
                self.isRunning = false
                self.updateStatusAfterExit(status: status)
            }
        }

        do {
            try process.run()
            self.process = process
            self.outputPipe = outputPipe
            self.errorPipe = errorPipe
            self.isRunning = true
            statusText = monitoringMode.statusDescription
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
        isRunning = false
        statusText = monitoringMode.stoppedDescription
    }

    func restart() {
        guard let currentProcess = process else {
            start()
            return
        }

        // Clean up handlers immediately so termination doesn't interfere
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil

        // Temporarily disable the termination handler to prevent it from clearing state
        currentProcess.terminationHandler = nil
        currentProcess.terminate()

        // Start fresh
        process = nil
        outputPipe = nil
        errorPipe = nil
        buffer.removeAll(keepingCapacity: true)
        stderrBuffer.removeAll(keepingCapacity: true)
        start()
    }

    func clear() {
        events.removeAll()
        guard let logFileURL else { return }

        do {
            try Data().write(to: logFileURL, options: .atomic)
        } catch {
            errorText = "Failed to clear log file.\n\nDetails: \(error.localizedDescription)"
        }
    }

    func setCustomLogFile(to url: URL) {
        restart()
        logFileURL = url
        loadPersistedEvents()
    }

    func resetToDefaultLogFile() {
        restart()
        buffer.removeAll(keepingCapacity: true)
        stderrBuffer.removeAll(keepingCapacity: true)
        prepareLogFile()
        loadPersistedEvents()
    }

    #if DEBUG
    func simulateCheckIn() {
        let timestamp = Date()
        let event = CheckInEvent(
            timestamp: timestamp,
            message: "\(dateFormatter.string(from: timestamp)) \(monitoringMode == .mdmclient ? "Device checked in with MDM" : "Device checked in with JAMF Pro")",
            rawLogLine: monitoringMode == .mdmclient
                ? "SIMULATED: Processing server request: DeclarativeManagement for test-device-udid"
                : "SIMULATED: Fri Apr 10 04:38:51 TestUser's Virtual Machine jamf[13474]: Checking for policies triggered by \"recurring check-in\" for user \"testuser\"..."
        )

        events.append(event)
        lastLoggedTimestamp = timestamp
        appendToLogFile(event)
        statusText = "Last event at \(dateFormatter.string(from: timestamp))"
        liveEventPublisher.send(event)
    }
    #endif

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
        switch monitoringMode {
        case .mdmclient:
            handleMDMClientLine(line)
        case .jamfPro:
            handleJamfLine(line)
        }
    }

    private func handleMDMClientLine(_ line: String) {
        guard line.contains("Processing server request:") else { return }

        let timestamp = Date()
        if let lastLoggedTimestamp,
           timestamp.timeIntervalSince(lastLoggedTimestamp) < cooldownInterval {
            statusText = "Ignored duplicate check-in within 120 seconds."
            return
        }

        let event = CheckInEvent(
            timestamp: timestamp,
            message: "\(dateFormatter.string(from: timestamp)) Device checked in with MDM",
            rawLogLine: line
        )
        recordLiveEvent(event, statusText: "Last event at \(dateFormatter.string(from: timestamp))")
    }

    private func handleJamfLine(_ line: String) {
        guard line.contains(" jamf["),
              line.contains(#"Checking for policies triggered by "recurring check-in""#)
        else {
            return
        }

        let timestamp = Date()

        let event = CheckInEvent(
            timestamp: timestamp,
            message: "\(dateFormatter.string(from: timestamp)) Device checked in with JAMF Pro",
            rawLogLine: line
        )
        recordLiveEvent(event, statusText: "Last JAMF check-in at \(dateFormatter.string(from: timestamp))")
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

            let message = monitoringMode == .mdmclient
                ? "Permission denied while reading system logs. Run the app as admin."
                : "Permission denied while reading `/var/log/jamf.log`. Confirm that the file is readable."
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
            ? monitoringMode.stoppedDescription
            : "Log stream exited with code \(status)."
    }

    private func prepareLogFile() {
        do {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let directoryURL = appSupportURL
                .appendingPathComponent(Bundle.main.bundleIdentifier ?? "MDM-Monitor", isDirectory: true)

            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            let fileURL = directoryURL.appendingPathComponent("MDM-CheckIns.log")
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }

            logFileURL = fileURL
        } catch {
            errorText = "Failed to prepare the app log file.\n\nDetails: \(error.localizedDescription)"
        }
    }

    private func loadPersistedEvents() {
        guard let logFileURL else { return }
        guard let contents = try? String(contentsOf: logFileURL, encoding: .utf8) else { return }

        events = contents
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .map { storedLine in
                CheckInEvent(
                    timestamp: dateFormatter.date(from: String(storedLine.prefix(19))) ?? .now,
                    message: storedLine,
                    rawLogLine: ""
                )
            }

        if let lastEvent = events.last {
            lastLoggedTimestamp = lastEvent.timestamp
            statusText = "Loaded \(events.count) logged event\(events.count == 1 ? "" : "s"). Last event at \(dateFormatter.string(from: lastEvent.timestamp))"
        }
    }

    private func appendToLogFile(_ event: CheckInEvent) {
        guard let logFileURL else { return }
        guard let data = "\(event.message)\n".data(using: .utf8) else { return }

        do {
            let fileHandle = try FileHandle(forWritingTo: logFileURL)
            defer { try? fileHandle.close() }
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: data)
        } catch {
            errorText = "Failed to write to the app log file.\n\nDetails: \(error.localizedDescription)"
        }
    }

    private func recordLiveEvent(_ event: CheckInEvent, statusText: String) {
        events.append(event)
        lastLoggedTimestamp = event.timestamp
        appendToLogFile(event)
        self.statusText = statusText
        liveEventPublisher.send(event)
    }

    deinit {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
    }
}
