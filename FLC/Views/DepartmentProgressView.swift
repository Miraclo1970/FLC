import SwiftUI

struct DepartmentProgressView: View {
    @State private var stats: [DepartmentStats] = []
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
                    Text("Department Progress")
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
                
                // Department List
                List(stats) { department in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(department.name)
                            .font(.headline)
                        
                        // Department's Application Readiness
                        ProgressBar(
                            title: "Application Readiness",
                            value: department.applicationReadiness,
                            color: .blue
                        )
                        
                        Text("Applications: \(department.applications)")
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
                let departmentStats = try await DatabaseManager.shared.getDepartmentStats()
                await MainActor.run {
                    self.stats = departmentStats
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
        
        for department in stats {
            let weight = Double(department.applications)
            totalWeightedReadiness += department.applicationReadiness * weight
            totalApplications += department.applications
        }
        
        return totalApplications > 0 ? totalWeightedReadiness / Double(totalApplications) : 0.0
    }
    
    private func calculateTotalUniqueApplications() -> Int {
        stats.reduce(0) { $0 + $1.applications }
    }
}

#Preview {
    DepartmentProgressView()
} 