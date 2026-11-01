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

    /// 算力单元降级链：大的 UNet 建不了 ANE 执行计划时，自动往下退
    private static let unitOrder: [MLComputeUnits] = [.cpuAndNeuralEngine, .all, .cpuAndGPU, .cpuOnly]
    private var unitIndex = 0

    struct Request {
        var prompt: String
        var negative: String
        var steps: Int
        var guidance: Float
        var seed: UInt32
        var resolution: Int
        var kind: ModelKind
    }

    var unitName: String {
        switch Self.unitOrder[min(unitIndex, Self.unitOrder.count - 1)] {
        case .cpuAndNeuralEngine: return "神经引擎"
        case .cpuAndGPU: return "GPU"
        case .cpuOnly: return "CPU"
        default: return "全部"
        }
    }

    func cancel() {
        cancelFlag = true
    }

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

            var lastError: Error?
            var attempt = 0

            while attempt < Self.unitOrder.count {
                if self.cancelFlag {
                    completion(.failure(EngineError.cancelled))
                    return
                }
                do {
                    let pipe = try self.pipeline(for: model)

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

                    if self.cancelFlag {
                        completion(.failure(EngineError.cancelled))
                        return
                    }
                    guard let image = images.first ?? nil else { throw EngineError.noImage }
                    completion(.success(UIImage(cgImage: image)))
                    return
                } catch {
                    if let e = error as? EngineError, e == .cancelled {
                        completion(.failure(e))
                        return
                    }
                    lastError = error
                    attempt += 1
                    // 换下一个算力单元重试
                    self.pipeline?.unloadResources()
                    self.pipeline = nil
                    self.loadedKey = nil
                    self.unitIndex = min(self.unitIndex + 1, Self.unitOrder.count - 1)
                    if attempt >= Self.unitOrder.count { break }
                }
            }

            completion(.failure(lastError ?? EngineError.notReady))
        }
    }

    // MARK: - 私有

    private func makePipeline(model: InstalledModel, units: MLComputeUnits) throws -> any StableDiffusionPipelineProtocol {
        let config = MLModelConfiguration()
        config.computeUnits = units

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
        return built
    }

    private func pipeline(for model: InstalledModel) throws -> any StableDiffusionPipelineProtocol {
        let key = model.url.path + "#" + model.kind.rawValue + "#\(unitIndex)"
        if let pipeline, loadedKey == key { return pipeline }

        pipeline?.unloadResources()
        pipeline = nil
        loadedKey = nil

        var lastError: Error?
        for index in unitIndex..<Self.unitOrder.count {
            do {
                let built = try makePipeline(model: model, units: Self.unitOrder[index])
                self.pipeline = built
                self.loadedKey = key
                self.unitIndex = index
                return built
            } catch {
                lastError = error
                self.pipeline = nil
                self.loadedKey = nil
            }
        }
        throw lastError ?? EngineError.notReady
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
        case .notReady: return "模型没准备好"
        }
    }
}
