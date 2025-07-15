//
//  MicPulseView.swift
//  TrackLore
//
//  Created by Joab Bastidas on 7/15/25.
//


import SwiftUI

struct MicPulseView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.1))
                .scaleEffect(pulse ? 1.2 : 1)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)

            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)

            Image(systemName: "waveform.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .foregroundColor(.white)
        }
        .onAppear { pulse = true }
        .onDisappear { pulse = false }
    }
}