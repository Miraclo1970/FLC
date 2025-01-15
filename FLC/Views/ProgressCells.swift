import SwiftUI

struct AverageProgressCell: View {
    let progress: Double
    var color: Color = .blue
    
    // Stabilize the progress value
    private var stableProgress: Double {
        max(0, min(100, progress))
    }
    
    var body: some View {
        HStack(spacing: 4) {
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Rectangle()
                            .fill(color)
                            .frame(width: max(0, geometry.size.width * CGFloat(stableProgress / 100.0)))
                        , alignment: .leading
                    )
            }
            .frame(width: 80, height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            
            Text(String(format: "%.1f%%", stableProgress))
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 8)
    }
}

struct DepartmentProgressCell: View {
    let status: String
    let isTestStatus: Bool
    
    private var progress: Double {
        if isTestStatus {
            switch status.lowercased() {
            case "pat ok":
                return 100.0
            case "pat on hold":
                return 75.0
            case "gat ok":
                return 50.0
            case "pat planned":
                return 60.0
            case "in progress":
                return 30.0
            case "", "not started":
                return 0.0
            default:
                print("Unknown test status: \(status)")
                return 0.0
            }
        } else {
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
    }
    
    private var progressColor: Color {
        if isTestStatus {
            switch status.lowercased() {
            case "pat ok":
                return .green
            case "pat on hold":
                return .red
            case "pat planned":
                return .green.opacity(0.6)  // Light green
            case "gat ok":
                return .blue  // Middle blue
            case "in progress":
                return .blue.opacity(0.6)  // Light blue
            default:
                return .gray
            }
        }
        return .blue
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
                            .fill(progressColor)
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
        max(0, min(100, progress))
    }
    
    private var statusColor: Color {
        switch stableProgress {
        case 0:
            return Color.gray
        case 1...20:
            return Color.blue.opacity(0.3)  // Started
        case 21...80:
            return Color.blue.opacity(0.6)  // In Progress
        case 81...99:
            return Color.blue.opacity(0.9)  // Finishing
        case 100:
            return Color.green  // Migration Ready
        default:
            return Color.blue.opacity(0.3)  // Fallback to Started color
        }
    }
    
    private var statusText: String {
        switch stableProgress {
        case 0:
            return "Not Started"
        case 1...20:
            return "Started"
        case 21...80:
            return "In Progress"
        case 81...99:
            return "Finishing"
        case 100:
            return "Migration Ready"
        default:
            return "In Progress"  // Fallback for any unexpected values
        }
    }
    
    var body: some View {
        Text(statusText)
            .font(.system(size: 11))
            .foregroundColor(statusColor)
            .frame(maxWidth: .infinity, alignment: .center)
    }
} 