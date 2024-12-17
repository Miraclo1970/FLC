import SwiftUI

@available(macOS 14.0, *)
struct DatabaseMigrationRecordsView: View {
    let records: [MigrationStatusData]
    private let rowHeight: CGFloat = 18
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("ID")
                            .frame(width: 80, alignment: .leading)
                            .padding(.leading, 16)
                            .font(.system(size: 11))
                        Text("AD Group")
                            .frame(width: 150, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Application")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("New Application")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Suite")
                            .frame(width: 150, alignment: .leading)
                            .font(.system(size: 11))
                        Text("New Suite")
                            .frame(width: 150, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Scope Division")
                            .frame(width: 150, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Department Simple")
                            .frame(width: 150, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Migration Cluster")
                            .frame(width: 150, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Migration Readiness")
                            .frame(width: 150, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Import Date")
                            .frame(width: 200, alignment: .leading)
                            .font(.system(size: 11))
                        Text("Import Set")
                            .frame(width: 150, alignment: .leading)
                            .font(.system(size: 11))
                    }
                    .padding(.vertical, 4)
                    .background(Color(NSColor.windowBackgroundColor))
                    .border(Color.gray.opacity(0.2), width: 1)
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(records, id: \.id) { record in
                                HStack(spacing: 0) {
                                    Text(String(format: "%.0f", Double(record.id ?? -1)))
                                        .frame(width: 80, alignment: .leading)
                                        .padding(.leading, 16)
                                        .font(.system(size: 11))
                                    Text(record.adGroup)
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.applicationName)
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.applicationNameNew ?? "")
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.suite ?? "")
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.suiteNew ?? "")
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.scopeDivision ?? "")
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.departmentSimple ?? "")
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.migrationCluster ?? "")
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.migrationReadiness ?? "")
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(dateFormatter.string(from: record.importDate))
                                        .frame(width: 200, alignment: .leading)
                                        .font(.system(size: 11))
                                    Text(record.importSet)
                                        .frame(width: 150, alignment: .leading)
                                        .font(.system(size: 11))
                                }
                                .frame(height: rowHeight)
                                .padding(.vertical, 0)
                                .background(Color(NSColor.controlBackgroundColor))
                            }
                        }
                    }
                }
            }
        }
    }
} 