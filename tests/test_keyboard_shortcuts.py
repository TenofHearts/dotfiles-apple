import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


class KeyboardShortcutTests(unittest.TestCase):
    def test_karabiner_routes_editing_and_clipboard_history_by_app(self):
        profile = json.loads((ROOT / "config/karabiner/karabiner.json").read_text())["profiles"][0]
        rules = profile["complex_modifications"]["rules"]
        cases = {"com.apple.Terminal": False, "com.mitchellh.ghostty": False,
                 "net.kovidgoyal.kitty": False, "com.microsoft.rdc.macos": False,
                 "com.apple.finder": True, "com.apple.Safari": True, "com.microsoft.VSCode": True}
        for modifier, key in (("control", "a"), ("control", "c"), ("control", "v"), ("command", "v")):
            for app, is_gui in cases.items():
                with self.subTest(modifier=modifier, key=key, app=app):
                    matches = [m for rule in rules for m in rule["manipulators"]
                               if m["from"].get("any") == "key_code" or
                               (m["from"].get("key_code") == key and
                                modifier in m["from"]["modifiers"]["mandatory"])]
                    for m in matches:
                        if all(c["type"] == "frontmost_application_if" and
                               any(re.search(p, app) for p in c["bundle_identifiers"])
                               for c in m.get("conditions", [])):
                            break
                    else:
                        self.fail("Missing shortcut or passthrough rule")
                    expected = {"key_code": key, "modifiers": ["command"]} if is_gui else {"from_event": True}
                    if modifier == "command" and app != "com.microsoft.rdc.macos":
                        expected = {"key_code": "f18", "repeat": False}
                        self.assertEqual(m["from"]["modifiers"], {"mandatory": ["command"], "optional": ["caps_lock"]})
                    self.assertEqual(m["to"], [expected])
