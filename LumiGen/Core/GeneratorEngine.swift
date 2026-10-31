import Foundation
import CoreML
import UIKit

/// 包在苹果 ml-stable-diffusion 之上的生成引擎
final class GeneratorEngine {

    private var pipeline: (any StableDiffusionPipelineProtocol)?
    private var loadedKey: String?

    private let queue = DispatchQueue(label: "lumigen.engine", qos: .userInitiated)
    private var cancelFlag = false
    private(set) var isBusy = false

    struct Request {
        var prompt: String
        var negative: String
        var steps: Int
        var guidance: Float
        var seed: UInt32
        var resolution: Int
        var kind: ModelKind
    }

    func cancel() {
        cancelFlag = true
    }

    /// 预热：把模型常驻进内存，第一次出图就不必再等
    func preload(model: InstalledModel) {
        queue.async { [weak self] in
            guard let self else { return }
            _ = try? self.pipeline(for: model)
        }
    }

    /// 卸载，释放内存
    func unload() {
        queue.async { [weak self] in
            guard let self else { return }
            self.pipeline?.unloadResources()
            self.pipeline = nil
            self.loadedKey = nil
        }
    }

    func generate(model: InstalledModel,
                  request: Request,
                  onProgress: @escaping (Int, Int) -> Void,
                  completion: @escaping (Result<UIImage, Error>) -> Void) {

        cancelFlag = false
        isBusy = true

        queue.async { [weak self] in
            guard let self else { return }
            defer { self.isBusy = false }

            do {
                let pipe = try self.pipeline(for: model)
                if self.cancelFlag { throw EngineError.cancelled }

                var config = PipelineConfiguration(prompt: request.prompt)
                config.negativePrompt = request.negative
                config.stepCount = request.steps
                config.guidanceScale = request.guidance
                config.seed = request.seed
                config.imageCount = 1
                config.schedulerType = .dpmSolverMultistepScheduler
                config.rngType = .numpyRNG
                config.disableSafety = true
                config.useDenoisedIntermediates = false
                config.targetSize = Float(request.resolution)
                config.originalSize = Float(request.resolution)
                config.cropsCoordsTopLeft = 0
                config.strength = 1.0

                let images = try pipe.generateImages(configuration: config) { [weak self] progress in
                    onProgress(progress.step, progress.stepCount)
                    return !(self?.cancelFlag ?? true)
                }

                if self.cancelFlag { throw EngineError.cancelled }

                guard let image = images.first ?? nil else { throw EngineError.noImage }
                completion(.success(UIImage(cgImage: image)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - 私有

    private func pipeline(for model: InstalledModel) throws -> any StableDiffusionPipelineProtocol {
        let key = model.url.path + "#" + model.kind.rawValue
        if let pipeline, loadedKey == key { return pipeline }

        pipeline?.unloadResources()

        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine

        let built: any StableDiffusionPipelineProtocol
        switch model.kind {
        case .sdxl:
            built = try StableDiffusionXLPipeline(resourcesAt: model.url,
                                                  configuration: config,
                                                  reduceMemory: model.reduceMemory)
        case .sd15:
            built = try StableDiffusionPipeline(resourcesAt: model.url,
                                                controlNet: [],
                                                configuration: config,
                                                disableSafety: true,
                                                reduceMemory: model.reduceMemory)
        }

        try built.loadResources()
        self.pipeline = built
        self.loadedKey = key
        return built
    }
}

enum EngineError: LocalizedError, Equatable {
    case cancelled
    case noImage
    case notReady

    var errorDescription: String? {
        switch self {
        case .cancelled: return "已取消"
        case .noImage: return "模型没有返回图片"
        case .notReady: return "模型还没准备好"
        }
    }
}
