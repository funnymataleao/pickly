import AVFoundation
import SwiftUI
import UIKit

struct BarcodeScannerView: UIViewRepresentable {
    enum ScannerError {
        case cameraUnavailable
        case configurationFailed
    }

    let onCodeScanned: (String) -> Void
    let onFailure: (ScannerError) -> Void
    let isActive: Bool

    func makeUIView(context: Context) -> ScannerPreviewView {
        let view = ScannerPreviewView()
        context.coordinator.configure(previewView: view)
        return view
    }

    func updateUIView(_ uiView: ScannerPreviewView, context: Context) {
        uiView.previewLayer.videoGravity = .resizeAspectFill
        context.coordinator.setActive(isActive)
    }

    static func dismantleUIView(_ uiView: ScannerPreviewView, coordinator: Coordinator) {
        coordinator.stop()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCodeScanned: onCodeScanned,
            onFailure: onFailure,
            isActive: isActive
        )
    }
}

final class ScannerPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

extension BarcodeScannerView {
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let captureSession = AVCaptureSession()
        private let sessionQueue = DispatchQueue(label: "pickly.barcode-scanner.session")
        private let onCodeScanned: (String) -> Void
        private let onFailure: (ScannerError) -> Void
        private var isActive: Bool
        private var isConfigured = false
        private var didScanCode = false

        init(
            onCodeScanned: @escaping (String) -> Void,
            onFailure: @escaping (ScannerError) -> Void,
            isActive: Bool
        ) {
            self.onCodeScanned = onCodeScanned
            self.onFailure = onFailure
            self.isActive = isActive
        }

        func configure(previewView: ScannerPreviewView) {
            previewView.previewLayer.session = captureSession

            sessionQueue.async { [weak self] in
                self?.configureSessionIfNeeded()
                self?.updateRunningState()
            }
        }

        func stop() {
            setActive(false)
        }

        func setActive(_ isActive: Bool) {
            if isActive {
                DispatchQueue.main.async { [weak self] in
                    self?.didScanCode = false
                }
            }

            sessionQueue.async { [weak self] in
                guard let self else { return }
                self.isActive = isActive
                self.updateRunningState()
            }
        }

        private func configureSessionIfNeeded() {
            guard !isConfigured else { return }

            guard let videoDevice = AVCaptureDevice.default(for: .video) else {
                notifyFailure(.cameraUnavailable)
                return
            }

            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)

                guard captureSession.canAddInput(videoInput) else {
                    notifyFailure(.configurationFailed)
                    return
                }

                let metadataOutput = AVCaptureMetadataOutput()
                guard captureSession.canAddOutput(metadataOutput) else {
                    notifyFailure(.configurationFailed)
                    return
                }

                captureSession.beginConfiguration()
                captureSession.addInput(videoInput)
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: .main)

                let supportedTypes: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce, .itf14]
                metadataOutput.metadataObjectTypes = supportedTypes.filter {
                    metadataOutput.availableMetadataObjectTypes.contains($0)
                }
                captureSession.commitConfiguration()
                isConfigured = true
            } catch {
                notifyFailure(.configurationFailed)
            }
        }

        private func updateRunningState() {
            guard isConfigured else { return }

            if isActive {
                if !captureSession.isRunning {
                    captureSession.startRunning()
                }
            } else if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }

        private func notifyFailure(_ error: ScannerError) {
            DispatchQueue.main.async { [onFailure] in
                onFailure(error)
            }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !didScanCode,
                  let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let code = metadataObject.stringValue else {
                return
            }

            didScanCode = true
            stop()
            onCodeScanned(code)
        }
    }
}
