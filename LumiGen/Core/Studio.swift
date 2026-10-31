import SwiftUI
import Combine
import UIKit

enum GenPhase: Equatable {
    case idle
    case preparing(String)
    case sampling(step: Int, total: Int)
    case done
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .preparing, .sampling: return true
        default: return false
        }
    }

    var caption: String {
        switch self {
        case .idle: return ""
        case .preparing(let text): return text
        case .sampling(let step, let total): return "\(step) / \(total) 步"
        case .done: return "已完成"
        case .failed: return "出错了"
        }
    }

    var fraction: Double {
        switch self {
        case .sampling(let step, let total):
            guard total > 0 else { return 0 }
            return min(1, Double(step) / Double(total))
        case .preparing: return 0.04
        case .done: return 1
        default: return 0
        }
    }
}

/// 全局状态
final class Studio: ObservableObject {

    @Published var prompt: String = ""
    @Published var styleID: String = "anime"
    @Published var resolutionOverride: Int = 0
    @Published var phase: GenPhase = .idle
    @Published var image: UIImage?
    @Published var seed: UInt32 = 0
    @Published var banner: String?
    @Published var showSetup: Bool = false
    @Published var showSettings: Bool = false
    @Published var lastSeconds: Double = 0
    @Published var isSaved: Bool = false

    let engine = GeneratorEngine()
    let library = ModelLibrary()
    let installer = ModelInstaller()

    private var bag = Set<AnyCancellable>()
    private var startedAt = Date()
    private var bannerWork: DispatchWorkItem?

    init() {
        library.objectWillChange
            .merge(with: installer.objectWillChange)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
    }

    // MARK: - 派生状态

    var style: StylePreset {
        StylePreset.all.first { $0.id == styleID } ?? StylePreset.all[0]
    }

    var model: InstalledModel? { library.current }

    var resolution: Int {
        if resolutionOverride > 0 { return resolutionOverride }
        return model?.resolution ?? 768
    }

    var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && model != nil
        && !phase.isBusy
    }

    var isBusy: Bool { phase.isBusy }

    // MARK: - 生成

    func generate() {
        guard let model else {
            showSetup = true
            return
        }
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !phase.isBusy else { return }

        seed = seed == 0 ? UInt32.random(in: 1...4_000_000_000) : seed &+ 1
        let request = GeneratorEngine.Request(
            prompt: style.prompt(from: text),
            negative: StylePreset.baseNegative,
            steps: style.steps ?? model.steps,
            guidance: model.guidance,
            seed: seed,
            resolution: resolution,
            kind: model.kind
        )

        isSaved = false
        startedAt = Date()
        phase = .preparing("唤醒模型…")

        engine.generate(model: model, request: request, onProgress: { [weak self] step, total in
            DispatchQueue.main.async {
                guard let self, self.phase.isBusy else { return }
                self.phase = .sampling(step: step, total: total)
            }
        }, completion: { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let output):
                    self.image = output
                    self.lastSeconds = Date().timeIntervalSince(self.startedAt)
                    self.phase = .done
                case .failure(let error):
                    if let engineError = error as? EngineError, engineError == .cancelled {
                        self.phase = .idle
                    } else {
                        self.phase = .failed(error.localizedDescription)
                        self.showBanner("生成失败：\(error.localizedDescription)")
                    }
                }
            }
        })
    }

    func cancel() {
        engine.cancel()
        phase = .idle
    }

    // MARK: - 小提示

    func showBanner(_ text: String) {
        banner = text
        bannerWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.25)) { self?.banner = nil }
        }
        bannerWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: work)
    }
}
