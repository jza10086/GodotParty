"""Build selected GodotParty content and a SideStore IPA on a macOS runner.

The existing mobile content exporter owns dependency closure, PCK classes and
loose-file declarations. This script owns the iOS host and Xcode packaging.
"""
import argparse
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import zipfile


def run(command, logs, name, godot=False):
    print(f"[{name}]", flush=True)
    result = subprocess.run(list(map(str, command)), stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
    (logs / f"{name}.log").write_text(result.stdout, encoding="utf-8")
    if result.returncode or (godot and re.search(r"(?m)^(?:SCRIPT ERROR|ERROR):", result.stdout)):
        print(result.stdout[-14000:], flush=True)
        raise RuntimeError(f"{name} failed ({result.returncode}); see logs/{name}.log")
    return result.stdout


def import_project(godot, project, logs, name):
    """First import cannot load a custom theme whose imported fonts do not exist."""
    config = project / "project.godot"
    original = config.read_bytes()
    text = original.decode("utf-8-sig")
    text = re.sub(r"(?ms)^\[(?:autoload|editor_plugins)\].*?(?=^\[|\Z)", "", text)
    text = re.sub(r"(?m)^theme/custom(?:_font)?=.*\n?", "", text)
    config.write_text(text, encoding="utf-8")
    try:
        run([godot, "--headless", "--path", project, "--import"], logs, name, godot=True)
    finally:
        config.write_bytes(original)


def prepare_host(content_project, host, bundle, root, build_number):
    host.mkdir()
    # This already-sanitized staging project contains framework files only in core/.
    shutil.copytree(content_project / "core", host / "core")
    shutil.copyfile(content_project / "icon.svg", host / "icon.svg")
    shutil.copyfile(content_project / "project.godot", host / "project.godot")
    data = host / "core/runtime/party_data.gd"
    text, count = re.subn(r'(?m)^const SYSTEM: String = "android"$',
                         'const SYSTEM: String = "ios"', data.read_text(encoding="utf-8"))
    if count != 1:
        raise RuntimeError("Mobile staging did not declare framework SYSTEM android")
    data.write_text(text, encoding="utf-8")
    shutil.copyfile(bundle, host / "core/bundled_content.zip")
    notices = host / "core/notices"
    notices.mkdir(exist_ok=True)
    for name in ("LICENSE", "LICENSE-CC0.txt", "ASSET_LICENSES.md"):
        shutil.copyfile(root / name, notices / name)
    shutil.copyfile(root / "doc/credits.md", notices / "credits.md")
    preset = (root / "core/dev/ios_export_presets.cfg").read_text(encoding="utf-8")
    preset = preset.replace('application/version="1"', f'application/version="{build_number}"')
    (host / "export_presets.cfg").write_text(preset, encoding="utf-8")


def compile_ipa(godot, host, output, logs):
    xcode_dir = output / "xcode"
    xcode_dir.mkdir()
    run([godot, "--headless", "--path", host, "--export-release", "iOS SideStore",
         xcode_dir / "GodotParty.zip"], logs, "ios-export", godot=True)
    projects = list(xcode_dir.glob("*.xcodeproj"))
    if len(projects) != 1:
        raise RuntimeError(f"Expected one Xcode project, found {len(projects)}")
    listing = run(["xcodebuild", "-list", "-json", "-project", projects[0]], logs, "schemes")
    schemes = json.loads(listing[listing.index("{"):])["project"]["schemes"]
    if len(schemes) != 1:
        raise RuntimeError(f"Expected one scheme, found {schemes}")
    derived = output / "DerivedData"
    run(["xcodebuild", "-project", projects[0], "-scheme", schemes[0], "-configuration", "Release",
         "-sdk", "iphoneos", "-destination", "generic/platform=iOS", "-derivedDataPath", derived,
         "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=",
         "DEVELOPMENT_TEAM=", "ARCHS=arm64", "ONLY_ACTIVE_ARCH=NO", "build"], logs, "xcode-build")
    apps = list((derived / "Build/Products/Release-iphoneos").glob("*.app"))
    if len(apps) != 1:
        raise RuntimeError(f"Expected one device app, found {len(apps)}")
    info = plistlib.loads((apps[0] / "Info.plist").read_bytes())
    if 2 not in info["UIDeviceFamily"] or info["CFBundleIdentifier"] != "org.godotparty.play":
        raise RuntimeError("Wrong device family or application identifier")
    if not info.get("NSLocalNetworkUsageDescription") or not info.get("NSMicrophoneUsageDescription"):
        raise RuntimeError("Missing local network or microphone usage description")
    arch = run(["lipo", "-archs", apps[0] / info["CFBundleExecutable"]], logs, "architectures").strip()
    if arch != "arm64":
        raise RuntimeError(f"Expected arm64 device executable, found {arch}")
    payload = output / "Payload"
    payload.mkdir()
    app = payload / apps[0].name
    shutil.copytree(apps[0], app, symlinks=True)
    # Keep redistribution notices readable without unpacking the Godot PCK.
    shutil.copytree(host / "core/notices", app / "notices")
    for index, framework in enumerate(sorted(app.rglob("*.framework"), key=lambda p: len(p.parts), reverse=True)):
        run(["codesign", "--force", "--sign", "-", framework], logs, f"sign-framework-{index}")
    run(["codesign", "--force", "--sign", "-", app], logs, "sign-app")
    ipa = output / "release/GodotParty-iOS-SideStore.ipa"
    run(["ditto", "-c", "-k", "--keepParent", "--norsrc", payload, ipa], logs, "package")
    with zipfile.ZipFile(ipa) as archive:
        if f"Payload/{app.name}/Info.plist" not in archive.namelist():
            raise RuntimeError("Invalid IPA structure")
        for name in ("LICENSE", "LICENSE-CC0.txt", "ASSET_LICENSES.md", "credits.md"):
            if f"Payload/{app.name}/notices/{name}" not in archive.namelist():
                raise RuntimeError(f"IPA is missing redistribution notice: {name}")
    return {"architecture": arch, "minimum_os": info["MinimumOSVersion"],
            "device_family": info["UIDeviceFamily"], "ipa_bytes": ipa.stat().st_size}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--build-number", required=True)
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("Run on the GitHub macOS runner with Xcode")
    if not re.fullmatch(r"[1-9][0-9]*", args.build_number):
        parser.error("build-number must be a positive integer")
    request = json.loads(args.request.read_text(encoding="utf-8-sig"))
    if type(request.get("core")) is not bool or not isinstance(request.get("packages"), list):
        parser.error("Request requires core boolean and packages array")
    if not request["core"] and not request["packages"]:
        parser.error("Select core or at least one package")
    if any(not isinstance(package, str) or not re.fullmatch(r"[a-z0-9_]+", package) for package in request["packages"]):
        parser.error("Invalid package ID")
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    logs = output / "logs"
    logs.mkdir()
    release = output / "release"
    release.mkdir()
    version = run([args.godot, "--version"], logs, "godot-version").strip()
    revision = run(["git", "-C", root, "rev-parse", "HEAD"], logs, "revision").strip()
    import_project(args.godot, root, logs, "catalog-import")
    mobile = output / "mobile"
    mobile.mkdir()
    (mobile / "build").mkdir()
    (mobile / "android_payload").mkdir()
    mobile_request = mobile / "request.json"
    mobile_request.write_text(json.dumps({"platform": "iOS", "core": False,
                                         "packages": request["packages"]}), encoding="utf-8")
    # No Android SDK is needed: only the common mobile content stage runs.
    try:
        run(["pwsh", "-NoProfile", "-File", root / "core/dev/export_android.ps1",
             "-RequestPath", mobile_request, "-GodotPath", args.godot], logs, "mobile-content")
    finally:
        for log in mobile.glob("*.log"):
            shutil.copyfile(log, logs / log.name)
    bundle = release / "GodotParty-content-ios.zip"
    shutil.copyfile(mobile / "build/GodotParty-content-android.zip", bundle)
    with zipfile.ZipFile(bundle) as archive:
        bundle_info = json.loads(archive.read("bundle.json"))
    result = {"revision": revision, "godot": version, "build": args.build_number,
              "requested": request["packages"], "packages": bundle_info["packages"],
              "core": request["core"], "device_validation": "Not performed",
              "signing": "Ad-hoc; SideStore must re-sign before installation"}
    if request["core"]:
        result["xcode"] = run(["xcodebuild", "-version"], logs, "xcode-version").strip()
        host = output / "host"
        prepare_host(mobile / "android_content", host, bundle, root, args.build_number)
        import_project(args.godot, host, logs, "host-import")
        result.update(compile_ipa(args.godot, host, output, logs))
    (release / "build-info.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    (release / "INSTALL.txt").write_text(
        "GodotParty iOS / iPad preview\n"
        "Import the IPA into SideStore to re-sign and install.\n"
        "This is NOT a directly installable or App Store/TestFlight signed IPA.\n"
        "SideStore setup: https://docs.sidestore.io/docs/installation/prerequisites\n"
        "Allow Local Network access when creating or joining a LAN room.\n"
        "Touch emulates left mouse. Touch the upper-left corner to reveal Esc, then tap again.\n"
        "Player configuration stays in the app sandbox. Keep the same signing identity and bundle ID\n"
        "when updating; uninstalling the app deletes its data.\n"
        "Content-only builds contain no IPA. Use the in-game content ZIP importer and restart.\n"
        "iPad device, gameplay and network acceptance still require manual testing.\n",
        encoding="utf-8")
    print("IOS_EXPORT_PASS", json.dumps(result), flush=True)


if __name__ == "__main__":
    main()
