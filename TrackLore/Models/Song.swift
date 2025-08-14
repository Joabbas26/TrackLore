//
//  Song.swift
//  TrackLore
//
//  Created by Joab Bastidas on 7/13/25.
//

import Foundation

struct Song: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let artist: String
    let artworkURL: URL?
    let appleMusicURL: URL?
    let sourceTitle: String?
    let sourceType: String?

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        artworkURL: URL?,
        appleMusicURL: URL?,
        sourceTitle: String? = nil,
        sourceType: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.appleMusicURL = appleMusicURL
        self.sourceTitle = sourceTitle
        self.sourceType = sourceType
    }
}
