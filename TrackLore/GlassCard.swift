//
//  GlassCard.swift
//  TrackLore
//
//  Created by Joab Bastidas on 7/15/25.
//


import SwiftUI

struct GlassCard<Content: View>: View {
    let content: () -> Content

    var body: some View {
        RoundedRectangle(cornerRadius: 25, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                content()
                    .padding()
            )
            .shadow(radius: 10)
    }
}