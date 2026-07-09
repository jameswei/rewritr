import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Rewritr")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("Empty macOS app scaffold")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 420, minHeight: 260)
        .padding()
    }
}

