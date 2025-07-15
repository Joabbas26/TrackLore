//
//  GlassButton.swift
//  TrackLore
//
//  Created by Joab Bastidas on 7/15/25.
//


import SwiftUI

struct GlassButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(radius: 10)
        }
        .padding(.horizontal)
    }
}