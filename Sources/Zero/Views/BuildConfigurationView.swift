import SwiftUI

struct BuildConfigurationView: View {
    @State private var configuration: BuildConfiguration = .default
    @State private var isCustomImage: Bool = false
    @State private var customImage: String = ""
    private let service: BuildConfigurationService = FileBasedBuildConfigurationService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Build Configuration")
                .font(.title2)
                .fontWeight(.bold)
            
            // JDK Image Section
            VStack(alignment: .leading, spacing: 10) {
                Text("JDK Image")
                    .font(.headline)
                
                JDKSelectorView(
                    configuration: $configuration,
                    isCustomImage: $isCustomImage,
                    customImage: $customImage
                )
            }
            
            // Build Tool Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Build Tool")
                    .font(.headline)
                
                Picker("Build Tool", selection: $configuration.buildTool) {
                    Text("javac").tag(BuildConfiguration.BuildTool.javac)
                    Text("Maven").tag(BuildConfiguration.BuildTool.maven)
                    Text("Gradle").tag(BuildConfiguration.BuildTool.gradle)
                }
                .pickerStyle(.segmented)
            }
            
            // Custom Args Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Custom Arguments")
                    .font(.headline)
                
                TextField("e.g., -Xmx2g", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
            }
            
            Spacer()
            
            // Save Button
            Button(action: saveConfiguration) {
                Text("Save Settings")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
        .onAppear {
            loadConfiguration()
        }
    }
    
    private func loadConfiguration() {
        if let config = try? service.load() {
            configuration = config
        }
    }
    
    private func saveConfiguration() {
        if isCustomImage && !customImage.isEmpty {
            let customJDK = JDKConfiguration(
                id: UUID(),
                name: "Custom",
                image: customImage,
                version: "custom",
                isCustom: true
            )
            configuration.selectedJDK = customJDK
        }
        
        try? service.save(configuration)
    }
}

struct JDKSelectorView: View {
    @Binding var configuration: BuildConfiguration
    @Binding var isCustomImage: Bool
    @Binding var customImage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !isCustomImage {
                Picker("JDK Image", selection: $configuration.selectedJDK) {
                    ForEach(JDKConfiguration.predefined) { jdk in
                        Text(jdk.name).tag(jdk)
                    }
                }
                .pickerStyle(.menu)
            } else {
                TextField("Custom Image (e.g., eclipse-temurin:21)", text: $customImage)
                    .textFieldStyle(.roundedBorder)
            }
            
            Toggle("Use custom image", isOn: $isCustomImage)
                .font(.subheadline)
        }
    }
}

#Preview {
    BuildConfigurationView()
}
