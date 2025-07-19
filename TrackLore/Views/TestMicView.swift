//
//  TestMicView.swift
//  TrackLore
//
//  Created by Joab Bastidas on 7/17/25.
//


import SwiftUI
import AVFoundation
import ShazamKit

struct TestMicView: View {
    @State private var micLevel: Float = 0.0
    @State private var isRecording = false
    @State private var logs: [String] = []

    private let audioEngine = AVAudioEngine()
    private let signatureGenerator = SHSignatureGenerator()

    var body: some View {
        VStack(spacing: 20) {
            Text("🎤 Microphone Test")
                .font(.title)
                .bold()

            ProgressView(value: micLevel)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(width: 200)

            Button(isRecording ? "Stop Test" : "Start Test") {
                isRecording ? stopRecording() : startRecording()
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .foregroundColor(.white)

            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(logs, id: \.self) { log in
                        Text("• \(log)").font(.caption).foregroundColor(.white)
                    }
                }
            }
            .frame(height: 200)
            .padding()
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom))
        .foregroundColor(.white)
    }

    func startRecording() {
        logs = []
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)

            let inputNode = audioEngine.inputNode
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1)!

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
                guard let channelData = buffer.floatChannelData?.pointee else { return }
                let frameLength = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<frameLength {
                    sum += channelData[i] * channelData[i]
                }
                let avgPower = 10 * log10(sum / Float(frameLength) + 1e-7)
                DispatchQueue.main.async {
                    self.micLevel = max(0, (avgPower + 60) / 60)
                }

                do {
                    try self.signatureGenerator.append(buffer, at: time)
                    appendLog("✔️ Appended buffer successfully")
                } catch {
                    appendLog("❌ Buffer append error: \(error.localizedDescription)")
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            appendLog("🎧 AudioEngine started")
        } catch {
            appendLog("❌ Audio setup failed: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
        appendLog("🛑 Recording stopped")
    }

    func appendLog(_ message: String) {
        DispatchQueue.main.async {
            self.logs.insert(message, at: 0)
        }
    }
}

struct TestMicView_Previews: PreviewProvider {
    static var previews: some View {
        TestMicView()
    }
}
