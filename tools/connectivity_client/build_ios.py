"""Build a device IPA on macOS for SideStore to re-sign; no Apple credentials.

Uses an isolated project copy, the Godot command on PATH, and installed Xcode.
Does not install engines, change the source project, or delete existing outputs.
"""
import argparse
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import time
import zipfile


def run(command, log_directory, name, godot=False):
    """Preserve full diagnostics and reject Godot errors even with exit code zero."""
    print("Running:", " ".join(map(str, command)), flush=True)
    result = subprocess.run(list(map(str, command)), text=True, encoding="utf-8",
                            errors="replace", stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (log_directory / (name + ".log")).write_text(result.stdout, encoding="utf-8")
    if result.returncode or (godot and re.search(r"(?m)^(?:SCRIPT ERROR|ERROR):", result.stdout)):
        print(result.stdout[-14000:], flush=True)
        raise RuntimeError(f"{name} failed (exit {result.returncode}); see logs")
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--build-number", default="1")
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("iOS compilation requires macOS + Xcode. Run the GitHub Actions workflow.")
    if not re.fullmatch(r"[1-9][0-9]*", args.build_number):
        parser.error("build-number must be a positive integer")
    source = Path(__file__).resolve().parent / "project"
    root = source.parents[2]
    output = (args.output or root / "tmp" / ("ios_connectivity_" + time.strftime("%Y%m%d_%H%M%S"))).resolve()
    output.mkdir(parents=True, exist_ok=False)
    logs = output / "logs"
    logs.mkdir()
    version = run([args.godot, "--version"], logs, "godot-version").strip()
    xcode = run(["xcodebuild", "-version"], logs, "xcode-version").strip()
    project = output / "project"
    shutil.copytree(source, project, ignore=shutil.ignore_patterns(".godot", "build", "*.apk", "*.aab", "*.ipa"))
    presets = project / "export_presets.cfg"
    presets.write_text(re.sub(r'(?m)^application/version="[^"]*"$',
                             f'application/version="{args.build_number}"',
                             presets.read_text(encoding="utf-8")), encoding="utf-8")
    xcode_dir = output / "xcode"
    xcode_dir.mkdir()
    run([args.godot, "--headless", "--path", project, "--editor", "--import"], logs, "import", godot=True)
    run([args.godot, "--headless", "--path", project, "--script",
         source.parent / "check_font.gd"], logs, "bundled-font", godot=True)
    run([args.godot, "--headless", "--path", project, "--export-release", "iOS SideStore",
         xcode_dir / "ConnectivityProbe.zip"], logs, "export", godot=True)
    # With export_project_only, Godot writes the Xcode project beside this path.
    projects = list(xcode_dir.glob("*.xcodeproj"))
    if len(projects) != 1:
        raise RuntimeError(f"Expected one Xcode project, found {len(projects)}")
    listing = run(["xcodebuild", "-list", "-json", "-project", projects[0]], logs, "schemes")
    schemes = json.loads(listing[listing.index("{"):])["project"]["schemes"]
    if len(schemes) != 1:
        raise RuntimeError(f"Expected one generated scheme, found {schemes}")
    derived = output / "DerivedData"
    run(["xcodebuild", "-project", projects[0], "-scheme", schemes[0], "-configuration", "Release",
         "-sdk", "iphoneos", "-destination", "generic/platform=iOS", "-derivedDataPath", derived,
         "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=",
         "DEVELOPMENT_TEAM=", "ARCHS=arm64", "ONLY_ACTIVE_ARCH=NO", "build"], logs, "xcode-build")
    apps = list((derived / "Build/Products/Release-iphoneos").glob("*.app"))
    if len(apps) != 1:
        raise RuntimeError(f"Expected one device app, found {len(apps)}")
    info = plistlib.loads((apps[0] / "Info.plist").read_bytes())
    if set(info.get("UIDeviceFamily", [])) != {1, 2}:
        raise RuntimeError("Missing iPhone/iPad device family")
    if not info.get("NSLocalNetworkUsageDescription"):
        raise RuntimeError("Missing local network permission description")
    if info.get("CFBundleIdentifier") != "org.godotparty.connectivitytest":
        raise RuntimeError("Unexpected bundle identifier")
    arch = run(["lipo", "-archs", apps[0] / info["CFBundleExecutable"]], logs, "architectures").strip()
    if arch != "arm64":
        raise RuntimeError(f"Expected device arm64 executable, found {arch}")
    payload = output / "Payload"
    payload.mkdir()
    app = payload / apps[0].name
    shutil.copytree(apps[0], app, symlinks=True)
    # Keep redistribution notices accessible alongside the signed application too.
    shutil.copyfile(source / "fonts/FONT-LICENSE.txt", app / "FONT-LICENSE.txt")
    # Ad-hoc signatures have no developer identity or provisioning profile.
    # SideStore replaces these with the device owner's personal signing identity.
    frameworks = sorted(app.rglob("*.framework"), key=lambda p: len(p.parts), reverse=True)
    for index, framework in enumerate(frameworks):
        run(["codesign", "--force", "--sign", "-", framework], logs, f"adhoc-framework-{index}")
    run(["codesign", "--force", "--sign", "-", app], logs, "adhoc-app")
    ipa = output / "GodotParty-Connectivity-iOS-SideStore.ipa"
    run(["ditto", "-c", "-k", "--keepParent", "--norsrc", payload, ipa], logs, "package")
    with zipfile.ZipFile(ipa) as archive:
        required = f"Payload/{app.name}/Info.plist"
        if required not in archive.namelist():
            raise RuntimeError("Invalid IPA structure")
    manifest = {"godot": version, "xcode": xcode, "build": args.build_number,
                "device_family": ["iPhone", "iPad"], "architecture": arch,
                "minimum_os": info.get("MinimumOSVersion"), "ipa_bytes": ipa.stat().st_size,
                "font": "Bundled Noto Sans CJK SC; system fallback disabled; glyph check passed",
                "signing": "Ad-hoc only. Import into SideStore to sign and install.",
                "device_validation": "Not performed by this build."}
    (output / "build-info.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    (output / "INSTALL.txt").write_text(
        "Import GodotParty-Connectivity-iOS-SideStore.ipa into SideStore.\n"
        "This is NOT an App Store/TestFlight or directly installable signed IPA.\n"
        "SideStore setup: https://docs.sidestore.io/docs/installation/prerequisites\n"
        "Allow Local Network access. Turn off LocalDevVPN after signing before network tests.\n"
        "On PC open Listener Test, select matching UDP/TCP, IP and port, then start listening.\n"
        "Free Apple accounts need periodic signing refresh (normally every 7 days).\n",
        encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    print("IPA:", ipa)


if __name__ == "__main__":
    main()
