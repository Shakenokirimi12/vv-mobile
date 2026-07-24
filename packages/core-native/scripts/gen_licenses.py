#!/usr/bin/env python3
"""gen_licenses.py — voicevox_vvm のリリースから licenses.json を生成する。

各 .vvm(zip形式)の manifest.json / metas.json を HTTP Range リクエストで
部分取得するため、モデル本体(数十MB)をダウンロードせずに済む。

出力: packages/core-native/generated/licenses.json
  {
    "termsVersion": "<voicevox_vvm タグ>",
    "termsURL": "<リリースの TERMS.txt URL>",
    "models": [
      {"id", "filename", "sizeBytes", "downloadURL", "vvmId",
       "characters": [{"name", "speakerUuid", "creditText", "termsURL", "styles": [...]}]}
    ]
  }
"""
import io
import json
import re
import sys
import time
import urllib.request
from pathlib import Path


def urlopen_retry(req, tries=5, timeout=30):
    for i in range(tries):
        try:
            return urllib.request.urlopen(req, timeout=timeout)
        except Exception as e:  # noqa: BLE001 — リトライ対象を広く取る
            if i == tries - 1:
                raise
            wait = 2**i
            print(f"retry in {wait}s: {e}", file=sys.stderr)
            time.sleep(wait)

ROOT = Path(__file__).resolve().parent.parent
VERSION = dict(
    line.split("=", 1)
    for line in (ROOT / "VERSION").read_text().splitlines()
    if "=" in line
)
VVM_TAG = VERSION["VOICEVOX_VVM_VERSION"]
API = f"https://api.github.com/repos/VOICEVOX/voicevox_vvm/releases/tags/{VVM_TAG}"


class HttpFile(io.RawIOBase):
    """HTTP Range リクエストで zip をシーク可能ファイルとして読む。"""

    def __init__(self, url: str, length: int):
        self.url, self.length, self.pos = url, length, 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def seek(self, pos, whence=0):
        self.pos = (
            pos if whence == 0 else self.pos + pos if whence == 1 else self.length + pos
        )
        return self.pos

    def tell(self):
        return self.pos

    def readinto(self, b):
        n = len(b)
        if n == 0 or self.pos >= self.length:
            return 0
        end = min(self.pos + n, self.length) - 1
        req = urllib.request.Request(
            self.url, headers={"Range": f"bytes={self.pos}-{end}"}
        )
        with urlopen_retry(req) as r:
            data = r.read()
        b[: len(data)] = data
        self.pos += len(data)
        return len(data)


def fetch_json(url: str):
    with urlopen_retry(url) as r:
        return json.load(r)


def fetch_text(url: str) -> str:
    with urlopen_retry(url) as r:
        return r.read().decode("utf-8")


def parse_terms(terms: str) -> dict[str, str]:
    """TERMS.txt の「## キャラクター名」節から利用規約URLを抽出する。"""
    result = {}
    sections = re.split(r"^## ", terms, flags=re.M)[1:]
    for sec in sections:
        name = sec.splitlines()[0].strip()
        m = re.search(r"https?://\S+", sec)
        if m:
            result[name] = m.group(0)
    return result


def main():
    release = fetch_json(API)
    assets = {a["name"]: a for a in release["assets"]}

    terms_url = assets["TERMS.txt"]["browser_download_url"]
    char_terms = parse_terms(fetch_text(terms_url))

    models = []
    vvm_assets = sorted(
        (a for a in release["assets"] if a["name"].endswith(".vvm")),
        key=lambda a: (len(a["name"]), a["name"]),
    )
    for asset in vvm_assets:
        name, url, size = asset["name"], asset["browser_download_url"], asset["size"]
        print(f"reading {name} ...", file=sys.stderr)
        zf = __import__("zipfile").ZipFile(
            io.BufferedReader(HttpFile(url, size), buffer_size=512 * 1024)
        )
        manifest = json.loads(zf.read("manifest.json"))
        metas = json.loads(zf.read(manifest.get("metas_filename", "metas.json")))

        characters = []
        for meta in metas:
            cname = meta["name"]
            characters.append(
                {
                    "name": cname,
                    "speakerUuid": meta.get("speaker_uuid", ""),
                    "creditText": f"VOICEVOX:{cname}",
                    "termsURL": char_terms.get(cname, terms_url),
                    "styles": [
                        {"name": s["name"], "id": s["id"]} for s in meta.get("styles", [])
                    ],
                }
            )

        models.append(
            {
                "id": name.removesuffix(".vvm"),
                "filename": name,
                "sizeBytes": size,
                "downloadURL": url,
                "vvmId": manifest.get("id", ""),
                "characters": characters,
            }
        )

    out = {
        "termsVersion": VVM_TAG,
        "termsURL": terms_url,
        "models": models,
    }
    out_path = ROOT / "generated" / "licenses.json"
    out_path.parent.mkdir(exist_ok=True)
    out_path.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
    print(f"wrote {out_path} ({len(models)} models)", file=sys.stderr)


if __name__ == "__main__":
    main()
