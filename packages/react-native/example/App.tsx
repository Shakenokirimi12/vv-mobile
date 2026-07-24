import React, {useEffect, useState} from 'react';
import {
  ActivityIndicator,
  Alert,
  FlatList,
  Modal,
  Pressable,
  SafeAreaView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import {getVoicevox, type VoicevoxModel} from 'react-native-voicevox';

const voicevox = getVoicevox();

// 開発検証用: true にすると起動時に DL→合成の自動E2Eを実行する
const AUTO_E2E = false;

type PickerStyle = {label: string; id: number};
type PickerTarget = {model: VoicevoxModel; styles: PickerStyle[]};

export default function App() {
  const [status, setStatus] = useState('初期化中...');
  const [models, setModels] = useState<VoicevoxModel[]>([]);
  const [text, setText] = useState('こんにちは、ずんだもんなのだ');
  const [busy, setBusy] = useState(false);
  const [picker, setPicker] = useState<PickerTarget | null>(null);

  useEffect(() => {
    (async () => {
      try {
        await voicevox.initialize(4);
        const list = await voicevox.listModels();
        setModels(list);
        setStatus(`準備完了 (${list.length} モデル)`);
        if (AUTO_E2E) {
          await runAutoE2E();
        }
      } catch (e) {
        setStatus(`初期化失敗: ${String(e)}`);
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 開発検証用の自動E2E(通常はfalseのままにする)
  const runAutoE2E = async () => {
    setStatus('E2E: 未同意DLの拒否を確認中...');
    try {
      await voicevox.downloadModel('1');
      setStatus('E2E失敗: 未同意DLが通ってしまった');
      return;
    } catch {
      // 期待どおり拒否された
    }
    setStatus('E2E: モデル0をダウンロード中...');
    voicevox.acceptLicense('0');
    await voicevox.downloadModel('0');
    await refresh();
    setStatus('E2E: 合成中...');
    // ずんだもん(スタイル3=ノーマル)
    const wav = await voicevox.synthesis('こんにちは、ずんだもんなのだ', '0', 3);
    const header = String.fromCharCode(...new Uint8Array(wav).slice(0, 4));
    await voicevox.playWav(wav);
    setStatus(`E2E成功(再生開始済): ${wav.byteLength} bytes, header="${header}"`);
  };

  const refresh = async () => setModels(await voicevox.listModels());

  // 規約に同意を得てからダウンロードする。
  const confirmLicenseAndDownload = (model: VoicevoxModel) => {
    if (voicevox.isLicenseAccepted(model.id)) {
      download(model);
      return;
    }
    const characters = model.characters.map(c => c.name).join('、');
    const credit = model.characters[0]?.creditText ?? '';
    Alert.alert(
      '利用規約への同意',
      `このモデルには ${characters} が含まれます。\n\n` +
        '利用には VOICEVOX 音声モデル利用規約および各キャラクターの規約への同意が必要です。' +
        `生成音声の利用時はクレジット表記(例: ${credit})が必要です。\n\n` +
        `規約: ${voicevox.getTermsURL()}`,
      [
        {text: '同意しない', style: 'cancel'},
        {
          text: '同意する',
          onPress: () => {
            voicevox.acceptLicense(model.id);
            download(model);
          },
        },
      ],
    );
  };

  const download = async (model: VoicevoxModel) => {
    setBusy(true);
    setStatus(`${model.id} をダウンロード中...`);
    try {
      await voicevox.downloadModel(model.id);
      await refresh();
      setStatus(`${model.id} ダウンロード完了`);
    } catch (e) {
      setStatus(String(e));
    } finally {
      setBusy(false);
    }
  };

  // キャラクター×スタイル(talkのみ)を選ばせてから合成する。
  // モデルによっては 10〜30 スタイルあるため、Alert.alert(Android で
  // ボタン最大3個の制約あり)ではなくスクロール可能な Modal + FlatList
  // で表示する。
  const selectStyleAndSynthesize = (model: VoicevoxModel) => {
    const styles: PickerStyle[] = model.characters.flatMap(c =>
      c.styles
        .filter(s => s.type === 'talk')
        .map(s => ({label: `${c.name}(${s.name})`, id: s.id})),
    );
    if (styles.length === 0) {
      setStatus('このモデルは歌唱合成用のため読み上げには使えません');
      return;
    }
    setPicker({model, styles});
  };

  const synthesize = async (model: VoicevoxModel, styleId?: number) => {
    setBusy(true);
    setStatus('合成中...');
    try {
      const wav = await voicevox.synthesis(text, model.id, styleId);
      await voicevox.playWav(wav);
      setStatus(
        `再生中 (styleId=${styleId ?? 'auto'}, ${wav.byteLength} bytes)`,
      );
    } catch (e) {
      setStatus(String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.title}>react-native-voicevox example</Text>
      <TextInput
        style={styles.input}
        value={text}
        onChangeText={setText}
        placeholder="読み上げテキスト"
      />
      <View style={styles.statusRow}>
        {busy && <ActivityIndicator style={{marginRight: 8}} />}
        <Text testID="status">{status}</Text>
      </View>
      <Modal
        visible={picker != null}
        animationType="slide"
        transparent
        onRequestClose={() => setPicker(null)}>
        <Pressable style={styles.pickerScrim} onPress={() => setPicker(null)}>
          <Pressable style={styles.pickerSheet} onPress={e => e.stopPropagation()}>
            <Text style={styles.pickerTitle}>
              キャラクター・スタイルを選択({picker?.styles.length ?? 0}件)
            </Text>
            <FlatList
              data={picker?.styles ?? []}
              keyExtractor={s => String(s.id)}
              renderItem={({item}) => (
                <TouchableOpacity
                  style={styles.pickerRow}
                  onPress={() => {
                    const target = picker;
                    setPicker(null);
                    if (target) synthesize(target.model, item.id);
                  }}>
                  <Text style={styles.pickerLabel}>{item.label}</Text>
                </TouchableOpacity>
              )}
            />
            <TouchableOpacity
              style={styles.pickerCancel}
              onPress={() => setPicker(null)}>
              <Text style={styles.pickerCancelLabel}>キャンセル</Text>
            </TouchableOpacity>
          </Pressable>
        </Pressable>
      </Modal>
      <FlatList
        data={models}
        keyExtractor={m => m.id}
        renderItem={({item}) => (
          <View style={styles.row}>
            <Text style={styles.modelLabel} numberOfLines={1}>
              {item.id}: {item.characters.map(c => c.name).join('、')}
            </Text>
            <TouchableOpacity
              disabled={busy}
              testID={`action-${item.id}`}
              onPress={() =>
                item.isDownloaded
                  ? selectStyleAndSynthesize(item)
                  : confirmLicenseAndDownload(item)
              }>
              <Text style={styles.action}>
                {item.isDownloaded ? '再生' : 'DL'}
              </Text>
            </TouchableOpacity>
          </View>
        )}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {flex: 1, padding: 16},
  title: {fontSize: 18, fontWeight: '600', marginBottom: 12},
  input: {borderWidth: 1, borderColor: '#ccc', borderRadius: 8, padding: 8},
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 12,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: '#ddd',
  },
  modelLabel: {flex: 1, marginRight: 8},
  action: {color: '#007aff', fontWeight: '600'},
  pickerScrim: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.35)',
    justifyContent: 'flex-end',
  },
  pickerSheet: {
    backgroundColor: 'white',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    maxHeight: '70%',
    paddingTop: 16,
  },
  pickerTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
    paddingHorizontal: 16,
    paddingBottom: 8,
  },
  pickerRow: {
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderColor: '#eee',
  },
  pickerLabel: {fontSize: 16, color: '#007aff'},
  pickerCancel: {
    paddingVertical: 14,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderColor: '#ddd',
    alignItems: 'center',
  },
  pickerCancelLabel: {fontSize: 16, color: '#666'},
});
