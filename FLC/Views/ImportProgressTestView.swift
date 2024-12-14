import SwiftUI

struct ImportProgressTestView: View {
    @StateObject private var progress = ImportProgress()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Progress Test")
                .font(.title)
            
            if progress.isProcessing {
                ImportProgressView(
                    progress: progress.progressValue,
                    currentOperation: progress.currentOperation
                )
            }
            
            // Test controls
            VStack(spacing: 10) {
                Button("Start Test") {
                    startTest()
                }
                .buttonStyle(.bordered)
                
                Button("Reset") {
                    progress.reset()
                }
                .buttonStyle(.bordered)
                
                // Manual progress control
                HStack {
                    Text("Progress:")
                    Slider(value: Binding(
                        get: { progress.progressValue },
                        set: { newValue in
                            progress.update(operation: "Manual progress test", progress: newValue)
                        }
                    ), in: 0...1)
                }
                .padding()
            }
            .disabled(progress.isProcessing)
        }
        .padding()
        .frame(width: 400)
    }
    
    private func startTest() {
        progress.isProcessing = true
        
        // Simulate a process with different stages
        Task {
            // Stage 1
            progress.update(operation: "Starting test...", progress: 0.0)
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Stage 2
            progress.update(operation: "Processing stage 1", progress: 0.25)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Stage 3
            progress.update(operation: "Processing stage 2", progress: 0.5)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Stage 4
            progress.update(operation: "Processing stage 3", progress: 0.75)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Complete
            progress.update(operation: "Completed", progress: 1.0)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            progress.isProcessing = false
        }
    }
}

#Preview {
    ImportProgressTestView()
} 