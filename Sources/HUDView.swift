import SwiftUI
import AppKit

class HUDViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var sizeText: String = "Calculating..."
    @Published var detailText: String = ""
    @Published var breakdown: [(name: String, sizeText: String)] = []
    @Published var canCopy: Bool = false

    private var currentTaskID: UUID?
    private var lastBreakdown: SizeBreakdown?

    func update(result: Result<[URL], FinderError>) {
        let taskID = UUID()
        self.currentTaskID = taskID

        switch result {
        case .success(let items):
            if items.isEmpty {
                self.title = "No Selection"
                self.sizeText = "0 Bytes"
                self.detailText = ""
                self.breakdown = []
                self.canCopy = false
                self.lastBreakdown = nil
                return
            }

            if items.count == 1 {
                self.title = items.first!.lastPathComponent
            } else {
                self.title = "\(items.count) items selected"
            }

            self.sizeText = "Calculating..."
            self.detailText = ""
            self.breakdown = []
            self.canCopy = false
            self.lastBreakdown = nil

            DispatchQueue.global(qos: .userInitiated).async {
                let breakdown = SizeCalculator.calculateBreakdown(for: items)

                DispatchQueue.main.async {
                    if self.currentTaskID != taskID { return }
                    self.apply(breakdown)
                }
            }
        case .failure(let error):
            self.title = "Permission Error"
            self.sizeText = "Failed to Read"
            self.detailText = ""
            self.breakdown = []
            self.canCopy = false
            self.lastBreakdown = nil
            print("Error: \(error.message)")
        }
    }

    private func apply(_ breakdown: SizeBreakdown) {
        self.lastBreakdown = breakdown
        self.sizeText = ByteFormatter.string(from: breakdown.totalBytes)

        var parts: [String] = []
        parts.append("\(ByteFormatter.count(breakdown.fileCount)) files")
        if breakdown.folderCount > 0 {
            parts.append("\(ByteFormatter.count(breakdown.folderCount)) folders")
        }
        if breakdown.unreadableCount > 0 {
            parts.append("\(ByteFormatter.count(breakdown.unreadableCount)) unreadable")
        }
        self.detailText = parts.joined(separator: " · ")

        self.breakdown = breakdown.topItems.map {
            (name: $0.name, sizeText: ByteFormatter.string(from: $0.bytes))
        }
        self.canCopy = breakdown.totalBytes > 0
    }

    func copyToClipboard() {
        guard let breakdown = lastBreakdown else { return }

        var lines: [String] = [title, sizeText]
        if !detailText.isEmpty { lines.append(detailText) }
        if !breakdown.topItems.isEmpty {
            lines.append("")
            for item in breakdown.topItems {
                lines.append("\(ByteFormatter.string(from: item.bytes))\t\(item.name)")
            }
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
    }
}

enum ByteFormatter {
    static func string(from bytes: Int64) -> String {
        let gib = Double(bytes) / 1073741824.0
        if gib >= 1.0 { return String(format: "%.2f GiB", gib) }

        let mib = Double(bytes) / 1048576.0
        if mib >= 1.0 { return String(format: "%.2f MiB", mib) }

        let kib = Double(bytes) / 1024.0
        if kib >= 1.0 { return String(format: "%.2f KiB", kib) }

        return "\(bytes) Bytes"
    }

    static func count(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
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

            if !viewModel.detailText.isEmpty {
                Text(viewModel.detailText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !viewModel.breakdown.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(viewModel.breakdown.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(item.sizeText)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.08))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 16) {
                Text("Press Ctrl+Shift+Space to close")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if viewModel.canCopy {
                    Button(action: viewModel.copyToClipboard) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("c", modifiers: .command)
                }
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(minWidth: 300, idealWidth: 340, maxWidth: .infinity, minHeight: 150, idealHeight: 220, maxHeight: .infinity)
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
