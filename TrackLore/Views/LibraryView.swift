//
//  LibraryView.swift
//  TrackLore
//
//  Created by Joab Bastidas on 7/13/25.

import SwiftUI

struct LibraryView: View {
    @State private var librarySongs: [Song] = []

    var body: some View {
        List(librarySongs) { song in
            HStack(alignment: .top, spacing: 12) {
                if let url = song.artworkURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 50, height: 50)
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

                    Text("From: \(song.source)")
                        .font(.caption)
                        .foregroundColor(.yellow)

                    if let animeInfo = song.animeInfo {
                        Text(animeInfo)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .contextMenu {
                if let url = song.appleMusicURL {
                    Button("Open in Apple Music") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .navigationTitle("Library")
        .onAppear {
            librarySongs = SongHistoryManager.shared.load()
        }
    }
}
