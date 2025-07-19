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
                        self.recognitionStatus = "🧠 Matching with Shazam..."
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


    /// Fetches anime or media source information for a given title.
    func fetchAnimeOrMediaSource(for title: String) async -> String? {
        if let mediaMatch = await fetchMovieOrTVTheme(for: title) {
            return mediaMatch
        } else if let animeMatch = await fetchAnimeTheme(for: title) {
            return animeMatch
        } else {
            return nil
        }
    }

    /// Fetches anime theme information from Jikan API.
    private func fetchAnimeTheme(for title: String, artist: String = "") async -> String? {
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let urlString = "https://api.jikan.moe/v4/anime?q=\(query)&sfw=true"
        guard let url = URL(string: urlString) else { return nil }
        print("🔍 Searching Jikan with query: \(urlString)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("Jikan API HTTP Error: \(httpResponse.statusCode)")
                return nil
            }
            let decoded = try JSONDecoder().decode(JikanAnimeSearchResponse.self, from: data)

            for anime in decoded.data {
                if let openings = anime.theme.openings {
                    print("📺 Found anime title: \(anime.title)")
                    if openings.isEmpty {
                        print("⚠️ No openings found for this anime.")
                    }
                    print("🎵 Openings: \(openings)")
                    for opening in openings {
                        print("🔎 Checking opening: \(opening)")
                        if opening.lowercased().contains(title.lowercased()) ||
                           opening.lowercased().contains(artist.lowercased()) {
                            return "Anime Opening: \(anime.title)"
                        }
                    }
                }
            }
        } catch {
            print("Jikan API error: \(error.localizedDescription)")
        }
        return nil
    }

    /// Fetches movie or TV theme information from TMDb API.
    private func fetchMovieOrTVTheme(for title: String) async -> String? {
        let query = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let apiKey = Secrets.tmdbApiKey
        let urlString = "https://api.themoviedb.org/3/search/multi?api_key=\(apiKey)&query=\(query)"
        guard let url = URL(string: urlString) else { return nil }
        print("🔍 Searching TMDB with query: \(urlString)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("TMDB API HTTP Error: \(httpResponse.statusCode)")
                return nil
            }
            let result = try JSONDecoder().decode(TMDbSearchResponse.self, from: data)
            print("🧾 TMDB returned \(result.results.count) result(s).")

            if let match = result.results.first {
                if let name = match.name ?? match.title {
                    print("✅ TMDB match: \(name) - \(match.media_type)")
                    return "\(match.media_type.capitalized): \(name)"
                } else {
                    print("⚠️ TMDB match found, but no name/title.")
                }
            }
        } catch {
            print("TMDB API error: \(error.localizedDescription)")
        }
        return nil
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
                let query = "\(rawTitle) \(artist)"
                print("🎯 Querying for media source with: \(query)")
                let sourceInfo = await self.fetchAnimeOrMediaSource(for: query)

                let song = Song(
                    title: item.title ?? "Unknown Title",
                    artist: item.artist ?? "Unknown Artist",
                    artworkURL: item.artworkURL,
                    appleMusicURL: item.appleMusicURL,
                    source: sourceInfo ?? "Shazam",
                    animeInfo: sourceInfo
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

// MARK: - Jikan API Decoding (As provided by you)
struct JikanAnimeSearchResponse: Codable {
    let data: [JikanAnime]
}

struct JikanAnime: Codable {
    let title: String
    let theme: JikanTheme
}

struct JikanTheme: Codable {
    let openings: [String]?
    let endings: [String]?
}

// MARK: - TMDB API Decoding (As provided by you)
struct TMDbSearchResponse: Codable {
    let results: [TMDbMedia]
}

struct TMDbMedia: Codable {
    let title: String?
    let name: String?
    let media_type: String // "movie", "tv"
}
