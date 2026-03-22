import SwiftUI

class HUDViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var sizeText: String = "Calculating..."
    
    private var currentTaskID: UUID?
    
    func update(result: Result<[URL], FinderError>) {
        let taskID = UUID()
        self.currentTaskID = taskID
        
        switch result {
        case .success(let items):
            if items.isEmpty {
                self.title = "No Selection"
                self.sizeText = "0 Bytes"
                return
            }
            
            if items.count == 1 {
                self.title = items.first!.lastPathComponent
            } else {
                self.title = "\(items.count) items selected"
            }
            
            self.sizeText = "Calculating..."
            
            DispatchQueue.global(qos: .userInitiated).async {
                let bytes = SizeCalculator.calculateTotalSize(for: items)
                let gib = Double(bytes) / 1073741824.0
                
                DispatchQueue.main.async {
                    if self.currentTaskID != taskID { return }
                    
                    if gib >= 1.0 {
                        self.sizeText = String(format: "%.2f GiB", gib)
                    } else {
                        let mib = Double(bytes) / 1048576.0
                        if mib >= 1.0 {
                            self.sizeText = String(format: "%.2f MiB", mib)
                        } else {
                            let kib = Double(bytes) / 1024.0
                            if kib >= 1.0 {
                                self.sizeText = String(format: "%.2f KiB", kib)
                            } else {
                                self.sizeText = "\(bytes) Bytes"
                            }
                        }
                    }
                }
            }
        case .failure(let error):
            self.title = "Permission Error"
            self.sizeText = "Failed to Read"
            print("Error: \(error.message)")
        }
    }
}

struct HUDView: View {
    @ObservedObject var viewModel: HUDViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 44))
                .foregroundColor(.blue)
            
            Text(viewModel.title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Text(viewModel.sizeText)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                
            Text("Press Ctrl+Shift+Space to close")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(minWidth: 300, idealWidth: 340, maxWidth: .infinity, minHeight: 150, idealHeight: 180, maxHeight: .infinity)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea())
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
