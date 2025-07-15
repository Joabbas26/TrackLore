//
//  SongMatchViewModel.swift
//  TrackLore
//
//  Created by Joab Bastidas on 7/2/25.
//

import Combine
import Foundation
import AVFoundation
import ShazamKit

class SongMatchViewModel: NSObject, ObservableObject {
    @Published var matchedSong: Song?
    @Published var isListening: Bool = false

    private var session = SHSession()
    private let audioEngine = AVAudioEngine()
    private var signatureGenerator = SHSignatureGenerator()

    override init() {
        super.init()
        session.delegate = self
    }

    func startRecognition() {
        matchedSong = nil
        isListening = true

        let inputNode = audioEngine.inputNode
        let micFormat = inputNode.outputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1)!

        let converter = AVAudioConverter(from: micFormat, to: targetFormat)!

        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: micFormat) { buffer, when in
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: 1024) else { return }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

            if let error = error {
                print("\u{274c} Conversion failed: \(error.localizedDescription)")
            } else {
                do {
                    try self.signatureGenerator.append(convertedBuffer, at: when)
                } catch {
                    print("\u{274c} Append failed: \(error.localizedDescription)")
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()

            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [self] in
                stopRecognition()
                Task { [self] in
                    do {
                        let signature = try self.signatureGenerator.signature()
                        self.session.match(signature)
                    } catch {
                        print("\u{274c} Signature error: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("\u{274c} AudioEngine error: \(error.localizedDescription)")
            isListening = false
        }
    }

    func stopRecognition() {
        isListening = false
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        signatureGenerator = SHSignatureGenerator()
    }

    func fetchAnimeTheme(for title: String) async -> String? {
        let query = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let urlString = "https://api.jikan.moe/v4/anime?q=\(query)&sfw=true"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(JikanAnimeSearchResponse.self, from: data)

            for anime in decoded.data {
                if let openings = anime.theme.openings {
                    for opening in openings {
                        if opening.lowercased().contains(title.lowercased()) {
                            return "Anime Opening: \(anime.title)"
                        }
                    }
                }
            }
        } catch {
            print("Jikan API error: \(error)")
        }

        return nil
    }
}

extension SongMatchViewModel: SHSessionDelegate {
    func session(_ session: SHSession, didFind match: SHMatch) {
        if let item = match.mediaItems.first {
            Task {
                let animeMatch = await self.fetchAnimeTheme(for: item.title ?? "")

                let song = Song(
                    title: item.title ?? "Unknown Title",
                    artist: item.artist ?? "Unknown Artist",
                    artworkURL: item.artworkURL,
                    appleMusicURL: item.appleMusicURL,
                    source: "Shazam",
                    animeInfo: animeMatch
                )

                DispatchQueue.main.async {
                    self.matchedSong = song
                    SongHistoryManager.shared.save(song)
                }
            }
        }
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        print("No match found")
    }
}

// MARK: - Jikan API Decoding
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
