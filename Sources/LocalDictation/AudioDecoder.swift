@preconcurrency import AVFoundation
import Foundation

enum AudioDecodeFailure: Error {
    case emptyFile
    case converterUnavailable
    case emptyInputBuffer
    case emptyConvertedBuffer
}

private final class OneShotAudioBufferFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: AVAudioPCMBuffer?

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func take() -> AVAudioPCMBuffer? {
        lock.lock()
        defer { lock.unlock() }
        defer { buffer = nil }
        return buffer
    }
}

enum AudioDecoder {
    static func decodeToFloatArray(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0 else { throw AudioDecodeFailure.emptyFile }
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioDecodeFailure.converterUnavailable
        }
        guard let converter = AVAudioConverter(from: file.processingFormat, to: targetFormat) else {
            throw AudioDecodeFailure.converterUnavailable
        }
        guard let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw AudioDecodeFailure.emptyInputBuffer
        }
        try file.read(into: inputBuffer)
        guard inputBuffer.frameLength > 0 else { throw AudioDecodeFailure.emptyInputBuffer }

        let ratio = targetFormat.sampleRate / file.processingFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio) + 1024
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            throw AudioDecodeFailure.emptyConvertedBuffer
        }
        let feed = OneShotAudioBufferFeed(buffer: inputBuffer)
        var conversionError: NSError?
        converter.convert(to: outputBuffer, error: &conversionError) { _, status in
            guard let nextBuffer = feed.take() else {
                status.pointee = .noDataNow
                return nil
            }
            status.pointee = .haveData
            return nextBuffer
        }
        if let conversionError { throw conversionError }
        guard outputBuffer.frameLength > 0, let channels = outputBuffer.floatChannelData else {
            throw AudioDecodeFailure.emptyConvertedBuffer
        }
        return Array(UnsafeBufferPointer(
            start: channels[0],
            count: Int(outputBuffer.frameLength)
        ))
    }
}
