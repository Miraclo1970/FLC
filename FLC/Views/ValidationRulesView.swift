import SwiftUI

struct ValidationRulesView: View {
    @StateObject private var validationStore = ValidationConfigStore.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(validationStore.configurations) { config in
                    ValidationSection(config: config)
                }
            }
            .padding()
        }
    }
}

struct ValidationSection: View {
    let config: ValidationConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(config.title)
                .font(.title2)
                .foregroundColor(.blue)
                .padding(.bottom, 8)
            
            // Validation Rules
            VStack(alignment: .leading, spacing: 4) {
                Text("Validation Rules")
                    .foregroundColor(.blue)
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(config.rules) { rule in
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 8))
                                .padding(.top, 6)
                            Text(rule.description)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
            
            // Required Fields
            VStack(alignment: .leading, spacing: 4) {
                Text("Required Fields")
                    .foregroundColor(.blue)
                    .padding(.vertical, 4)
                
                HStack(spacing: 8) {
                    ForEach(config.requiredFields, id: \.self) { field in
                        Text(field)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.top, 8)
            
            // Optional Fields
            VStack(alignment: .leading, spacing: 4) {
                Text("Optional Fields")
                    .foregroundColor(.blue)
                    .padding(.vertical, 4)
                
                HStack(spacing: 8) {
                    ForEach(config.optionalFields, id: \.self) { field in
                        Text(field)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.top, 8)
            
            Divider()
                .padding(.vertical, 16)
        }
    }
}

#Preview {
    ValidationRulesView()
} 