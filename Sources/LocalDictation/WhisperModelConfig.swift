import Foundation
import WhisperKit

enum WhisperModelConfig {
    static let modelIdentifier = "openai_whisper-large-v3-v20240930_turbo_632MB"
    static let language = "ru"

    private static var applicationSupportRoot: URL? {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("Local Dictation", isDirectory: true)
    }

    static var modelFolder: URL? {
        guard let applicationSupportRoot else { return nil }
        let folder = applicationSupportRoot
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(modelIdentifier, isDirectory: true)
        guard FileManager.default.fileExists(atPath: folder.path) else {
            return nil
        }
        return folder
    }

    static var tokenizerBaseFolder: URL? {
        guard let applicationSupportRoot else { return nil }
        let base = applicationSupportRoot
            .appendingPathComponent("Tokenizers", isDirectory: true)
        let repository = base
            .appendingPathComponent("models/openai/whisper-large-v3", isDirectory: true)
        let requiredFiles = ["config.json", "tokenizer_config.json", "tokenizer.json"]
        guard requiredFiles.allSatisfy({ name in
            FileManager.default.fileExists(
                atPath: repository.appendingPathComponent(name).path
            )
        }) else {
            return nil
        }
        return base
    }

    static func makeConfig() -> WhisperKitConfig? {
        guard let modelFolder, let tokenizerBaseFolder else { return nil }
        let compute = ModelComputeOptions(
            melCompute: .cpuAndGPU,
            audioEncoderCompute: .cpuAndGPU,
            textDecoderCompute: .cpuAndGPU,
            prefillCompute: .cpuAndGPU
        )
        return WhisperKitConfig(
            model: modelIdentifier,
            modelFolder: modelFolder.path,
            tokenizerFolder: tokenizerBaseFolder,
            computeOptions: compute,
            verbose: false,
            logLevel: .none,
            prewarm: true,
            load: true,
            download: false
        )
    }

    static func decodingOptions() -> DecodingOptions {
        DecodingOptions(verbose: false, task: .transcribe, language: language)
    }
}
