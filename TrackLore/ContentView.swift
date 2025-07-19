//  ContentView.swift
import SwiftUI
import ShazamKit
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = SongMatchViewModel()
    @State private var showHistory = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 80)

                Text("TrackLore")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(radius: 10)

                if viewModel.isListening {
                    MicPulseView()
                        .frame(width: 200, height: 200)
                        .padding(.bottom, 10)

                    ProgressView("Listening...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                } else {
                    Button(action: {
                        viewModel.startRecognition()
                    }) {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 200, height: 200)
                            .overlay(
                                Image(systemName: "mic.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.white)
                            )
                            .shadow(radius: 10)
                    }

                    Text("Tap to Identify Music")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.headline)
                }

                if let status = viewModel.recognitionStatus {
                    Text(status)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.top, 5)
                }

                if viewModel.isListening {
                    GlassButton(title: "Stop Listening") {
                        viewModel.stopRecognition()
                    }
                }

                if let song = viewModel.matchedSong {
                    GlassCard {
                        VStack(spacing: 10) {
                            if let url = song.artworkURL {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 15))
                                        .shadow(radius: 10)
                                } placeholder: {
                                    ProgressView()
                                }
                            }

                            Text(song.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Text(song.artist)
                                .font(.subheadline)
                                .foregroundColor(.gray)

                            Text("From: \(song.source)")
                                .font(.caption)
                                .foregroundColor(.yellow)

                            if let animeInfo = song.animeInfo {
                                Text(animeInfo)
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }

                            HStack(spacing: 20) {
                                if let url = song.appleMusicURL {
                                    Link(destination: url) {
                                        Label("Apple Music", systemImage: "music.note")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                }

                                let spotifyQuery = song.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? song.title
                                if let spotifyURL = URL(string: "https://open.spotify.com/search/\(spotifyQuery)") {
                                    Link(destination: spotifyURL) {
                                        Label("Spotify", systemImage: "play.circle")
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                    }
                                }

                                if let animeTitle = song.animeInfo?.replacingOccurrences(of: "Anime Opening: ", with: "") {
                                    let googleQuery = animeTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? animeTitle
                                    if let watchURL = URL(string: "https://www.google.com/search?q=watch+\(googleQuery)") {
                                        Link(destination: watchURL) {
                                            Label("Watch", systemImage: "tv")
                                                .font(.subheadline)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 5)
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: 320)
                    .padding(.horizontal)
                }

                Button(action: {
                    showHistory = true
                }) {
                    Text("View History")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .underline()
                }
                .padding(.top)

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showHistory) {
            NavigationView {
                LibraryView()
                    .navigationTitle("History")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showHistory = false
                            }
                        }
                    }
            }
        }
    }
}
