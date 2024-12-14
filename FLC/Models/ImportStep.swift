import Foundation

class ImportStep: Identifiable {
    let id = UUID()
    let title: String
    var status: StepStatus = .pending
    
    enum StepStatus {
        case pending
        case inProgress
        case completed
        case failed
    }
    
    init(title: String) {
        self.title = title
    }
} 