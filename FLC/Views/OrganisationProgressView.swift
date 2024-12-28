import SwiftUI

struct OrganisationProgressView: View {
    @State private var stats: [DivisionStats] = []
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading statistics...")
            } else if let error = error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else {
                // Overall Progress Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Organisation Progress")
                        .font(.title)
                        .padding(.bottom, 8)
                    
                    // Application Readiness (Weighted Average)
                    let applicationReadiness = calculateWeightedApplicationReadiness()
                    ProgressBar(
                        title: "Application Readiness",
                        value: applicationReadiness,
                        color: .blue
                    )
                    
                    // Total Applications
                    let totalUniqueApps = calculateTotalUniqueApplications()
                    Text("Total Unique Applications: \(totalUniqueApps)")
                        .font(.headline)
                }
                .padding()
                .background(Color(.windowBackgroundColor))
                .cornerRadius(10)
                
                // Division List
                List(stats) { division in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(division.name)
                            .font(.headline)
                        
                        // Division's Application Readiness
                        ProgressBar(
                            title: "Application Readiness",
                            value: division.applicationReadiness,
                            color: .blue
                        )
                        
                        Text("Applications: \(division.applications)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        Task {
            do {
                let divisionStats = try await DatabaseManager.shared.getDivisionStats()
                await MainActor.run {
                    self.stats = divisionStats
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func calculateWeightedApplicationReadiness() -> Double {
        guard !stats.isEmpty else { return 0.0 }
        
        var totalWeightedReadiness = 0.0
        var totalApplications = 0
        
        for division in stats {
            let weight = Double(division.applications)
            totalWeightedReadiness += division.applicationReadiness * weight
            totalApplications += division.applications
        }
        
        return totalApplications > 0 ? totalWeightedReadiness / Double(totalApplications) : 0.0
    }
    
    private func calculateTotalUniqueApplications() -> Int {
        stats.reduce(0) { $0 + $1.applications }
    }
}

struct ProgressBar: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value * 100))%")
            }
            .font(.subheadline)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .foregroundColor(Color(.systemGray5))
                        .frame(width: geometry.size.width, height: 8)
                    
                    Rectangle()
                        .foregroundColor(color)
                        .frame(width: geometry.size.width * CGFloat(value), height: 8)
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    OrganisationProgressView()
} 