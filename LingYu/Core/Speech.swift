import Foundation
import Speech
import AVFoundation

/// 长按说话：iOS 自带识别，不花 token
final class Speech: ObservableObject {

    @Published var recording = false
    @Published var text = ""
    @Published var hint: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    func begin() {
        guard !recording else { return }
        hint = nil
        Task { @MainActor in
            guard await authorized() else {
                hint = "需要麦克风与语音识别权限"
                return
            }
            guard let recognizer, recognizer.isAvailable else {
                hint = "语音识别不可用"
                return
            }
            do {
                try start(recognizer)
            } catch {
                hint = "录音失败"
            }
        }
    }

    /// 松手：结束并返回识别结果
    @discardableResult
    func end() -> String {
        guard recording else { return text }
        recording = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return text
    }

    func cancel() {
        _ = end()
        text = ""
    }

    // MARK: - 私有

    private func authorized() async -> Bool {
        let speechOK: Bool = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard speechOK else { return false }
        return await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { ok in
                cont.resume(returning: ok)
            }
        }
    }

    private func start(_ recognizer: SFSpeechRecognizer) throws {
        text = ""
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .dictation
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }
        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: req) { [weak self] result, _ in
            guard let self, let result else { return }
            let current = result.bestTranscription.formattedString
            DispatchQueue.main.async { self.text = current }
        }
        recording = true
    }
}
