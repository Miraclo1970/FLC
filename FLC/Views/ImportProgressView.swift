import SwiftUI

@available(macOS 14.0, *)
struct ImportProgressView: View {
    let progress: Double
    let currentOperation: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .foregroundColor(Color(.windowBackgroundColor))
                        .frame(width: geometry.size.width, height: 8)
                    
                    Rectangle()
                        .foregroundColor(.blue)
                        .frame(width: max(0, geometry.size.width * CGFloat(progress)), height: 8)
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
            .padding(.horizontal)
            
            // Progress percentage
            Text("\(Int(progress * 100))%")
                .font(.headline)
            
            // Current operation
            Text(currentOperation)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 300)
    }
} 