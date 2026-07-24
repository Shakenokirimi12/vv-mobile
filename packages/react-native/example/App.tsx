import React, {useEffect, useState} from 'react';
import {
  ActivityIndicator,
  FlatList,
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

export default function App() {
  const [status, setStatus] = useState('初期化中...');
  const [models, setModels] = useState<VoicevoxModel[]>([]);
  const [text, setText] = useState('こんにちは、ずんだもんなのだ');
  const [busy, setBusy] = useState(false);

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
    setStatus(`E2E成功: ${wav.byteLength} bytes, header="${header}"`);
  };

  const refresh = async () => setModels(await voicevox.listModels());

  const download = async (model: VoicevoxModel) => {
    if (!voicevox.isLicenseAccepted(model.id)) {
      voicevox.acceptLicense(model.id);
    }
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

  const synthesize = async (model: VoicevoxModel) => {
    setBusy(true);
    setStatus('合成中...');
    try {
      const wav = await voicevox.synthesis(text, model.id);
      const bytes = new Uint8Array(wav);
      const header = String.fromCharCode(...bytes.slice(0, 4));
      setStatus(`合成完了: ${wav.byteLength} bytes, header="${header}"`);
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
                item.isDownloaded ? synthesize(item) : download(item)
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
});
