import SwiftUI
import GuitarPracticeCore

struct IntegrationSettingsView: View {
    @State private var endpoint = UserDefaults.standard.string(forKey: "lightElement.endpoint") ?? ""
    @State private var model = UserDefaults.standard.string(forKey: "lightElement.model") ?? ""
    @State private var token = ""
    @State private var status: String?
    @State private var hasToken = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Light Element").font(Theme.title(30))
            Text("Connect when your endpoint and token are available. No connection is needed for local practice and recording.").font(Theme.body(13)).foregroundStyle(Theme.muted)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                GridRow { Text("Full endpoint"); TextField("https://your-host/…/chat/completions", text: $endpoint).textFieldStyle(.roundedBorder) }
                GridRow { Text("Model"); TextField("Your deployment model name", text: $model).textFieldStyle(.roundedBorder) }
                GridRow { Text("Access token"); SecureField(hasToken ? "Saved in Keychain · enter to replace" : "Add later", text: $token).textFieldStyle(.roundedBorder) }
            }.font(Theme.body(12))
            Text("Wire format: OpenAI-compatible chat completions (provisional). The full endpoint is used exactly as entered; its format must be confirmed against your Light Element deployment.")
                .font(Theme.body(12)).foregroundStyle(Theme.muted)
            HStack {
                Button("Remove token") {
                    do { try Credentials.save(""); hasToken = false; status = "Token removed from Keychain." } catch { status = error.localizedDescription }
                }.disabled(!hasToken)
                Spacer()
                Button("Save settings") { save() }.buttonStyle(PrimaryButtonStyle())
            }
            if let status { Text(status).font(Theme.body(12)).foregroundStyle(Theme.muted).textSelection(.enabled) }
        }.padding(30).background(Theme.paper).foregroundStyle(Theme.ink).tint(Theme.accent)
            .onAppear { hasToken = Credentials.token() != nil }
    }
    private func save() {
        do {
            if !endpoint.isEmpty || !model.isEmpty { _ = try LightElementConfiguration(endpoint: endpoint, model: model).validatedURL() }
            if !token.isEmpty { try Credentials.save(token); token = ""; hasToken = true }
            UserDefaults.standard.set(endpoint, forKey: "lightElement.endpoint")
            UserDefaults.standard.set(model, forKey: "lightElement.model")
            status = "Settings saved. Live connectivity has not been tested."
        } catch { status = error.localizedDescription }
    }
}
