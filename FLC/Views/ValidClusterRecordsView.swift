import SwiftUI

struct ValidClusterRecordsView: View {
    let records: [ClusterData]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(records) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Department: \(record.department)")
                        .font(.headline)
                    
                    if let simple = record.departmentSimple, !simple.isEmpty {
                        Text("Department Simple: \(simple)")
                            .font(.subheadline)
                    }
                    
                    if let domain = record.domain, !domain.isEmpty {
                        Text("Domain: \(domain)")
                            .font(.subheadline)
                    }
                    
                    if let cluster = record.migrationCluster, !cluster.isEmpty {
                        Text("Migration Cluster: \(cluster)")
                            .font(.subheadline)
                    }
                    
                    if let readiness = record.migrationClusterReadiness, !readiness.isEmpty {
                        Text("Migration Cluster Readiness: \(readiness)")
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Valid Records")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ValidClusterRecordsView(records: [
        ClusterData(
            department: "Test Department",
            departmentSimple: "Test Simple",
            domain: "Test Domain",
            migrationCluster: "Test Cluster",
            migrationClusterReadiness: "planned"
        )
    ])
} 