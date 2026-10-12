#!/usr/bin/env python3
"""檢查五種語言檔：key 一致、占位符一致、沒有 Dart 插值用的美元符號。"""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent / "lib" / "i18n"
langs = ["zh", "ja", "en", "pt", "es"]
entry = re.compile(r"^\s*'([^']+)':\s*\"((?:[^\"\\]|\\.)*)\",\s*$")


def load(lang):
    out = {}
    for i, line in enumerate((root / f"{lang}.dart").read_text(encoding="utf-8").splitlines(), 1):
        if line.strip().startswith("'") and "':" in line:
            m = entry.match(line)
            if not m:
                print(f"{lang}.dart:{i}: 無法解析：{line.strip()[:70]}")
                sys.exit(1)
            if m.group(1) in out:
                print(f"{lang}.dart:{i}: key 重複：{m.group(1)}")
                sys.exit(1)
            out[m.group(1)] = m.group(2)
    return out


data = {l: load(l) for l in langs}
base = data["zh"]
ok = True
for l in langs:
    missing = sorted(set(base) - set(data[l]))
    extra = sorted(set(data[l]) - set(base))
    if missing or extra:
        ok = False
        print(f"[{l}] 缺少 {len(missing)}：{missing[:8]}  多出 {len(extra)}：{extra[:8]}")
    for k, v in data[l].items():
        if "$" in v:
            ok = False
            print(f"[{l}] {k} 含有美元符號")
        if k in base and set(re.findall(r"\{(\w+)\}", v)) != set(re.findall(r"\{(\w+)\}", base[k])):
            ok = False
            print(f"[{l}] {k} 占位符不一致：{re.findall(r'{(\w+)}', v)} vs {re.findall(r'{(\w+)}', base[k])}")
        if not v.strip():
            ok = False
            print(f"[{l}] {k} 是空字串")

print("keys:", {l: len(data[l]) for l in langs})
print("OK" if ok else "FAILED")
sys.exit(0 if ok else 1)
