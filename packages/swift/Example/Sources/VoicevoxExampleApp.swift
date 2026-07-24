import AVFoundation
import SwiftUI
import VoicevoxCore

@main
struct VoicevoxExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var voicevox: Voicevox?
    @State private var models: [VoicevoxModelInfo] = []
    @State private var text = "こんにちは、ずんだもんなのだ"
    @State private var status = "初期化中..."
    @State private var busy = false
    @State private var licenseTarget: VoicevoxModelInfo?
    @State private var styleTarget: VoicevoxModelInfo?
    @State private var player: AVAudioPlayer?

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("読み上げテキスト", text: $text)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    if busy { ProgressView().padding(.trailing, 4) }
                    Text(status).font(.footnote)
                }
                List(models) { model in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("モデル \(model.id)").font(.headline)
                            Text(model.characters.map(\.name).joined(separator: "、"))
                                .font(.caption)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button(model.isDownloaded ? "再生" : "DL") {
                            if model.isDownloaded {
                                styleTarget = model
                            } else {
                                licenseTarget = model
                            }
                        }
                        .disabled(busy)
                    }
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("VoicevoxCore example")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await initialize() }
        .alert(
            "利用規約への同意",
            isPresented: Binding(
                get: { licenseTarget != nil },
                set: { if !$0 { licenseTarget = nil } }
            ),
            presenting: licenseTarget
        ) { model in
            Button("同意しない", role: .cancel) {}
            Button("同意する") {
                Task { await download(model, accepted: true) }
            }
        } message: { model in
            Text(
                "このモデルには \(model.characters.map(\.name).joined(separator: "、")) が含まれます。\n"
                    + "利用には VOICEVOX 音声モデル利用規約および各キャラクターの規約への同意が必要です。"
                    + "生成音声の利用時はクレジット表記(例: \(model.characters.first?.creditText ?? ""))が必要です。"
            )
        }
        .confirmationDialog(
            "キャラクター・スタイルを選択",
            isPresented: Binding(
                get: { styleTarget != nil },
                set: { if !$0 { styleTarget = nil } }
            ),
            titleVisibility: .visible,
            presenting: styleTarget
        ) { model in
            ForEach(model.characters, id: \.speakerUuid) { character in
                ForEach(character.talkStyles, id: \.id) { style in
                    Button("\(character.name)(\(style.name))") {
                        Task { await synthesize(model, styleId: style.id) }
                    }
                }
            }
            if !model.supportsTalk {
                Button("このモデルは歌唱合成用のため読み上げ不可") {}
            }
        }
    }

    private func initialize() async {
        do {
            let voicevox = try Voicevox()
            self.voicevox = voicevox
            models = await voicevox.listModels()
            status = "準備完了 (\(models.count) モデル)"

            // 開発検証用の自動E2E(simctl launch --setenv VV_AUTO_E2E 1 で有効化)
            if ProcessInfo.processInfo.environment["VV_AUTO_E2E"] == "1" {
                await runAutoE2E(voicevox)
            }
        } catch {
            status = "初期化失敗: \(error.localizedDescription)"
        }
    }

    private func runAutoE2E(_ voicevox: Voicevox) async {
        status = "E2E: 未同意DLの拒否を確認中..."
        do {
            try await voicevox.downloadModel(id: "1")
            status = "E2E失敗: 未同意DLが通ってしまった"
            return
        } catch {
            // 期待どおり拒否された
        }
        do {
            status = "E2E: モデル0をダウンロード中..."
            voicevox.acceptLicense(modelId: "0")
            try await voicevox.downloadModel(id: "0")
            models = await voicevox.listModels()
            status = "E2E: 合成中..."
            // ずんだもん(スタイル3=ノーマル)
            let wav = try await voicevox.synthesis(
                text: "こんにちは、ずんだもんなのだ", modelId: "0", styleId: 3)
            let header = String(data: wav.prefix(4), encoding: .ascii) ?? "?"
            status = "E2E成功: \(wav.count) bytes, header=\"\(header)\""
        } catch {
            status = "E2E失敗: \(error.localizedDescription)"
        }
    }

    private func download(_ model: VoicevoxModelInfo, accepted: Bool) async {
        guard let voicevox, accepted else { return }
        busy = true
        status = "\(model.id) をダウンロード中..."
        defer { busy = false }
        do {
            voicevox.acceptLicense(modelId: model.id)
            try await voicevox.downloadModel(id: model.id)
            models = await voicevox.listModels()
            status = "\(model.id) ダウンロード完了"
        } catch {
            status = error.localizedDescription
        }
    }

    private func synthesize(_ model: VoicevoxModelInfo, styleId: UInt32? = nil) async {
        guard let voicevox else { return }
        busy = true
        status = "合成中..."
        defer { busy = false }
        do {
            let wav = try await voicevox.synthesis(text: text, modelId: model.id, styleId: styleId)
            player = try AVAudioPlayer(data: wav)
            player?.play()
            status = "再生中 (styleId=\(styleId.map(String.init) ?? "auto"), \(wav.count) bytes)"
        } catch {
            status = error.localizedDescription
        }
    }
}
