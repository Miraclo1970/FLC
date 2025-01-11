import SwiftUI

struct ValidClusterRecordsView: View {
    let records: [ClusterData]
    let searchText: String
    
    var filteredRecords: [ClusterData] {
        if searchText.isEmpty {
            return records
        }
        return records.filter { record in
            record.department.localizedCaseInsensitiveContains(searchText) ||
            (record.departmentSimple ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.domain ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.migrationCluster ?? "").localizedCaseInsensitiveContains(searchText) ||
            (record.migrationClusterReadiness ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("Department")
                    .frame(width: 200, alignment: .leading)
                Text("Department Simple")
                    .frame(width: 200, alignment: .leading)
                Text("Domain")
                    .frame(width: 150, alignment: .leading)
                Text("Migration Cluster")
                    .frame(width: 200, alignment: .leading)
                Text("Migration Cluster Readiness")
                    .frame(width: 200, alignment: .leading)
            }
            .padding(.vertical, 4)
            .font(.system(size: 11, weight: .bold))
            .background(Color(NSColor.controlBackgroundColor))
            
            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredRecords) { record in
                        HStack(spacing: 0) {
                            Text(record.department)
                                .frame(width: 200, alignment: .leading)
                            Text(record.departmentSimple ?? "")
                                .frame(width: 200, alignment: .leading)
                            Text(record.domain ?? "")
                                .frame(width: 150, alignment: .leading)
                            Text(record.migrationCluster ?? "")
                                .frame(width: 200, alignment: .leading)
                            Text(record.migrationClusterReadiness ?? "")
                                .frame(width: 200, alignment: .leading)
                        }
                        .frame(height: 18)
                        .font(.system(size: 11))
                        .background(filteredRecords.firstIndex(where: { $0.id == record.id })!.isMultiple(of: 2) ? Color(NSColor.controlBackgroundColor) : Color.clear)
                    }
                }
            }
        }
    }
} 