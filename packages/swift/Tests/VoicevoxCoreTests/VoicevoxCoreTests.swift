import Foundation
import XCTest

@testable import VoicevoxCore

final class VoicevoxCoreTests: XCTestCase {
    // macOS テスト実行時に dlopen する ONNX Runtime のパス(リポジトリ内の xcframework)
    static let onnxruntimePath = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // VoicevoxCoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // packages/swift
        .appendingPathComponent(
            "Binaries/voicevox_onnxruntime.xcframework/macos-arm64_x86_64/voicevox_onnxruntime.framework/voicevox_onnxruntime"
        ).path

    func testCatalogDecodes() throws {
        let catalog = try LicenseCatalog.bundled()
        XCTAssertFalse(catalog.models.isEmpty)
        XCTAssertFalse(catalog.termsVersion.isEmpty)
        // 全モデルにキャラクターとスタイルがある
        for model in catalog.models {
            XCTAssertFalse(model.characters.isEmpty, "model \(model.id) has no characters")
            XCTAssertFalse(model.characters[0].styles.isEmpty)
            XCTAssertTrue(model.downloadURL.hasPrefix("https://"))
            XCTAssertFalse(model.domains.isEmpty, "model \(model.id) has no domains")
        }
        // モデル0は talk 対応で複数キャラクター・複数スタイルを持つ
        let model0 = catalog.models.first { $0.id == "0" }!
        XCTAssertTrue(model0.supportsTalk)
        XCTAssertEqual(model0.characters.count, 4)
        XCTAssertEqual(model0.characters.flatMap(\.talkStyles).count, 10)
        // s0(歌唱合成用)は talk 非対応
        let s0 = catalog.models.first { $0.id == "s0" }!
        XCTAssertFalse(s0.supportsTalk)
        XCTAssertTrue(s0.characters.flatMap(\.talkStyles).isEmpty)
    }

    func testVoicevoxCatalogReadsWithoutNativeInit() throws {
        // ONNX Runtime も Open JTalk 辞書も要らずに読めること
        let tempModels = FileManager.default.temporaryDirectory
            .appendingPathComponent("catalog-test-\(UUID().uuidString)")
        let catalog = try VoicevoxCatalog(modelsDir: tempModels)

        XCTAssertFalse(catalog.models().isEmpty)
        XCTAssertFalse(catalog.termsURL.isEmpty)
        // 何も落としていないので、全部未取得で合計 0
        XCTAssertTrue(catalog.models().allSatisfy { !$0.isDownloaded })
        XCTAssertEqual(catalog.downloadedSize(), 0)
    }

    func testCatalogResolvesModelFromStyleId() throws {
        let catalog = try VoicevoxCatalog()
        // ずんだもん(ノーマル)はスタイルID 3、モデル 0 に属する
        XCTAssertEqual(catalog.model(forStyle: 3)?.id, "0")
        XCTAssertNil(catalog.model(forStyle: 99999))
    }

    func testSynthesizerModelIdLookupMatchesCatalog() throws {
        let voicevox = try Voicevox(onnxruntimePath: Self.onnxruntimePath)
        let catalog = try VoicevoxCatalog()
        for model in catalog.models() {
            for style in model.characters.flatMap(\.talkStyles) {
                XCTAssertEqual(voicevox.modelId(forStyle: style.id), model.id)
            }
        }
    }

    func testSynthesisRejectsSongOnlyModel() async throws {
        let voicevox = try Voicevox(
            onnxruntimePath: Self.onnxruntimePath,
            modelsDir: FileManager.default.temporaryDirectory
                .appendingPathComponent("vv-empty-\(UUID().uuidString)")
        )
        do {
            _ = try await voicevox.synthesis(text: "テスト", modelId: "s0")
            XCTFail("should throw talkNotSupported")
        } catch let error as VoicevoxError {
            XCTAssertEqual(error, .talkNotSupported(modelId: "s0"))
        }
    }

    func testLicenseGateBlocksAndAccepts() throws {
        let suiteName = "vv-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let gate = LicenseGate(termsVersion: "0.16.4", defaults: defaults)
        XCTAssertFalse(gate.isAccepted(modelId: "0"))
        XCTAssertThrowsError(try gate.require(modelId: "0")) { error in
            XCTAssertEqual(error as? VoicevoxError, .licenseNotAccepted(modelId: "0"))
        }

        gate.accept(modelId: "0")
        XCTAssertTrue(gate.isAccepted(modelId: "0"))
        XCTAssertNoThrow(try gate.require(modelId: "0"))

        // 規約バージョンが変わると再同意が必要
        let newGate = LicenseGate(termsVersion: "0.17.0", defaults: defaults)
        XCTAssertFalse(newGate.isAccepted(modelId: "0"))

        gate.revoke(modelId: "0")
        XCTAssertFalse(gate.isAccepted(modelId: "0"))
    }

    func testSynthesizerInitAndVersion() throws {
        XCTAssertEqual(Synthesizer.coreVersion, "0.16.4")
        let synth = try Synthesizer(onnxruntimePath: Self.onnxruntimePath)
        XCTAssertFalse(synth.isLoaded(modelId: "0"))
    }

    func testSynthesisFailsWithoutDownload() async throws {
        let voicevox = try Voicevox(
            onnxruntimePath: Self.onnxruntimePath,
            modelsDir: FileManager.default.temporaryDirectory
                .appendingPathComponent("vv-empty-\(UUID().uuidString)")
        )
        do {
            _ = try await voicevox.synthesis(text: "テスト", modelId: "0")
            XCTFail("should throw modelNotDownloaded")
        } catch let error as VoicevoxError {
            XCTAssertEqual(error, .modelNotDownloaded(modelId: "0"))
        }
    }

    /// E2E: モデルをダウンロードして実際に合成する(VV_E2E=1 のときのみ)。
    func testEndToEndSynthesis() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["VV_E2E"] == "1", "set VV_E2E=1 to run")

        let voicevox = try Voicevox(onnxruntimePath: Self.onnxruntimePath)

        let models = await voicevox.listModels()
        XCTAssertFalse(models.isEmpty)

        // ずんだもん(スタイル3=ノーマル)を含むモデル0を使用
        voicevox.acceptLicense(modelId: "0")
        try await voicevox.downloadModel(id: "0")

        let wav = try await voicevox.synthesis(text: "こんにちは、ずんだもんなのだ", modelId: "0", styleId: 3)
        // WAV ヘッダ("RIFF")と十分なデータ長を確認
        XCTAssertGreaterThan(wav.count, 44)
        XCTAssertEqual(String(data: wav.prefix(4), encoding: .ascii), "RIFF")

        // 同一モデル内の別スタイル(ずんだもん あまあま=1)でも合成でき、
        // 結果がノーマル(3)と異なることを確認(スタイル指定が効いている)
        let wavAmaama = try await voicevox.synthesis(
            text: "こんにちは、ずんだもんなのだ", modelId: "0", styleId: 1)
        XCTAssertEqual(String(data: wavAmaama.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertNotEqual(wav, wavAmaama)

        // デフォルト(styleId未指定)は最初のtalkスタイル(四国めたん ノーマル=2)
        let wavDefault = try await voicevox.synthesis(
            text: "こんにちは、ずんだもんなのだ", modelId: "0")
        XCTAssertEqual(String(data: wavDefault.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertNotEqual(wavDefault, wav)

        // 検証用に書き出し
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("vv_e2e_output.wav")
        try wav.write(to: out)
        print("E2E wav written to: \(out.path)")
    }

    /// E2E: 複数モデルの並列ダウンロード(VV_E2E=1 のときのみ)。
    func testParallelDownload() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["VV_E2E"] == "1", "set VV_E2E=1 to run")

        let voicevox = try Voicevox(onnxruntimePath: Self.onnxruntimePath, maxConcurrentDownloads: 2)
        let ids = ["1", "2"]
        for id in ids { voicevox.acceptLicense(modelId: id) }

        let results = await voicevox.downloadModels(ids: ids)
        for id in ids {
            if case .failure(let error)? = results[id] {
                XCTFail("download \(id) failed: \(error)")
            }
        }

        // 未同意モデルはブロックされる(結果としてlicenseNotAcceptedが返る)
        let blocked = await voicevox.downloadModels(ids: ["3"])
        if case .failure(let error)? = blocked["3"] {
            XCTAssertEqual(error, .licenseNotAccepted(modelId: "3"))
        } else {
            XCTFail("download of unaccepted model should fail")
        }
    }
}
