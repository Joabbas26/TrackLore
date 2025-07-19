//
//  LibraryView.swift
//  TrackLore
//
//  Created by Joab Bastidas on 7/13/25.

import SwiftUI

struct LibraryView: View {
    @State private var librarySongs: [Song] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent Matches")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                Button("Clear") {
                    SongHistoryManager.shared.clear()
                    librarySongs = []
                }
                .foregroundColor(.red)
            }
            .padding()

            if librarySongs.isEmpty {
                Spacer()
                Text("No history yet")
                    .foregroundColor(.gray)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(librarySongs) { song in
                            HStack(spacing: 12) {
                                if let url = song.artworkURL {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Image(systemName: "music.note")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.gray)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(song.title)
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text(song.artist)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)

                                    if let animeInfo = song.animeInfo {
                                        Text(animeInfo)
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }

                                Spacer()

                                if let url = song.appleMusicURL {
                                    Link(destination: url) {
                                        Image(systemName: "link")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .onAppear {
            librarySongs = SongHistoryManager.shared.load()
        }
    }
}
