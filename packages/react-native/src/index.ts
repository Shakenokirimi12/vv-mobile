import { NitroModules } from 'react-native-nitro-modules'
import type { Voicevox } from './specs/Voicevox.nitro'

export type {
  DownloadResult,
  Voicevox,
  VoicevoxCharacter,
  VoicevoxModelInfo,
  VoicevoxStyle,
} from './specs/Voicevox.nitro'

let instance: Voicevox | null = null

/**
 * Voicevox の共有インスタンスを取得する。
 *
 * ```ts
 * const voicevox = getVoicevox()
 * await voicevox.initialize(4)
 * const models = await voicevox.listModels()
 * voicevox.acceptLicense('0')
 * await voicevox.downloadModel('0')
 * const wav = await voicevox.synthesis('こんにちは', '0')
 * ```
 */
export function getVoicevox(): Voicevox {
  if (instance == null) {
    instance = NitroModules.createHybridObject<Voicevox>('Voicevox')
  }
  return instance
}
