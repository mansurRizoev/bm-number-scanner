import AVFoundation
import PhotosUI
import UIKit
import Vision

final class ScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate,
    PHPickerViewControllerDelegate {

    var onResult: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private let regex: NSRegularExpression
    private let hint: String
    private let galleryTitle: String
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "bm.number.scanner")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var finished = false
    private var busy = false

    init(pattern: String, hint: String, galleryTitle: String) {
        self.regex = (try? NSRegularExpression(pattern: pattern))
            ?? (try! NSRegularExpression(pattern: "\\d{6,}"))
        self.hint = hint
        self.galleryTitle = galleryTitle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildUI()
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted { self?.startCamera() } else { self?.cancel() }
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: UI

    private func buildUI() {
        let back = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        back.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        back.tintColor = .white
        back.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        let label = UILabel()
        label.text = hint
        label.textColor = .white
        label.font = .systemFont(ofSize: 17)

        let frame = UIView()
        frame.layer.borderColor = UIColor.white.cgColor
        frame.layer.borderWidth = 3
        frame.layer.cornerRadius = 32

        let gallery = UIButton(type: .system)
        gallery.setTitle(galleryTitle, for: .normal)
        gallery.setTitleColor(.white, for: .normal)
        gallery.titleLabel?.font = .systemFont(ofSize: 17)
        gallery.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        gallery.layer.borderColor = UIColor.white.cgColor
        gallery.layer.borderWidth = 1
        gallery.layer.cornerRadius = 20
        gallery.contentEdgeInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        gallery.addTarget(self, action: #selector(pickFromGallery), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [label, frame, gallery])
        stack.axis = .vertical
        stack.alignment = .center
        stack.setCustomSpacing(48, after: label)
        stack.setCustomSpacing(32, after: frame)

        for v in [back, stack, frame, gallery] { v.translatesAutoresizingMaskIntoConstraints = false }
        view.addSubview(back)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            back.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            back.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            back.widthAnchor.constraint(equalToConstant: 48),
            back.heightAnchor.constraint(equalToConstant: 48),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            frame.widthAnchor.constraint(equalToConstant: 260),
            frame.heightAnchor.constraint(equalToConstant: 260),
            gallery.heightAnchor.constraint(equalToConstant: 52),
            gallery.widthAnchor.constraint(greaterThanOrEqualToConstant: 220)
        ])
    }

    // MARK: Camera

    private func startCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return cancel() }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) { session.addOutput(output) }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        queue.async { self.session.startRunning() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard !finished, !busy, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        busy = true
        recognize(VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .right)) { [weak self] value in
            self?.busy = false
            if let value = value { self?.finish(with: value) }
        }
    }

    // MARK: OCR

    private func recognize(_ handler: VNImageRequestHandler, completion: @escaping (String?) -> Void) {
        let request = VNRecognizeTextRequest { [weak self] request, _ in
            guard let self = self else { return completion(nil) }
            let lines = (request.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string } ?? []
            for line in lines {
                let cleaned = line.replacingOccurrences(of: "[\\s-]", with: "", options: .regularExpression)
                let range = NSRange(cleaned.startIndex..., in: cleaned)
                if let m = self.regex.firstMatch(in: cleaned, range: range), let r = Range(m.range, in: cleaned) {
                    return completion(String(cleaned[r]))
                }
            }
            completion(nil)
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        DispatchQueue.global(qos: .userInitiated).async {
            do { try handler.perform([request]) } catch { completion(nil) }
        }
    }

    // MARK: Gallery

    @objc private func pickFromGallery() {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self = self, let cg = (object as? UIImage)?.cgImage else { return }
            self.recognize(VNImageRequestHandler(cgImage: cg)) { value in
                DispatchQueue.main.async {
                    if let value = value { self.finish(with: value) } else { self.showNotFound() }
                }
            }
        }
    }

    private func showNotFound() {
        let alert = UIAlertController(title: nil, message: "Номер не найден", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: Finish

    private func finish(with value: String) {
        DispatchQueue.main.async {
            guard !self.finished else { return }
            self.finished = true
            self.session.stopRunning()
            self.dismiss(animated: true) { self.onResult?(value) }
        }
    }

    @objc private func cancel() {
        guard !finished else { return }
        finished = true
        session.stopRunning()
        dismiss(animated: true) { self.onCancel?() }
    }
}
