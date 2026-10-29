import AVFoundation
import CoreAudio
import AudioRingSupport
import GuitarPracticeCore

struct InputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    static var defaultID: AudioDeviceID {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return id
    }
    static func all() -> [InputDevice] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            var input = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &input, 0, nil, &streamSize) == noErr, streamSize > 0 else { return nil }
            return InputDevice(id: id, uid: string(id, selector: kAudioDevicePropertyDeviceUID), name: string(id, selector: kAudioObjectPropertyName))
        }
    }
    private static func string(_ id: AudioDeviceID, selector: AudioObjectPropertySelector) -> String {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let pointer = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
        pointer.initialize(to: nil)
        defer { pointer.deinitialize(count: 1); pointer.deallocate() }
        var size = UInt32(MemoryLayout<CFString?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, pointer) == noErr, let value = pointer.pointee else { return "Unknown input" }
        return value as String
    }
}

enum AudioClock {
    static var now: Double { AVAudioTime.seconds(forHostTime: mach_absolute_time()) }
}

struct AudioObservation {
    var hostTime: Double
    var recordingTime: Double
    var level: Float
    var clipped: Bool
    var attackHostTimes: [Double]
    var analyzedStrums: [AnalyzedStrum] = []
    var sampleRate: Double = 0
    var channelCount: Int = 0
    var bufferDuration: Double = 0
    var broadbandNoise: Bool = false
}

/// Single producer / single consumer ring. The tap never waits for a mutex.
/// Release/acquire publication protects each preallocated slot until consumed.
final class AudioBufferPool: @unchecked Sendable {
    final class Slot {
        let buffer: AVAudioPCMBuffer
        var host: UInt64 = 0
        init(buffer: AVAudioPCMBuffer) { self.buffer = buffer }
    }
    private let slots: [Slot]
    private let ring: OpaquePointer
    init(format: AVAudioFormat) {
        slots = (0..<32).map { _ in Slot(buffer: AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_384)!) }
        ring = gj_ring_create(32)!
    }
    deinit { gj_ring_destroy(ring) }
    func enqueue(_ source: AVAudioPCMBuffer, host: UInt64) -> Bool {
        let index = gj_ring_write_index(ring)
        guard index >= 0 else { return false }
        let i = Int(index)
        guard source.frameLength <= slots[i].buffer.frameCapacity,
              let from = source.floatChannelData, let to = slots[i].buffer.floatChannelData else { return false }
        slots[i].buffer.frameLength = source.frameLength; slots[i].host = host
        for channel in 0..<Int(source.format.channelCount) {
            memcpy(to[channel], from[channel], Int(source.frameLength) * MemoryLayout<Float>.size)
        }
        gj_ring_commit_write(ring)
        return true
    }
    func pop() -> (Int, AVAudioPCMBuffer, UInt64)? {
        let index = gj_ring_read_index(ring)
        guard index >= 0 else { return nil }
        let i = Int(index)
        return (i, slots[i].buffer, slots[i].host)
    }
    func release(_ index: Int) { gj_ring_consume_read(ring) }
}
