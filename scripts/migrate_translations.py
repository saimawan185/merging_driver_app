#!/usr/bin/env python3
"""Migrate GetX .tr to easy_localization .tr() and sync translation JSON files."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
TRANSLATIONS = ROOT / "assets" / "translations"

GET_IMPORT = re.compile(
    r"import\s+'package:get/get\.dart'\s*;"
    r"|import\s+'package:get/get\.dart'\s+hide\s+Trans\s*;"
    r"|import\s+\"package:get/get\.dart\"\s*;"
)
GET_I18N_IMPORT = re.compile(
    r"import\s+'package:get/get_utils/src/extensions/internacionalization\.dart'\s*;"
)
EASY_IMPORT = "import 'package:easy_localization/easy_localization.dart';"

# Safe patterns for GetX .tr -> easy_localization .tr()
STRING_TR = re.compile(r"(['\"])([^'\"\\]*)\1\.tr(?!\()")
VAR_TR = re.compile(r"\b([a-zA-Z_][a-zA-Z0-9_]*)\.tr(?!\()")

TR_STRING = re.compile(
    r"""((?:'(?:\\'|[^'])*'|"(?:\\'|[^"])*"))\s*\.tr(?:\(\))?"""
)


def unquote(s: str) -> str:
    if s.startswith("'"):
        return s[1:-1].replace("\\'", "'")
    return s[1:-1].replace("\\\"", '"')


def process_dart_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    original = text

    text = STRING_TR.sub(r"\1\2\1.tr()", text)
    text = VAR_TR.sub(r"\1.tr()", text)

    if GET_I18N_IMPORT.search(text):
        text = GET_I18N_IMPORT.sub(EASY_IMPORT, text)

    if GET_IMPORT.search(text):
        text = GET_IMPORT.sub(
            "import 'package:get/get.dart' hide Trans;\n" + EASY_IMPORT,
            text,
        )

    if ".tr()" in text and "easy_localization" not in text:
        lines = text.splitlines()
        insert_at = 0
        for i, line in enumerate(lines):
            if line.startswith("import "):
                insert_at = i + 1
        lines.insert(insert_at, EASY_IMPORT)
        text = "\n".join(lines)
        if original.endswith("\n"):
            text += "\n"

    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def collect_keys_from_code() -> set[str]:
    keys: set[str] = set()
    for path in LIB.rglob("*.dart"):
        content = path.read_text(encoding="utf-8")
        for match in TR_STRING.finditer(content):
            keys.add(unquote(match.group(1)))
    return keys


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, data: dict):
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def sync_translations(keys: set[str]):
    en_path = TRANSLATIONS / "en.json"
    si_path = TRANSLATIONS / "si.json"
    ta_path = TRANSLATIONS / "ta.json"

    en = load_json(en_path)
    si = load_json(si_path)
    ta = load_json(ta_path)

    for key in keys:
        if key not in en:
            en[key] = key

    for lang_data in (si, ta):
        for en_key, en_val in en.items():
            if en_key not in lang_data:
                if en_val in lang_data:
                    lang_data[en_key] = lang_data[en_val]
                elif en_key in lang_data:
                    pass
                else:
                    lang_data[en_key] = en_val

    save_json(en_path, dict(sorted(en.items(), key=lambda x: x[0].lower())))
    save_json(si_path, dict(sorted(si.items(), key=lambda x: x[0].lower())))
    save_json(ta_path, dict(sorted(ta.items(), key=lambda x: x[0].lower())))


def main():
    changed = 0
    for path in LIB.rglob("*.dart"):
        if process_dart_file(path):
            changed += 1
    print(f"Updated {changed} dart files")

    keys = collect_keys_from_code()
    print(f"Found {len(keys)} translation keys in code")
    sync_translations(keys)
    print("Synced en.json, si.json, ta.json")


if __name__ == "__main__":
    main()
