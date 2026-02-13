import SwiftUI

struct SectionHeader: View {
    let icon: String
    let title: String
    var trailingAction: (() -> Void)? = nil
    var trailingIcon: String? = nil
    var trailingLabel: String? = nil
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundColor(.bitcoinOrange)
            
            Spacer()
            
            if let action = trailingAction {
                Button(action: action) {
                    if let label = trailingLabel {
                        Label(label, systemImage: trailingIcon ?? "chevron.right")
                            .font(.caption)
                    } else {
                        Image(systemName: trailingIcon ?? "chevron.right")
                            .font(.caption)
                    }
                }
                .foregroundColor(.bitcoinOrange)
            }
        }
    }
}

#Preview {
    List {
        Section {
            Text("Content")
        } header: {
            SectionHeader(icon: "clock", title: "History", trailingAction: {}, trailingIcon: "trash", trailingLabel: "Clear")
        }
    }
    .preferredColorScheme(.dark)
}
