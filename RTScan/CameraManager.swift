import AVFoundation
import SwiftUI
import Combine

/// Owns the AVCaptureSession, throttles frame sampling, runs OCR on frames,
/// and resolves detected text into Rotten Tomatoes matches.
final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var currentMatch: TitleMatch?
    @Published var isAuthorized = false

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "rtscan.session.queue")
    private let videoQueue = DispatchQueue(label: "rtscan.video.queue")
    private let textDetector = TextDetector()

    private var lastScanTime: Date = .distantPast
    private let scanInterval: TimeInterval = 1.2
    private var lastShownTitles: Set<String> = []
    private var isResolving = false

    private var activeDevice: AVCaptureDevice?
    private var zoomFactor: CGFloat = 1.0

    func requestAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.configureSession() }
                }
            }
        default:
            isAuthorized = false
        }
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
                self.activeDevice = device
            }

            self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
            self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func setZoom(scaleDelta: CGFloat) {
        guard let device = activeDevice else { return }
        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 8.0)
        let newFactor = min(max(zoomFactor * scaleDelta, 1.0), maxZoom)
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = newFactor
            device.unlockForConfiguration()
        } catch {}
    }

    func commitZoom() {
        zoomFactor = activeDevice?.videoZoomFactor ?? zoomFactor
    }

    /// Lets the user dismiss the current popup and re-scan for a new title.
    func dismissCurrentMatch() {
        DispatchQueue.main.async { [weak self] in
            self?.currentMatch = nil
            self?.lastShownTitles.removeAll()
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastScanTime) >= scanInterval, !isResolving else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        lastScanTime = now

        let candidates = textDetector.detectCandidates(in: pixelBuffer, orientation: .right)
        guard !candidates.isEmpty else { return }

        isResolving = true
        Task { [weak self] in
            guard let self else { return }
            await self.resolve(candidates: candidates)
            self.isResolving = false
        }
    }

    private func resolve(candidates: [String]) async {
        for candidate in candidates.prefix(3) {
            if lastShownTitles.contains(candidate.lowercased()) { continue }
            if let match = await OMDbService.shared.lookup(titleQuery: candidate) {
                lastShownTitles.insert(candidate.lowercased())
                await MainActor.run {
                    self.currentMatch = match
                }
                return
            }
        }
    }
}
