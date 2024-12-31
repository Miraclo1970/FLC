import SwiftUI

struct AverageProgressCell: View {
    let progress: Double
    
    // Stabilize the progress value
    private var stableProgress: Double {
        // Round to nearest 5 to prevent small fluctuations
        (progress / 5.0).rounded() * 5.0
    }
    
    var body: some View {
        HStack(spacing: 4) {
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(stableProgress / 100.0))
                        , alignment: .leading
                    )
            }
            .frame(width: 80, height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            
            Text(String(format: "%.0f%%", stableProgress))
                .font(.system(size: 11))
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 8)
    }
}

struct DepartmentProgressCell: View {
    let status: String
    
    private var progress: Double {
        let lowercasedStatus = status.lowercased()
        
        // Package status specific
        if lowercasedStatus == "ready for testing" {
            return 100.0
        }
        
        // Common statuses
        switch lowercasedStatus {
        case "ready", "completed", "passed":
            return 100.0
        case "in progress":
            return 50.0
        case "not started", "":
            return 0.0
        default:
            print("Unknown status: \(status)")
            return 0.0
        }
    }
    
    // Stabilize the progress value
    private var stableProgress: Double {
        // Round to nearest 5 to prevent small fluctuations
        (progress / 5.0).rounded() * 5.0
    }
    
    var body: some View {
        HStack(spacing: 4) {
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(stableProgress / 100.0))
                        , alignment: .leading
                    )
            }
            .frame(width: 80, height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            
            Text(String(format: "%.0f%%", stableProgress))
                .font(.system(size: 11))
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 8)
    }
} 