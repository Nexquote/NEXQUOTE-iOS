#!/usr/bin/env python3
import json
import plistlib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def plist(relative: str) -> dict:
    with (ROOT / relative).open("rb") as handle:
        return plistlib.load(handle)


def main() -> int:
    failures = []
    required = [
        "App.xcodeproj/project.pbxproj",
        "App.xcodeproj/xcshareddata/xcschemes/App.xcscheme",
        "App/public/index.html",
        "App/public/bridge.js",
        "App/public/styles.css",
        "Shared/PrivacyInfo.xcprivacy",
    ]
    failures.extend(f"missing {path}" for path in required if not (ROOT / path).is_file())

    for path in [
        "App/Info.plist",
        "App/App.entitlements",
        "ShareExtension/Info.plist",
        "ShareExtension/ShareExtension.entitlements",
        "Shared/PrivacyInfo.xcprivacy",
    ]:
        try:
            plist(path)
        except Exception as error:
            failures.append(f"invalid plist {path}: {error}")

    for path in [
        "App.xcodeproj/xcshareddata/xcschemes/App.xcscheme",
        "App/Base.lproj/Main.storyboard",
        "App/Base.lproj/LaunchScreen.storyboard",
        "App/config.xml",
    ]:
        try:
            ET.parse(ROOT / path)
        except Exception as error:
            failures.append(f"invalid XML {path}: {error}")

    try:
        capacitor = json.loads(read("App/capacitor.config.json"))
        if capacitor.get("appId") != "com.nexquote.app" or capacitor.get("webDir") != "public":
            failures.append("Capacitor appId/webDir contract drift")
    except Exception as error:
        failures.append(f"invalid Capacitor config: {error}")

    app_info = plist("App/Info.plist")
    extension_info = plist("ShareExtension/Info.plist")
    app_entitlements = plist("App/App.entitlements")
    extension_entitlements = plist("ShareExtension/ShareExtension.entitlements")
    group = ["group.com.nexquote.app"]
    if app_entitlements.get("com.apple.security.application-groups") != group:
        failures.append("App Group mismatch in App entitlements")
    if extension_entitlements.get("com.apple.security.application-groups") != group:
        failures.append("App Group mismatch in Share Extension entitlements")
    if app_info.get("NQAppMode") != "$(NQ_APP_MODE)":
        failures.append("App mode is not build-configured")
    if extension_info.get("NSExtension", {}).get("NSExtensionPointIdentifier") != "com.apple.share-services":
        failures.append("Share Extension point identifier drift")

    pbx = read("App.xcodeproj/project.pbxproj")
    definitions = set(re.findall(r"^\s*([A-F0-9]{24})(?: /\*.*?\*/)? = \{", pbx, re.MULTILINE))
    references = set(re.findall(r"\b[A-F0-9]{24}\b", pbx))
    undefined = sorted(references - definitions)
    if undefined:
        failures.append(f"undefined Xcode object references: {', '.join(undefined)}")
    for token in ["AppTests", "AppUITests", "ShareExtension", "Localizable.strings", "Debug.xcconfig", "Release.xcconfig"]:
        if token not in pbx:
            failures.append(f"Xcode project missing {token}")
    if 'TARGETED_DEVICE_FAMILY = "1,2"' in pbx:
        failures.append("Xcode project still declares iPad support")

    scheme = read("App.xcodeproj/xcshareddata/xcschemes/App.xcscheme")
    for target in ["App.app", "AppTests.xctest", "AppUITests.xctest"]:
        if target not in scheme:
            failures.append(f"shared scheme missing {target}")

    debug_config = read("Config/Debug.xcconfig")
    release_config = read("Config/Release.xcconfig")
    shared_config = read("Config/Shared.xcconfig")
    if "NQ_APP_MODE = harness" not in shared_config:
        failures.append("public default must remain harness mode")
    if "TARGETED_DEVICE_FAMILY = 1" not in shared_config:
        failures.append("public build must remain iPhone-only")
    if '#include "Shared.xcconfig"' not in debug_config or '#include "Shared.xcconfig"' not in release_config:
        failures.append("xcconfig inheritance drift")

    html = read("App/public/index.html")
    bridge = read("App/public/bridge.js")
    if "connect-src 'none'" not in html or "Content-Security-Policy" not in html:
        failures.append("local harness CSP missing or too broad")
    for token in ["nq:native-route", "nq:native-share", "type: 'ready'", "type: 'ack'"]:
        if token not in bridge:
            failures.append(f"local harness bridge missing {token}")

    keys = {
        "quick.create_quote", "quick.import_rates", "quick.decision_inbox",
        "share.save", "share.save_failed",
    }
    for language in ["en", "vi"]:
        strings = read(f"Shared/{language}.lproj/Localizable.strings")
        missing = sorted(key for key in keys if f'"{key}"' not in strings)
        if missing:
            failures.append(f"{language} localization missing: {', '.join(missing)}")

    swift = "\n".join(path.read_text(encoding="utf-8") for path in (ROOT / "App").rglob("*.swift"))
    swift += "\n" + "\n".join(path.read_text(encoding="utf-8") for path in (ROOT / "ShareExtension").rglob("*.swift"))
    if re.search(r"\b(?:NSLog|print)\s*\(", swift):
        failures.append("native source contains runtime logging")

    if failures:
        print("Project validation failed:")
        print("\n".join(f"- {failure}" for failure in failures))
        return 1
    print("Project validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

