import Foundation
import AVFoundation
import AcornForestCore

/// 에셋 파일 없이 소리를 만든다.
/// 배경 ASMR은 잡음을 걸러 만든 4초짜리 루프를 돌리고, 병 뚜껑 소리는 짧게 합성한다.
@MainActor
final class ForestAudio {
    static let shared = ForestAudio()

    private let engine = AVAudioEngine()
    private let ambientPlayer = AVAudioPlayerNode()
    private let effectPlayer = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var isPrepared = false
    private var preparedFormat: AVAudioFormat?

    private init() {}

    var currentTrack: AmbientTrack?

    // MARK: - 공개 API

    func playAmbient(_ track: AmbientTrack) {
        guard prepare() else { return }
        guard let buffer = makeBuffer(for: track) else { return }
        currentTrack = track
        ambientPlayer.stop()
        ambientPlayer.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        ambientPlayer.volume = 0.42
        ambientPlayer.play()
        startEngineIfNeeded()
    }

    func stopAmbient() {
        ambientPlayer.stop()
        currentTrack = nil
    }

    func playJarPop() {
        guard prepare() else { return }
        guard let buffer = makePopBuffer() else { return }
        effectPlayer.stop()
        effectPlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        effectPlayer.volume = 0.5
        effectPlayer.play()
        startEngineIfNeeded()
    }

    // MARK: - 준비

    private func prepare() -> Bool {
        if isPrepared { return true }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return false
        }
        preparedFormat = format
        engine.attach(ambientPlayer)
        engine.attach(effectPlayer)
        engine.connect(ambientPlayer, to: engine.mainMixerNode, format: format)
        engine.connect(effectPlayer, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.8
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
        isPrepared = true
        return true
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            isPrepared = false
        }
    }

    // MARK: - 합성

    private func makeBuffer(for track: AmbientTrack) -> AVAudioPCMBuffer? {
        guard let format = preparedFormat else { return nil }
        let frames = AVAudioFrameCount(sampleRate * 4)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let channel = buffer.floatChannelData?[0] else { return nil }

        var noise = RustleNoise(seed: UInt64(0x51A7_2026) &+ UInt64(track.rawValue.count))
        var low: Float = 0
        var band: Float = 0
        var bubble: Float = 0

        for index in 0..<Int(frames) {
            let white = Float(noise.nextUnit()) - 0.5
            low += (white - low) * 0.015
            band += (white - band) * 0.32
            let seconds = Double(index) / sampleRate
            var sample: Float

            switch track {
            case .rain:
                sample = band * 0.42 + low * 0.55
                if noise.nextUnit() < 0.0012 {
                    sample += 0.22
                }
            case .hearth:
                sample = low * 1.05
                if noise.nextUnit() < 0.0032 {
                    sample += Float(noise.nextUnit()) * 0.42
                }
            case .simmer:
                bubble *= 0.995
                if noise.nextUnit() < 0.0025 {
                    bubble = Float(noise.nextUnit()) * 0.35
                }
                sample = low * 0.55 + bubble
                    + sin(Float(seconds * 2 * Double.pi * 86)) * 0.035
            case .nightInsects:
                let pulse = Float(max(0, sin(seconds * 2 * Double.pi * 0.8)))
                let chirp = sin(Float(seconds * 2 * Double.pi * 4200)) * 0.09 * pulse
                sample = low * 0.45 + chirp
            case .windChime:
                let sway = Float(0.5 + 0.5 * sin(seconds * 2 * Double.pi * 0.17))
                sample = low * 0.4
                    + sin(Float(seconds * 2 * Double.pi * 1320)) * 0.05 * sway
                    + sin(Float(seconds * 2 * Double.pi * 1980)) * 0.03 * sway
                if noise.nextUnit() < 0.0009 {
                    sample += 0.16
                }
            }

            // 4초 루프의 이음매가 들리지 않게 앞뒤를 살짝 눌러 준다.
            let edge = min(1.0, min(seconds / 0.25, (4.0 - seconds) / 0.25))
            channel[index] = max(-1, min(1, sample)) * Float(max(0, edge)) * 0.85
        }
        return buffer
    }

    private func makePopBuffer() -> AVAudioPCMBuffer? {
        guard let format = preparedFormat else { return nil }
        let duration = 0.32
        let frames = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let channel = buffer.floatChannelData?[0] else { return nil }

        var noise = RustleNoise(seed: 0x0B0B_2026)
        for index in 0..<Int(frames) {
            let seconds = Double(index) / sampleRate
            let decay = Float(exp(-seconds * 14))
            let pitch = Float(760 - 380 * (seconds / duration))
            let body = sin(Float(seconds * 2 * Double.pi * Double(pitch))) * decay
            let click = Float(noise.nextUnit() - 0.5) * Float(exp(-seconds * 90)) * 0.5
            let glass = sin(Float(seconds * 2 * Double.pi * 2340)) * decay * 0.18
            channel[index] = max(-1, min(1, body * 0.45 + click + glass))
        }
        return buffer
    }
}

/// 아주 작은 선형 합동 난수. 소리 합성에만 쓴다.
private struct RustleNoise {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func nextUnit() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let slice = (state >> 33) & 0x7FFF_FFFF
        return Double(slice) / Double(0x7FFF_FFFF)
    }
}
