//
//  SongHistoryManager.swift
//  TrackLore
//
//  Created by Joab Bastidas on 7/14/25.
//


import Foundation

class SongHistoryManager {
    static let shared = SongHistoryManager()
    private let key = "songHistory"

    func save(_ song: Song) {
        var history = load()
        history.insert(song, at: 0) // newest first
        if history.count > 20 {
            history = Array(history.prefix(20))
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() -> [Song] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let history = try? JSONDecoder().decode([Song].self, from: data) else {
            return []
        }
        return history
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
