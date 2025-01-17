import SwiftUI

struct AverageProgressCell: View {
    let progress: Double
    
    // Stabilize the progress value
    private var stableProgress: Double {
        max(0, min(100, progress))
    }
    
    private var statusColor: Color {
        switch stableProgress {
        case 0:
            return Color.gray
        case 1...20:
            return Color.blue.opacity(0.3)
        case 21...80:
            return Color.blue.opacity(0.6)
        case 81...99:
            return Color.blue.opacity(0.9)
        case 100:
            return Color.green
        default:
            return Color.gray
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Rectangle()
                            .fill(statusColor)
                            .frame(width: max(0, geometry.size.width * CGFloat(stableProgress / 100.0)))
                        , alignment: .leading
                    )
            }
            .frame(width: 80, height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            
            Text(String(format: "%.0f%%", stableProgress))
                .font(.system(size: 11))
                .foregroundColor(statusColor)
                .frame(width: 40, alignment: .trailing)
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
        // Clamp progress between 0 and 100, then round to nearest 5
        let clampedProgress = max(0, min(100, progress))
        return (clampedProgress / 5.0).rounded() * 5.0
    }
    
    var body: some View {
        HStack(spacing: 4) {
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: max(0, geometry.size.width * CGFloat(stableProgress / 100.0)))
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

struct OverallProgressCell: View {
    let progress: Double
    
    // Stabilize the progress value
    private var stableProgress: Double {
        round(max(0, min(100, progress)))
    }
    
    private var statusColor: Color {
        switch Int(round(stableProgress)) {
        case 0:
            return Color.gray
        case 1...20:
            return Color.blue.opacity(0.3)
        case 21...80:
            return Color.blue.opacity(0.6)
        case 81...99:
            return Color.blue.opacity(0.9)
        case 100:
            return Color.green
        default:
            return Color.gray
        }
    }
    
    private var statusText: String {
        switch Int(round(stableProgress)) {
        case 0:
            return "Not started"
        case 1...20:
            return "Started"
        case 21...80:
            return "In progress"
        case 81...99:
            return "Finishing"
        case 100:
            return "Migration Ready"
        default:
            return "Unknown"
        }
    }
    
    var body: some View {
        Text(statusText)
            .font(.system(size: 11))
            .foregroundColor(statusColor)
            .frame(maxWidth: .infinity, alignment: .center)
    }
} 