import type { HybridObject } from 'react-native-nitro-modules'

export interface VoicevoxStyle {
  name: string
  id: number
  /**
   * スタイル種別。"talk" はテキスト読み上げ(synthesis で使用可)、
   * "frame_decode" は歌唱合成用で synthesis では使えない。
   */
  type: string
}

export interface VoicevoxCharacter {
  name: string
  speakerUuid: string
  /** 生成音声の利用時に必要なクレジット表記(例: "VOICEVOX:ずんだもん")。 */
  creditText: string
  /** キャラクター個別の利用規約URL。 */
  termsURL: string
  styles: VoicevoxStyle[]
}

// NOTE: 名前を「VoicevoxModel」にしているのは、ネイティブ実装(vendored された
// packages/swift の VoicevoxModelInfo 型)と nitrogen 生成 Swift 構造体が
// 同一ターゲット内で名前衝突しないようにするため。
export interface VoicevoxModel {
  id: string
  filename: string
  sizeBytes: number
  downloadURL: string
  vvmId: string
  /** モデルが対応する合成ドメイン(例: ["talk"]、歌唱モデルは ["frame_decode"])。 */
  domains: string[]
  characters: VoicevoxCharacter[]
  isDownloaded: boolean
}

/** downloadModels の1件分の結果。error が undefined なら成功。 */
export interface DownloadResult {
  modelId: string
  error?: string
}

/**
 * VOICEVOX CORE の高レベル Facade。
 * ネイティブ実装は packages/swift / packages/android の Voicevox Facade への
 * 薄いグルーで、JSI (Nitro) 経由で直接呼び出される。
 */
export interface Voicevox
  extends HybridObject<{ ios: 'swift'; android: 'kotlin' }> {
  /**
   * ネイティブ初期化(ONNX Runtime・辞書展開)。他のメソッドより先に呼ぶこと。
   * @param maxConcurrentDownloads 並列ダウンロードの同時実行数(既定4)。
   */
  initialize(maxConcurrentDownloads: number): Promise<void>

  /** 利用可能な全モデルの一覧(ダウンロード状態付き)。 */
  listModels(): Promise<VoicevoxModel[]>

  /** 全モデル共通の利用規約(VOICEVOX 音声モデル利用規約)のURL。 */
  getTermsURL(): string

  /** モデルの利用規約に同意する。アプリ側は規約を提示した上で呼ぶこと。 */
  acceptLicense(modelId: string): void

  /** 同意状態を確認する。 */
  isLicenseAccepted(modelId: string): boolean

  /** 1モデルをダウンロードする(要同意)。ダウンロード済みなら何もしない。 */
  downloadModel(id: string): Promise<void>

  /**
   * 複数モデルを並列ダウンロードする。
   * 一部失敗でも reject せず、モデルごとの成否を返す。
   */
  downloadModels(ids: string[]): Promise<DownloadResult[]>

  /** 全モデルを一括ダウンロードする(全モデルへの同意が必要)。 */
  downloadAllModels(): Promise<DownloadResult[]>

  /**
   * テキストから音声(WAV)を合成する。
   * モデル未ダウンロード時は reject する(暗黙のダウンロードはしない)。
   * @param styleId 省略時はモデル先頭キャラクターの先頭スタイル。
   */
  synthesis(
    text: string,
    modelId: string,
    styleId?: number
  ): Promise<ArrayBuffer>

  /**
   * synthesis が返した WAV をネイティブ側で再生する(再生開始で resolve)。
   * 再生中に再度呼ぶと前の再生を停止して新しい音声を再生する。
   */
  playWav(wav: ArrayBuffer): Promise<void>

  /** 再生を停止する。 */
  stopPlayback(): void
}
