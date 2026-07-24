#!/usr/bin/env python3
"""normalize_header.py — 公式 voicevox_core.h を全ビルド環境共通で使える形に正規化する。

正規化は2点:

1. ONNX Runtime リンクモードのマクロ
   公式ヘッダはプラットフォーム別zipごとに VOICEVOX_LOAD/LINK_ONNXRUNTIME を
   ハードコードしている。単一ヘッダを全プラットフォームで共有できるよう、
   コンパイル時のプラットフォーム判定に置き換える。

2. enum と typedef の型面の統一
   公式ヘッダは
       enum VoicevoxResultCode
       #ifdef __cplusplus
         : int32_t
       #endif
       { ... };
       #ifndef __cplusplus
       typedef int32_t VoicevoxResultCode;
       #endif
   という形で、Cモードでは typedef(=int32_t)、C++モードでは enum 型が
   関数シグネチャに現れる。Swift から見ると C ビルド(SwiftPM)では Int32、
   C++ interop ビルド(Nitro/React Native ポッド)では独自 enum 型となり、
   同じ Swift ソースが片方でしかコンパイルできなくなる。
   enum タグを別名(<Name>Values)にリネームし typedef を無条件化することで、
   どちらのモードでも関数シグネチャを int32_t(Swift では Int32)に揃える。
   定数(VOICEVOX_RESULT_OK 等)は無スコープ enum のため従来どおり利用できる。

使い方: normalize_header.py <src_header> <dst_header>
(src と dst は同一パスでもよい)
"""
import re
import sys

ONNXRUNTIME_CONDITIONAL = """\
// vv-mobile: 単一ヘッダを全プラットフォームで使うため条件分岐に正規化。
// 公式リリースのライブラリは iOS のみリンク時動的リンク(LINK)、
// その他のプラットフォームは実行時ロード(LOAD)。
#if !defined(VOICEVOX_LINK_ONNXRUNTIME) && !defined(VOICEVOX_LOAD_ONNXRUNTIME)
#if defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#define VOICEVOX_LINK_ONNXRUNTIME
#else
#define VOICEVOX_LOAD_ONNXRUNTIME
#endif
#else
#define VOICEVOX_LOAD_ONNXRUNTIME
#endif
#endif
"""


def normalize(text: str) -> str:
    # --- 1. ONNX Runtime マクロ ---
    # プラットフォームにより「コメント→define」「define→コメント」の両順がある
    text, n = re.subn(
        r"^(?://)?#define VOICEVOX_(?:LINK|LOAD)_ONNXRUNTIME\n"
        r"(?://)?#define VOICEVOX_(?:LINK|LOAD)_ONNXRUNTIME\n",
        ONNXRUNTIME_CONDITIONAL,
        text,
        flags=re.M,
    )
    if n != 1:
        # すでに正規化済みのヘッダを再処理した場合はスキップ
        assert "vv-mobile: 単一ヘッダ" in text, "ONNXRUNTIME macro block not found"

    # --- 2. enum タグのリネーム + typedef の無条件化 ---
    # 対象パターン(公式ヘッダの int32_t/uint32_t ベース enum すべて):
    #   enum <Name>\n#ifdef __cplusplus\n  : <int_t>\n#endif // __cplusplus\n {
    #   ...
    #   #ifndef __cplusplus\ntypedef <int_t> <Name>;\n#endif // __cplusplus
    def rename_enum(m: re.Match) -> str:
        name = m.group("name")
        return m.group(0).replace(f"enum {name}", f"enum {name}Values", 1)

    text = re.sub(
        r"enum (?P<name>Voicevox\w+)\n#ifdef __cplusplus\n"
        r"  : u?int32_t\n#endif // __cplusplus\n",
        rename_enum,
        text,
    )
    text = re.sub(
        r"#ifndef __cplusplus\n"
        r"(?P<typedef>typedef u?int32_t Voicevox\w+;)\n"
        r"#endif // __cplusplus\n",
        r"// vv-mobile: C/C++両モードで typedef を関数シグネチャの型として使う\n"
        r"\g<typedef>\n",
        text,
    )
    return text


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, encoding="utf-8") as f:
        text = f.read()
    normalized = normalize(text)
    # 検証: 条件付き typedef が残っていないこと
    leftovers = re.findall(
        r"#ifndef __cplusplus\ntypedef u?int32_t \w+;", normalized
    )
    assert not leftovers, f"unconverted typedefs remain: {leftovers}"
    with open(dst, "w", encoding="utf-8") as f:
        f.write(normalized)
    print(f"normalized: {dst}")


if __name__ == "__main__":
    main()
