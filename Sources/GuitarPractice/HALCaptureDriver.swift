import AVFoundation
import AudioToolbox
import CoreAudio

/// Dedicated input-only AUHAL. It never opens an output stream, so microphone
/// capture does not inherit the Bluetooth speaker's sample rate or play monitoring.
/// Follows Apple's TN2091 input capture sequence.
final class HALCaptureDriver: @unchecked Sendable {
    private var unit: AudioUnit?
    private var formatStorage: AVAudioFormat?
    private var buffer: AVAudioPCMBuffer?
    private var pool: AudioBufferPool?
    private var ready: DispatchSourceUserDataAdd?
    private var fault: DispatchSourceUserDataAdd?
    var format: AVAudioFormat { formatStorage! }

    init(device: InputDevice) throws {
        var description = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_HALOutput, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        guard let component = AudioComponentFindNext(nil, &description) else { throw Self.error("No Core Audio input component", status: -1) }
        var created: AudioUnit?
        try Self.check(AudioComponentInstanceNew(component, &created), "Create microphone unit")
        unit = created
        guard let unit = created else { throw Self.error("Create microphone unit", status: -1) }
        do {
            var enabled: UInt32 = 1, disabled: UInt32 = 0
            try Self.check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enabled, 4), "Enable input")
            try Self.check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &disabled, 4), "Disable output")
            var deviceID = device.id
            try Self.check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &deviceID, 4), "Select microphone")
            var hardware = AudioStreamBasicDescription()
            var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            try Self.check(AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &hardware, &size), "Read microphone format")
            guard hardware.mSampleRate > 0, hardware.mChannelsPerFrame > 0,
                  let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: hardware.mSampleRate, channels: hardware.mChannelsPerFrame, interleaved: false) else { throw Self.error("Unsupported microphone format", status: -1) }
            formatStorage = format
            var stream = format.streamDescription.pointee
            try Self.check(AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &stream, size), "Set capture format")
            var maximumFrames: UInt32 = 16_384
            try Self.check(AudioUnitSetProperty(unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFrames, 4), "Set capture buffer capacity")
            buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: maximumFrames)
            guard buffer != nil else { throw Self.error("Allocate microphone buffer", status: -1) }
        } catch { stop(); throw error }
    }
    deinit { stop() }
    func start(pool: AudioBufferPool, ready: DispatchSourceUserDataAdd, fault: DispatchSourceUserDataAdd) throws {
        guard let unit else { throw Self.error("Microphone unit unavailable", status: -1) }
        self.pool = pool; self.ready = ready; self.fault = fault
        var callback = AURenderCallbackStruct(inputProc: { refCon, flags, time, bus, frames, _ in
            let driver = Unmanaged<HALCaptureDriver>.fromOpaque(refCon).takeUnretainedValue()
            return driver.render(flags: flags, time: time, frames: frames)
        }, inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        try Self.check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callback, UInt32(MemoryLayout<AURenderCallbackStruct>.size)), "Install microphone callback")
        try Self.check(AudioUnitInitialize(unit), "Initialize microphone")
        try Self.check(AudioOutputUnitStart(unit), "Start microphone")
    }
    func stop() {
        guard let unit else { return }
        AudioOutputUnitStop(unit)
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
        self.unit = nil
    }
    private func render(flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, time: UnsafePointer<AudioTimeStamp>, frames: UInt32) -> OSStatus {
        guard let unit, let buffer, let pool, frames <= buffer.frameCapacity else { fault?.add(data: 1); return kAudioUnitErr_TooManyFramesToProcess }
        buffer.frameLength = frames
        let status = AudioUnitRender(unit, flags, time, 1, frames, buffer.mutableAudioBufferList)
        guard status == noErr else { fault?.add(data: 1); return status }
        let host = time.pointee.mFlags.contains(.hostTimeValid) ? time.pointee.mHostTime : mach_absolute_time()
        if pool.enqueue(buffer, host: host) { ready?.add(data: 1) } else { fault?.add(data: 1) }
        return noErr
    }
    private static func check(_ status: OSStatus, _ operation: String) throws {
        if status != noErr { throw error(operation, status: status) }
    }
    private static func error(_ operation: String, status: OSStatus) -> NSError {
        NSError(domain: "GuitarJim.CoreAudio", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "\(operation) failed (\(status)). Choose a connected microphone and retry."])
    }
}
