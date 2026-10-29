import SwiftUI

struct AudioSetupView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            Text("Audio setup").font(Theme.title(27))
            Toggle("Metronome and countdown sound", isOn: $model.metronomeEnabled).font(Theme.strong(12))
            HStack {
                Text("Volume").font(Theme.body(12))
                Slider(value: $model.metronomeVolume, in: 0...1).accessibilityLabel("Metronome volume")
                Text("\(Int(model.metronomeVolume * 100))%").font(Theme.strong(12)).monospacedDigit().frame(width: 40)
            }
            HStack {
                Button("Test countdown sound") { model.testCountdownSound() }.disabled(model.transport == .playing || model.transport == .counting || model.metronomeVolume <= 0)
                Spacer()
                if model.outputLatencyMS > 0 { Text("Output delay ~\(model.outputLatencyMS) ms").font(Theme.body(10)).foregroundStyle(Theme.muted) }
            }
            Text("Clicks play through the current macOS sound output. Use headphones while scoring so the microphone does not pick up the click.").font(Theme.body(12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            Divider()
            Picker("Input", selection: $model.selectedDeviceID) {
                ForEach(model.devices) { device in Text(device.name).tag(device.id) }
            }.disabled(model.isRecording).onChange(of: model.selectedDeviceID) { _, _ in model.deviceChanged() }
            Button("Refresh inputs") { model.devices = InputDevice.all() }.disabled(model.isRecording)
            if model.isRecording {
                LevelMeter(level: model.level, clipped: model.clipped).frame(height: 15)
                Text(model.signalLabel)
                    .font(Theme.body(12)).foregroundStyle(Theme.muted)
                Text("\(Int(model.inputSampleRate)) Hz · \(model.inputChannels) channels · monitoring off").font(Theme.body(11)).foregroundStyle(Theme.muted)
            }
            Divider()
            Text("Timing offset").font(Theme.strong())
            Text("Feedback uses audio timestamps. Until you measure this route, timing is labelled as an uncalibrated estimate. Positive offset means input arrives late. Countdown visuals account for the output device’s reported delay.")
                .font(Theme.body(12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            HStack {
                Slider(value: $model.calibrationMS, in: -500...500, step: 5).accessibilityLabel("Input offset in milliseconds")
                Text("\(Int(model.calibrationMS)) ms").font(Theme.strong(12)).monospacedDigit().frame(width: 64)
            }.disabled(model.isRecording)
            Toggle("I have measured this device route", isOn: $model.calibrationConfirmed)
                .font(Theme.body(12)).disabled(model.isRecording)
                .onChange(of: model.calibrationConfirmed) { _, _ in model.saveCalibration() }
            Text("Local chord estimates are a beta feature. Quiet, clipped or ambiguous strums receive no chord verdict. Tune the guitar and confirm your capo before playing.")
                .font(Theme.body(12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
          }
        }.frame(height: 520).foregroundStyle(Theme.ink).tint(Theme.accent)
    }
}
