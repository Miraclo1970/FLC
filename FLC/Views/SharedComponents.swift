import SwiftUI
import UniformTypeIdentifiers

struct DashboardCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.blue)
            Text(value)
                .font(.title)
                .bold()
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

enum ExportType {
    case pastLeaveDate
    case missingHR
    case withoutName
    case withoutStatus
    case fewUsers
    case oneUser
}

struct PieSlice: Shape {
    let startAngle: Double
    let endAngle: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center,
                   radius: radius,
                   startAngle: .degrees(startAngle - 90),
                   endAngle: .degrees(endAngle - 90),
                   clockwise: false)
        path.closeSubpath()
        return path
    }
}

// Document for accounts export
struct AccountsCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var accounts: Set<String>
    var timestamp: Date
    var type: ExportType
    var adImportDate: Date?
    var hrImportDate: Date?
    
    init(accounts: Set<String>, timestamp: Date, type: ExportType, adImportDate: Date? = nil, hrImportDate: Date? = nil) {
        self.accounts = accounts
        self.timestamp = timestamp
        self.type = type
        self.adImportDate = adImportDate
        self.hrImportDate = hrImportDate
    }
    
    init(configuration: ReadConfiguration) throws {
        accounts = []
        timestamp = Date()
        type = .pastLeaveDate
        adImportDate = nil
        hrImportDate = nil
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        let title = type == .pastLeaveDate ? "Past Leave Date Accounts" : "Accounts Missing HR Data"
        var csvString = """
            \(title)
            Baseline check: \(dateFormatter.string(from: timestamp))
            """
        
        if let adDate = adImportDate {
            csvString += "\nLast AD import: \(dateFormatter.string(from: adDate))"
        }
        
        if let hrDate = hrImportDate {
            csvString += "\nLast HR import: \(dateFormatter.string(from: hrDate))"
        }
        
        csvString += "\n\nSystem Account\n"
        csvString += accounts.sorted().joined(separator: "\n")
        
        let data = csvString.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

// Document for applications export
struct ApplicationsCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var applications: Set<String>
    var timestamp: Date
    var exportType: ExportType
    var adImportDate: Date?
    var hrImportDate: Date?
    
    init(applications: Set<String>, timestamp: Date, exportType: ExportType, adImportDate: Date? = nil, hrImportDate: Date? = nil) {
        self.applications = applications
        self.timestamp = timestamp
        self.exportType = exportType
        self.adImportDate = adImportDate
        self.hrImportDate = hrImportDate
    }
    
    init(configuration: ReadConfiguration) throws {
        applications = []
        timestamp = Date()
        exportType = .withoutStatus
        adImportDate = nil
        hrImportDate = nil
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        let title = switch exportType {
            case .withoutName: "Applications without Name"
            case .withoutStatus: "Applications without Status"
            default: "Applications"
        }
        
        var csvString = """
            \(title)
            Baseline check: \(dateFormatter.string(from: timestamp))
            """
        
        if let adDate = adImportDate {
            csvString += "\nLast AD import: \(dateFormatter.string(from: adDate))"
        }
        
        if let hrDate = hrImportDate {
            csvString += "\nLast HR import: \(dateFormatter.string(from: hrDate))"
        }
        
        if exportType == .withoutName {
            csvString += "\n\nAD Group\n"
            csvString += applications.sorted().joined(separator: "\n")
        } else {
            csvString += "\n\nApplication Name,AD Group\n"
            csvString += applications.sorted().map { key -> String in
                let parts = key.split(separator: "|")
                return "\(parts[0]),\(parts[1])"
            }.joined(separator: "\n")
        }
        
        let data = csvString.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
} 