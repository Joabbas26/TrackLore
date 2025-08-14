//
//  SongMatchViewModel.swift
//  ShazamClone
//
//  Created by Gemini on 7/2/25.
//

import Combine
import Foundation
import AVFoundation
import ShazamKit


class SongMatchViewModel: NSObject, ObservableObject {
    @Published var matchedSong: Song? // The song found by Shazam
    @Published var isListening: Bool = false // Indicates if the app is actively listening
    @Published var recognitionStatus: String? = nil // Status messages for the user

    private var session = SHSession() // The ShazamKit session for matching
    private let audioEngine = AVAudioEngine() // Audio engine to capture microphone input
    private var signatureGenerator = SHSignatureGenerator() // Generates Shazam signatures from audio

    override init() {
        super.init()
        session.delegate = self // Set the delegate to receive match results
    }

    /// Starts the audio recognition process.
    func startRecognition() {
        matchedSong = nil // Clear any previous match
        recognitionStatus = "Checking microphone access..." // Initial status

        // Use the updated API for requesting microphone permission (iOS 17.0+)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async { // Ensure UI updates are on the main thread
                    guard let self = self else { return }

                    if granted {
                        print("✅ Microphone permission granted.")
                        self.setupAndStartAudioEngine() // Proceed if permission is granted
                    } else {
                        print("❌ Microphone permission denied.")
                        self.recognitionStatus = "❌ Microphone access denied. Please enable it in Settings."
                        self.isListening = false
                    }
                }
            }
        } else {
            // Fallback for older iOS versions
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async { // Ensure UI updates are on the main thread
                    guard let self = self else { return }

                    if granted {
                        print("✅ Microphone permission granted.")
                        self.setupAndStartAudioEngine() // Proceed if permission is granted
                    } else {
                        print("❌ Microphone permission denied.")
                        self.recognitionStatus = "❌ Microphone access denied. Please enable it in Settings."
                        self.isListening = false
                    }
                }
            }
        }
    }

    /// Sets up and starts the audio engine for recording.
    private func setupAndStartAudioEngine() {
        isListening = true
        recognitionStatus = "Preparing to listen..."

        // Configure AVAudioSession
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("❌ AVAudioSession setup error: \(error.localizedDescription)")
            recognitionStatus = "❌ Audio session setup failed."
            isListening = false
            return
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // Ensure there are input channels
        guard inputFormat.channelCount > 0 else {
            recognitionStatus = "❌ Microphone is not available or has no input channels."
            print("❌ Invalid input format: no channels detected.")
            isListening = false
            return
        }

        // Remove any existing taps to prevent multiple installations
        inputNode.removeTap(onBus: 0)
        // Re-initialize signature generator for a new recognition attempt
        signatureGenerator = SHSignatureGenerator()

        // Install a tap on the input node to capture audio buffers
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            do {
                // Append audio buffers to the signature generator
                try self.signatureGenerator.append(buffer, at: time)
                // print("🎤 Captured buffer at time: \(time.sampleTime)") // Uncomment for detailed logging
            } catch {
                print("❌ Failed to append buffer to signature generator: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    // Consider stopping recognition if append consistently fails
                    self.recognitionStatus = "⚠️ Error capturing audio. Please try again."
                    self.stopAudioEngineOnly() // Stop engine but don't deactivate session yet
                }
            }
        }

        // Start the audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            recognitionStatus = "🎧 Listening for music..."
            print("🎧 Audio engine started successfully.")

            // Stop listening after 10 seconds and attempt to match
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self = self else { return }
                self.stopAudioEngineOnly() // Stop the audio engine, but keep session active for signature generation

                Task { @MainActor [weak self] in // Use Task for async operation, ensure UI updates on main actor
                    guard let self = self else { return }
                    do {
                        let signature = try self.signatureGenerator.signature() // Generate the final signature
                        print("📝 Signature generated. Length: \(signature.dataRepresentation.count) bytes")
                        self.recognitionStatus = "🧠 Matching..."
                        self.session.match(signature) // Send signature to Shazam for matching
                    } catch {
                        print("❌ Signature generation failed: \(error.localizedDescription)")
                        self.recognitionStatus = "⚠️ Could not create audio signature."
                    }; do { // Ensure session is deactivated after match attempt (success or failure)
                        self.deactivateAudioSession()
                    }
                }
            }
        } catch {
            print("❌ AudioEngine failed to start: \(error.localizedDescription)")
            recognitionStatus = "❌ Failed to start audio engine. Check mic permissions and try again."
            self.isListening = false
            self.deactivateAudioSession() // Deactivate session if engine fails to start
        }
    }

    /// Stops only the audio engine, keeping the session active.
    private func stopAudioEngineOnly() {
        audioEngine.inputNode.removeTap(onBus: 0) // Remove the tap to stop capturing audio
        audioEngine.stop() // Stop the audio engine
        print("🛑 Audio engine stopped capturing.")
    }

    /// Deactivates the audio session.
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio session deactivated.")
        } catch {
            print("Error deactivating audio session: \(error.localizedDescription)")
        }
    }

    /// Stops the entire audio recognition process, including deactivating the session.
    func stopRecognition() {
        isListening = false
        stopAudioEngineOnly() // Stop the engine
        signatureGenerator = SHSignatureGenerator() // Reset signature generator
        deactivateAudioSession() // Deactivate the session
        print("🛑 Full recognition process stopped.")
    }


    /// Fetches media info using Gemini API for a given song title and artist.
    func fetchMediaInfoFromGemini(title: String, artist: String) async -> (sourceTitle: String?, sourceType: String?) {
        let prompt = """
        Based on the song "\(title)" by "\(artist)", tell me if it is used as a theme song in any movie, TV show, or anime.
        Respond ONLY in this JSON format:
        {
            "sourceTitle": "Friends",
            "sourceType": "TV Show"
        }
        If there is no known usage, respond with:
        {
            "sourceTitle": null,
            "sourceType": null
        }
        """

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=\(Secrets.geminiApiKey)") else {
            print("❌ Gemini API URL construction failed")
            return (nil, nil)
        }

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("❌ Gemini API: Failed to encode JSON body")
            return (nil, nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("Gemini API HTTP Error: \(httpResponse.statusCode)")
                return (nil, nil)
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String,
               let resultData = text.data(using: .utf8),
               let parsedResult = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] {
                
                let sourceTitle = parsedResult["sourceTitle"] as? String
                let sourceType = parsedResult["sourceType"] as? String
                print("🔮 Gemini API parsed result: sourceTitle=\(sourceTitle ?? "nil"), sourceType=\(sourceType ?? "nil")")
                return (sourceTitle, sourceType)
            }

            print("Gemini API: Unexpected response format")
        } catch {
            print("Gemini API error: \(error.localizedDescription)")
        }

        return (nil, nil)
    }
}

// MARK: - SHSessionDelegate Extension

extension SongMatchViewModel: SHSessionDelegate {
    /// Called when ShazamKit finds a match.
    func session(_ session: SHSession, didFind match: SHMatch) {
        if let item = match.mediaItems.first {
            Task { @MainActor [weak self] in // Ensure UI updates on the main actor
                guard let self = self else { return }
                let rawTitle = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                print("🔍 Shazam matched title: \(rawTitle)")

                let artist = item.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                print("🎯 Querying Gemini API for media info with: \(rawTitle) / \(artist)")
                let (sourceTitle, sourceType) = await self.fetchMediaInfoFromGemini(title: rawTitle, artist: artist)

                let sourceDescription: String
                if let sourceTitle = sourceTitle, let sourceType = sourceType {
                    sourceDescription = "\(sourceTitle) (\(sourceType))"
                } else {
                    sourceDescription = "Shazam"
                }

                let song = Song(
                    title: item.title ?? "Unknown Title",
                    artist: item.artist ?? "Unknown Artist",
                    artworkURL: item.artworkURL,
                    appleMusicURL: item.appleMusicURL,
                    source: sourceDescription,
                    animeInfo: sourceDescription
                )

                self.isListening = false
                self.matchedSong = song
                self.recognitionStatus = nil // Clear status on successful match
                SongHistoryManager.shared.save(song) // Save the matched song
                print("✅ Match found: \(song.title) by \(song.artist)")
                self.deactivateAudioSession() // Deactivate session after successful match
            }
        }
    }

    /// Called when ShazamKit does not find a match or an error occurs.
    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        print("❌ No match found for signature.")
        if let error = error as? SHError {
            // Handle specific ShazamKit errors
            switch error.code {
            case .internalError:
                print("ShazamKit Error: Internal error.")
                recognitionStatus = "⚠️ Shazam internal error. Please try again."
            case .signatureInvalid:
                print("ShazamKit Error: Signature invalid.")
                recognitionStatus = "⚠️ Invalid audio signature. Try again."
            default:
                // This is the modified section to help diagnose unknown errors
                print("ShazamKit Error: Unknown error code (\(error.code.rawValue)).")
                recognitionStatus = "⚠️ An unknown error occurred. Error Code: \(error.code.rawValue). Try again."
            }
        } else if let error = error {
            print("ShazamKit Generic Error: \(error.localizedDescription)")
            recognitionStatus = "⚠️ An error occurred: \(error.localizedDescription)"
        } else {
            recognitionStatus = "⚠️ No match found. Try again."
        }
        DispatchQueue.main.async {
            self.isListening = false
            self.deactivateAudioSession() // Deactivate session after match attempt (failure)
        }
    }
}
