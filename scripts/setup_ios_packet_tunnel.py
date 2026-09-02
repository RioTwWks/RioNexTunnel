#!/usr/bin/env python3
"""Merge PacketTunnel Network Extension target from v2ray_box example into secure_vpn_client."""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
PBX = ROOT / "secure_vpn_client/ios/Runner.xcodeproj/project.pbxproj"
EXAMPLE = ROOT / "packages/v2ray_box/example/ios/Runner.xcodeproj/project.pbxproj"

# PacketTunnel-related object IDs from the example project (no CocoaPods IDs).
OBJECT_IDS = {
    "11ABC4052F0E6C9800C14FFA",
    "11ABC40D2F0E6C9800C14FFA",
    "11ABC4162F0E6ECA00C14FFA",
    "11ABC4172F0E6ECA00C14FFA",
    "11ABC4422F0E703C00C14FFA",
    "11ABC4432F0E705100C14FFA",
    "11ABC40B2F0E6C9800C14FFA",
    "11ABC4912F0E7A1800C14FFA",
    "11ABC40E2F0E6C9800C14FFA",
    "11ABC4182F0E6ECA00C14FFA",
    "11ABC4032F0E6C9800C14FFA",
    "11ABC4042F0E6C9800C14FFA",
    "11ABC4142F0E6CFF00C14FFA",
    "11ABC4152F0E6ECA00C14FFA",
    "11ABC4412F0E702E00C14FFA",
    "11ABC4122F0E6C9800C14FFA",
    "11ABC4062F0E6C9800C14FFA",
    "11ABC4002F0E6C9800C14FFA",
    "F4555D451D1842937C52AEA0",
    "11ABC4022F0E6C9800C14FFA",
    "11ABC3FF2F0E6C9800C14FFA",
    "11ABC4012F0E6C9800C14FFA",
    "11ABC40C2F0E6C9800C14FFA",
    "11ABC4922F0E7A1800C14FFA",
    "11ABC40F2F0E6C9800C14FFA",
    "11ABC4102F0E6C9800C14FFA",
    "11ABC4112F0E6C9800C14FFA",
    "11ABC4132F0E6C9800C14FFA",
}

SECTION_FOR_ID: dict[str, str] = {
    "11ABC4052F0E6C9800C14FFA": "PBXBuildFile",
    "11ABC40D2F0E6C9800C14FFA": "PBXBuildFile",
    "11ABC4162F0E6ECA00C14FFA": "PBXBuildFile",
    "11ABC4172F0E6ECA00C14FFA": "PBXBuildFile",
    "11ABC4422F0E703C00C14FFA": "PBXBuildFile",
    "11ABC4432F0E705100C14FFA": "PBXBuildFile",
    "11ABC40B2F0E6C9800C14FFA": "PBXContainerItemProxy",
    "11ABC4912F0E7A1800C14FFA": "PBXContainerItemProxy",
    "11ABC40E2F0E6C9800C14FFA": "PBXCopyFilesBuildPhase",
    "11ABC4182F0E6ECA00C14FFA": "PBXCopyFilesBuildPhase",
    "11ABC4032F0E6C9800C14FFA": "PBXFileReference",
    "11ABC4042F0E6C9800C14FFA": "PBXFileReference",
    "11ABC4142F0E6CFF00C14FFA": "PBXFileReference",
    "11ABC4152F0E6ECA00C14FFA": "PBXFileReference",
    "11ABC4412F0E702E00C14FFA": "PBXFileReference",
    "11ABC4122F0E6C9800C14FFA": "PBXFileSystemSynchronizedBuildFileExceptionSet",
    "11ABC4062F0E6C9800C14FFA": "PBXFileSystemSynchronizedRootGroup",
    "11ABC4002F0E6C9800C14FFA": "PBXFrameworksBuildPhase",
    "F4555D451D1842937C52AEA0": "PBXGroup",
    "11ABC4022F0E6C9800C14FFA": "PBXNativeTarget",
    "11ABC4012F0E6C9800C14FFA": "PBXResourcesBuildPhase",
    "11ABC3FF2F0E6C9800C14FFA": "PBXSourcesBuildPhase",
    "11ABC40C2F0E6C9800C14FFA": "PBXTargetDependency",
    "11ABC4922F0E7A1800C14FFA": "PBXTargetDependency",
    "11ABC40F2F0E6C9800C14FFA": "XCBuildConfiguration",
    "11ABC4102F0E6C9800C14FFA": "XCBuildConfiguration",
    "11ABC4112F0E6C9800C14FFA": "XCBuildConfiguration",
    "11ABC4132F0E6C9800C14FFA": "XCConfigurationList",
}


def extract_objects(text: str) -> dict[str, str]:
    """Extract top-level pbx objects keyed by UUID."""
    objects: dict[str, str] = {}
    pattern = re.compile(r"^\t\t([A-F0-9]{24}) /\*.*?\*/ = \{", re.M)
    for match in pattern.finditer(text):
        obj_id = match.group(1)
        start = match.start()
        depth = 0
        i = match.end() - 1
        while i < len(text):
            ch = text[i]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    end = i + 1
                    if end < len(text) and text[end] == ";":
                        end += 1
                    objects[obj_id] = text[start:end]
                    break
            i += 1
    return objects


def section_body(text: str, name: str) -> str:
    match = re.search(
        rf"/\* Begin {name} section \*/\n(.*?)/\* End {name} section \*/",
        text,
        re.S,
    )
    return match.group(1) if match else ""


def insert_before_section_end(content: str, section: str, block: str) -> str:
    marker = f"/* End {section} section */"
    if block.strip() in content:
        return content
    return content.replace(marker, block + marker, 1)


def localize_bundle_ids(text: str) -> str:
    text = text.replace("com.example.v2rayBoxExample", "com.example.secureVpnClient")
    # Drop example team ID — developers set their own in Xcode.
    lines = [line for line in text.splitlines() if "DEVELOPMENT_TEAM" not in line]
    return "\n".join(lines)


def patch_frameworks_group(obj: str) -> str:
    """Drop CocoaPods framework references from the Frameworks group."""
    lines = []
    for line in obj.splitlines():
        if "Pods_" in line or "Pods-" in line:
            continue
        lines.append(line)
    return "\n".join(lines)


def patch_runner_target(content: str) -> str:
    runner_marker = "97C146ED1CF9000F007C117D /* Runner */ = {"
    runner_start = content.find(runner_marker)
    if runner_start == -1:
        return content
    runner_end = content.find("/* End PBXNativeTarget section */", runner_start)
    runner_block = content[runner_start:runner_end]

    if "11ABC40E2F0E6C9800C14FFA /* Embed Foundation Extensions */" not in runner_block:
        runner_block = runner_block.replace(
            "\t\t\t\t9705A1C41CF9048500538489 /* Embed Frameworks */,\n"
            "\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n",
            "\t\t\t\t9705A1C41CF9048500538489 /* Embed Frameworks */,\n"
            "\t\t\t\t11ABC40E2F0E6C9800C14FFA /* Embed Foundation Extensions */,\n"
            "\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n",
        )

    if "11ABC40C2F0E6C9800C14FFA /* PBXTargetDependency */" not in runner_block:
        runner_block = runner_block.replace(
            "\t\t\tdependencies = (\n"
            "\t\t\t);\n"
            "\t\t\tname = Runner;\n",
            "\t\t\tdependencies = (\n"
            "\t\t\t\t11ABC40C2F0E6C9800C14FFA /* PBXTargetDependency */,\n"
            "\t\t\t\t11ABC4922F0E7A1800C14FFA /* PBXTargetDependency */,\n"
            "\t\t\t);\n"
            "\t\t\tname = Runner;\n",
        )

    return content[:runner_start] + runner_block + content[runner_end:]


def patch_groups(content: str) -> str:
    if "11ABC4062F0E6C9800C14FFA /* PacketTunnel */" not in content:
        content = content.replace(
            "\t\t\tchildren = (\n"
            "\t\t\t\t9740EEB11CF90186004384FC /* Flutter */,\n"
            "\t\t\t\t97C146F01CF9000F007C117D /* Runner */,\n"
            "\t\t\t\t97C146EF1CF9000F007C117D /* Products */,\n"
            "\t\t\t\t331C8082294A63A400263BE5 /* RunnerTests */,\n"
            "\t\t\t);\n",
            "\t\t\tchildren = (\n"
            "\t\t\t\t9740EEB11CF90186004384FC /* Flutter */,\n"
            "\t\t\t\t97C146F01CF9000F007C117D /* Runner */,\n"
            "\t\t\t\t11ABC4062F0E6C9800C14FFA /* PacketTunnel */,\n"
            "\t\t\t\t97C146EF1CF9000F007C117D /* Products */,\n"
            "\t\t\t\t331C8082294A63A400263BE5 /* RunnerTests */,\n"
            "\t\t\t\tF4555D451D1842937C52AEA0 /* Frameworks */,\n"
            "\t\t\t);\n",
        )
    if "11ABC4032F0E6C9800C14FFA /* PacketTunnel.appex */" not in content:
        content = content.replace(
            "\t\t\tchildren = (\n"
            "\t\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,\n"
            "\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n"
            "\t\t\t);\n"
            "\t\t\tname = Products;\n",
            "\t\t\tchildren = (\n"
            "\t\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,\n"
            "\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n"
            "\t\t\t\t11ABC4032F0E6C9800C14FFA /* PacketTunnel.appex */,\n"
            "\t\t\t);\n"
            "\t\t\tname = Products;\n",
        )
    if "11ABC4142F0E6CFF00C14FFA /* Runner.entitlements */" not in content:
        content = content.replace(
            "\t\t\tchildren = (\n"
            "\t\t\t\t97C146FA1CF9000F007C117D /* Main.storyboard */,\n",
            "\t\t\tchildren = (\n"
            "\t\t\t\t11ABC4142F0E6CFF00C14FFA /* Runner.entitlements */,\n"
            "\t\t\t\t97C146FA1CF9000F007C117D /* Main.storyboard */,\n",
        )
    return content


def patch_project(content: str) -> str:
    if "11ABC4022F0E6C9800C14FFA /* PacketTunnel */," not in content:
        content = content.replace(
            "\t\t\ttargets = (\n"
            "\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,\n"
            "\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n"
            "\t\t\t);\n",
            "\t\t\ttargets = (\n"
            "\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,\n"
            "\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n"
            "\t\t\t\t11ABC4022F0E6C9800C14FFA /* PacketTunnel */,\n"
            "\t\t\t);\n",
        )
    if "11ABC4022F0E6C9800C14FFA = {" not in content:
        content = content.replace(
            "\t\t\t\tTargetAttributes = {\n"
            "\t\t\t\t\t331C8080294A63A400263BE5 = {\n",
            "\t\t\t\tTargetAttributes = {\n"
            "\t\t\t\t\t11ABC4022F0E6C9800C14FFA = {\n"
            "\t\t\t\t\t\tCreatedOnToolsVersion = 26.2;\n"
            "\t\t\t\t\t};\n"
            "\t\t\t\t\t331C8080294A63A400263BE5 = {\n",
        )
    return content


def patch_runner_entitlements(content: str) -> str:
    if "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements" in content:
        return content
    return content.replace(
        "\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n",
        "\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n"
        "\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n",
    )


def validate(content: str) -> list[str]:
    errors: list[str] = []
    required = [
        "isa = PBXNativeTarget",
        "11ABC4022F0E6C9800C14FFA /* PacketTunnel */",
        "buildPhases = (",
        "fileSystemSynchronizedGroups = (",
        "productType = \"com.apple.product-type.app-extension\"",
        "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements",
        "com.example.secureVpnClient.PacketTunnel",
    ]
    for token in required:
        if token not in content:
            errors.append(f"missing: {token}")
    # PacketTunnel target must be a complete object.
    if "11ABC4022F0E6C9800C14FFA /* PacketTunnel */ = {" in content:
        start = content.index("11ABC4022F0E6C9800C14FFA /* PacketTunnel */ = {")
        snippet = content[start : start + 800]
        if "isa = PBXNativeTarget" not in snippet:
            errors.append("PacketTunnel target missing isa = PBXNativeTarget")
    return errors


def main() -> int:
    if not EXAMPLE.is_file():
        print(f"Example project not found: {EXAMPLE}", file=sys.stderr)
        return 1

    example_text = EXAMPLE.read_text(encoding="utf-8")
    example_objects = extract_objects(example_text)
    missing = OBJECT_IDS - set(example_objects)
    if missing:
        print(f"Missing objects in example: {sorted(missing)}", file=sys.stderr)
        return 1

    content = PBX.read_text(encoding="utf-8")
    sections_added: dict[str, list[str]] = {}

    for obj_id in sorted(OBJECT_IDS):
        section = SECTION_FOR_ID[obj_id]
        obj = localize_bundle_ids(example_objects[obj_id])
        if obj_id == "F4555D451D1842937C52AEA0":
            obj = patch_frameworks_group(obj)
        if obj_id in content:
            continue
        sections_added.setdefault(section, []).append(obj)

    # Ensure FileSystemSynchronized sections exist (Flutter template may lack them).
    for section_name in (
        "PBXFileSystemSynchronizedBuildFileExceptionSet",
        "PBXFileSystemSynchronizedRootGroup",
    ):
        if section_name not in content and section_name in {SECTION_FOR_ID[i] for i in OBJECT_IDS}:
            marker = "/* Begin PBXFileReference section */"
            if section_name == "PBXFileSystemSynchronizedRootGroup":
                block = (
                    f"\n/* Begin {section_name} section */\n"
                    + "\n".join(sections_added.pop(section_name, []))
                    + f"\n/* End {section_name} section */\n\n"
                )
                content = content.replace(marker, block + marker, 1)
            else:
                block = (
                    f"\n/* Begin {section_name} section */\n"
                    + "\n".join(sections_added.pop(section_name, []))
                    + f"\n/* End {section_name} section */\n\n"
                )
                content = content.replace(marker, block + marker, 1)

    for section, blocks in sections_added.items():
        block = "\n".join(blocks) + "\n"
        content = insert_before_section_end(content, section, block)

    content = patch_runner_target(content)
    content = patch_groups(content)
    content = patch_project(content)
    content = patch_runner_entitlements(content)

    errors = validate(content)
    if errors:
        print("Validation failed:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    PBX.write_text(content, encoding="utf-8")
    print(f"Patched {PBX} ({len(OBJECT_IDS)} objects merged)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
