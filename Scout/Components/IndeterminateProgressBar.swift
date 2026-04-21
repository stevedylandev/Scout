//
//  IndeterminateProgressBar.swift
//  Scout
//

import SwiftUI

struct IndeterminateProgressBar: View {
    let color: Color

    @State private var animationOffset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(color)
                .frame(width: geometry.size.width * 0.3)
                .offset(x: animationOffset * geometry.size.width)
        }
        .frame(height: 3)
        .clipped()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                animationOffset = 1.0
            }
        }
    }
}

#Preview {
    IndeterminateProgressBar(color: .blue)
}
