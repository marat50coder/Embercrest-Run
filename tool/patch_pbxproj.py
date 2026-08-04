#!/usr/bin/env python3
"""One-shot pbxproj patcher: wires SceneDelegate, entitlements,
GoogleService-Info.plist and the EmberMediaService NSE target into the Runner
project. Binary-safe, no BOM, LF preserved. Idempotency is NOT required — run
once against the pristine (backed-up) file.
"""
import secrets
import sys

PBX = "ios/Runner.xcodeproj/project.pbxproj"


def uid():
    return secrets.token_hex(12).upper()


# ── new object ids ────────────────────────────────────────────────────────
SCENE_REF = uid(); SCENE_BUILD = uid()
ENT_REF = uid()
GSI_REF = uid(); GSI_BUILD = uid()
NSE_APPEX_REF = uid(); NSE_SWIFT_REF = uid(); NSE_PLIST_REF = uid()
NSE_GROUP = uid(); NSE_TARGET = uid()
NSE_SOURCES = uid(); NSE_FRAMEWORKS = uid(); NSE_RESOURCES = uid()
NSE_SWIFT_BUILD = uid()
EMBED_PHASE = uid(); NSE_APPEX_BUILD = uid()
NSE_PROXY = uid(); NSE_DEP = uid()
NSE_CFG_DEBUG = uid(); NSE_CFG_RELEASE = uid(); NSE_CFG_PROFILE = uid()
NSE_CFG_LIST = uid()

TEAM = "T72S4TZ35D"
NSE_BUNDLE = "com.embercrest.rungame.NotificationService"

with open(PBX, "rb") as f:
    txt = f.read().decode("utf-8")
assert txt[:1] != "\ufeff", "unexpected BOM"

orig = txt


def replace_once(old, new):
    global txt
    count = txt.count(old)
    assert count == 1, f"anchor not unique ({count}):\n{old[:120]}"
    txt = txt.replace(old, new, 1)


# 1. PBXBuildFile entries
replace_once(
    "/* Begin PBXBuildFile section */\n",
    "/* Begin PBXBuildFile section */\n"
    f"\t\t{SCENE_BUILD} /* SceneDelegate.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {SCENE_REF} /* SceneDelegate.swift */; }};\n"
    f"\t\t{GSI_BUILD} /* GoogleService-Info.plist in Resources */ = {{isa = PBXBuildFile; fileRef = {GSI_REF} /* GoogleService-Info.plist */; }};\n"
    f"\t\t{NSE_SWIFT_BUILD} /* NotificationService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {NSE_SWIFT_REF} /* NotificationService.swift */; }};\n"
    f"\t\t{NSE_APPEX_BUILD} /* EmberMediaService.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {NSE_APPEX_REF} /* EmberMediaService.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n",
)

# 2. PBXContainerItemProxy
replace_once(
    "/* Begin PBXContainerItemProxy section */\n",
    "/* Begin PBXContainerItemProxy section */\n"
    f"\t\t{NSE_PROXY} /* PBXContainerItemProxy */ = {{\n"
    f"\t\t\tisa = PBXContainerItemProxy;\n"
    f"\t\t\tcontainerPortal = 97C146E61CF9000F007C117D /* Project object */;\n"
    f"\t\t\tproxyType = 1;\n"
    f"\t\t\tremoteGlobalIDString = {NSE_TARGET};\n"
    f"\t\t\tremoteInfo = EmberMediaService;\n"
    f"\t\t}};\n",
)

# 3. PBXCopyFilesBuildPhase — Embed App Extensions
replace_once(
    "/* Begin PBXCopyFilesBuildPhase section */\n",
    "/* Begin PBXCopyFilesBuildPhase section */\n"
    f"\t\t{EMBED_PHASE} /* Embed App Extensions */ = {{\n"
    f"\t\t\tisa = PBXCopyFilesBuildPhase;\n"
    f"\t\t\tbuildActionMask = 2147483647;\n"
    f"\t\t\tdstPath = \"\";\n"
    f"\t\t\tdstSubfolderSpec = 13;\n"
    f"\t\t\tfiles = (\n"
    f"\t\t\t\t{NSE_APPEX_BUILD} /* EmberMediaService.appex in Embed App Extensions */,\n"
    f"\t\t\t);\n"
    f"\t\t\tname = \"Embed App Extensions\";\n"
    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    f"\t\t}};\n",
)

# 4. PBXFileReference entries
replace_once(
    "/* Begin PBXFileReference section */\n",
    "/* Begin PBXFileReference section */\n"
    f"\t\t{SCENE_REF} /* SceneDelegate.swift */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = SceneDelegate.swift; sourceTree = \"<group>\"; }};\n"
    f"\t\t{ENT_REF} /* Runner.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Runner.entitlements; sourceTree = \"<group>\"; }};\n"
    f"\t\t{GSI_REF} /* GoogleService-Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = \"GoogleService-Info.plist\"; sourceTree = \"<group>\"; }};\n"
    f"\t\t{NSE_APPEX_REF} /* EmberMediaService.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = EmberMediaService.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
    f"\t\t{NSE_SWIFT_REF} /* NotificationService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NotificationService.swift; sourceTree = \"<group>\"; }};\n"
    f"\t\t{NSE_PLIST_REF} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};\n",
)

# 5. PBXGroup — EmberMediaService group (inside PBXGroup section)
replace_once(
    "/* Begin PBXGroup section */\n",
    "/* Begin PBXGroup section */\n"
    f"\t\t{NSE_GROUP} /* EmberMediaService */ = {{\n"
    f"\t\t\tisa = PBXGroup;\n"
    f"\t\t\tchildren = (\n"
    f"\t\t\t\t{NSE_SWIFT_REF} /* NotificationService.swift */,\n"
    f"\t\t\t\t{NSE_PLIST_REF} /* Info.plist */,\n"
    f"\t\t\t);\n"
    f"\t\t\tpath = EmberMediaService;\n"
    f"\t\t\tsourceTree = \"<group>\";\n"
    f"\t\t}};\n",
)

# 5b. add NSE group to main group children (after Runner group)
replace_once(
    "\t\t\t\t97C146F01CF9000F007C117D /* Runner */,\n",
    "\t\t\t\t97C146F01CF9000F007C117D /* Runner */,\n"
    f"\t\t\t\t{NSE_GROUP} /* EmberMediaService */,\n",
)

# 5c. add SceneDelegate + entitlements + GoogleService to Runner group
replace_once(
    "\t\t\t\t74858FAD1ED2DC5600515810 /* Runner-Bridging-Header.h */,\n",
    "\t\t\t\t74858FAD1ED2DC5600515810 /* Runner-Bridging-Header.h */,\n"
    f"\t\t\t\t{SCENE_REF} /* SceneDelegate.swift */,\n"
    f"\t\t\t\t{ENT_REF} /* Runner.entitlements */,\n"
    f"\t\t\t\t{GSI_REF} /* GoogleService-Info.plist */,\n",
)

# 5d. add appex to Products group
replace_once(
    "\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n\t\t\t);\n\t\t\tname = Products;\n",
    f"\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n\t\t\t\t{NSE_APPEX_REF} /* EmberMediaService.appex */,\n\t\t\t);\n\t\t\tname = Products;\n",
)

# 6. NSE PBXNativeTarget
replace_once(
    "/* Begin PBXNativeTarget section */\n",
    "/* Begin PBXNativeTarget section */\n"
    f"\t\t{NSE_TARGET} /* EmberMediaService */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {NSE_CFG_LIST} /* Build configuration list for PBXNativeTarget \"EmberMediaService\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{NSE_SOURCES} /* Sources */,\n"
    f"\t\t\t\t{NSE_FRAMEWORKS} /* Frameworks */,\n"
    f"\t\t\t\t{NSE_RESOURCES} /* Resources */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n\t\t\t);\n"
    f"\t\t\tdependencies = (\n\t\t\t);\n"
    f"\t\t\tname = EmberMediaService;\n"
    f"\t\t\tproductName = EmberMediaService;\n"
    f"\t\t\tproductReference = {NSE_APPEX_REF} /* EmberMediaService.appex */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.app-extension\";\n"
    f"\t\t}};\n",
)

# 6b. Runner buildPhases: insert Embed App Extensions BEFORE Thin Binary
replace_once(
    "\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n",
    f"\t\t\t\t{EMBED_PHASE} /* Embed App Extensions */,\n"
    "\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n",
)

# 6c. Runner dependencies: add NSE dependency
replace_once(
    "\t\t\tdependencies = (\n\t\t\t);\n\t\t\tname = Runner;\n",
    f"\t\t\tdependencies = (\n\t\t\t\t{NSE_DEP} /* PBXTargetDependency */,\n\t\t\t);\n\t\t\tname = Runner;\n",
)

# 7. PBXProject targets + TargetAttributes
replace_once(
    "\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,\n\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n",
    "\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,\n"
    f"\t\t\t\t{NSE_TARGET} /* EmberMediaService */,\n"
    "\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n",
)
replace_once(
    "\t\t\t\t\t97C146ED1CF9000F007C117D = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n\t\t\t\t\t\tLastSwiftMigration = 1100;\n\t\t\t\t\t};\n",
    "\t\t\t\t\t97C146ED1CF9000F007C117D = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n\t\t\t\t\t\tLastSwiftMigration = 1100;\n\t\t\t\t\t};\n"
    f"\t\t\t\t\t{NSE_TARGET} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n\t\t\t\t\t}};\n",
)

# 8. NSE build phases (sources/frameworks/resources)
replace_once(
    "/* Begin PBXResourcesBuildPhase section */\n",
    "/* Begin PBXResourcesBuildPhase section */\n"
    f"\t\t{NSE_RESOURCES} /* Resources */ = {{\n"
    f"\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n",
)
replace_once(
    "/* Begin PBXSourcesBuildPhase section */\n",
    "/* Begin PBXSourcesBuildPhase section */\n"
    f"\t\t{NSE_SOURCES} /* Sources */ = {{\n"
    f"\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n"
    f"\t\t\t\t{NSE_SWIFT_BUILD} /* NotificationService.swift in Sources */,\n"
    f"\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n",
)
replace_once(
    "/* Begin PBXFrameworksBuildPhase section */\n",
    "/* Begin PBXFrameworksBuildPhase section */\n"
    f"\t\t{NSE_FRAMEWORKS} /* Frameworks */ = {{\n"
    f"\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n",
)

# 8b. add SceneDelegate.swift to Runner Sources phase
replace_once(
    "\t\t\t\t74858FAF1ED2DC5600515810 /* AppDelegate.swift in Sources */,\n",
    "\t\t\t\t74858FAF1ED2DC5600515810 /* AppDelegate.swift in Sources */,\n"
    f"\t\t\t\t{SCENE_BUILD} /* SceneDelegate.swift in Sources */,\n",
)
# 8c. add GoogleService-Info.plist to Runner Resources phase
replace_once(
    "\t\t\t\t97C146FC1CF9000F007C117D /* Main.storyboard in Resources */,\n",
    "\t\t\t\t97C146FC1CF9000F007C117D /* Main.storyboard in Resources */,\n"
    f"\t\t\t\t{GSI_BUILD} /* GoogleService-Info.plist in Resources */,\n",
)

# 9. PBXTargetDependency
replace_once(
    "/* Begin PBXTargetDependency section */\n",
    "/* Begin PBXTargetDependency section */\n"
    f"\t\t{NSE_DEP} /* PBXTargetDependency */ = {{\n"
    f"\t\t\tisa = PBXTargetDependency;\n"
    f"\t\t\ttarget = {NSE_TARGET} /* EmberMediaService */;\n"
    f"\t\t\ttargetProxy = {NSE_PROXY} /* PBXContainerItemProxy */;\n"
    f"\t\t}};\n",
)

# 10. NSE XCBuildConfiguration (Debug/Release/Profile)
def nse_cfg(cfg_id, name, debug):
    swift_opt = "\"-Onone\"" if debug else "\"-O\""
    cond = "\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;\n" if debug else ""
    return (
        f"\t\t{cfg_id} /* {name} */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbuildSettings = {{\n"
        f"\t\t\t\tCLANG_ENABLE_MODULES = YES;\n"
        f"\t\t\t\tCODE_SIGN_STYLE = Automatic;\n"
        f"\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n"
        f"\t\t\t\tDEVELOPMENT_TEAM = {TEAM};\n"
        f"\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n"
        f"\t\t\t\tINFOPLIST_FILE = EmberMediaService/Info.plist;\n"
        f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;\n"
        f"\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\n"
        f"\t\t\t\t\t\"$(inherited)\",\n"
        f"\t\t\t\t\t\"@executable_path/Frameworks\",\n"
        f"\t\t\t\t\t\"@executable_path/../../Frameworks\",\n"
        f"\t\t\t\t);\n"
        f"\t\t\t\tMARKETING_VERSION = 1.0;\n"
        f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {NSE_BUNDLE};\n"
        f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";\n"
        f"\t\t\t\tSKIP_INSTALL = YES;\n"
        f"{cond}"
        f"\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = {swift_opt};\n"
        f"\t\t\t\tSWIFT_VERSION = 5.0;\n"
        f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";\n"
        f"\t\t\t}};\n"
        f"\t\t\tname = {name};\n"
        f"\t\t}};\n"
    )

replace_once(
    "/* Begin XCBuildConfiguration section */\n",
    "/* Begin XCBuildConfiguration section */\n"
    + nse_cfg(NSE_CFG_DEBUG, "Debug", True)
    + nse_cfg(NSE_CFG_RELEASE, "Release", False)
    + nse_cfg(NSE_CFG_PROFILE, "Profile", False),
)

# 11. NSE XCConfigurationList
replace_once(
    "/* Begin XCConfigurationList section */\n",
    "/* Begin XCConfigurationList section */\n"
    f"\t\t{NSE_CFG_LIST} /* Build configuration list for PBXNativeTarget \"EmberMediaService\" */ = {{\n"
    f"\t\t\tisa = XCConfigurationList;\n"
    f"\t\t\tbuildConfigurations = (\n"
    f"\t\t\t\t{NSE_CFG_DEBUG} /* Debug */,\n"
    f"\t\t\t\t{NSE_CFG_RELEASE} /* Release */,\n"
    f"\t\t\t\t{NSE_CFG_PROFILE} /* Profile */,\n"
    f"\t\t\t);\n"
    f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
    f"\t\t\tdefaultConfigurationName = Release;\n"
    f"\t\t}};\n",
)

# 12. Runner configs: CODE_SIGN_ENTITLEMENTS (+ DEVELOPMENT_TEAM on Release/Profile)
# Debug (already has DEVELOPMENT_TEAM)
replace_once(
    "\t\t97C147061CF9000F007C117D /* Debug */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbaseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;\n\t\t\tbuildSettings = {\n",
    "\t\t97C147061CF9000F007C117D /* Debug */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbaseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;\n\t\t\tbuildSettings = {\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n",
)
# Release
replace_once(
    "\t\t97C147071CF9000F007C117D /* Release */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbaseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;\n\t\t\tbuildSettings = {\n",
    "\t\t97C147071CF9000F007C117D /* Release */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbaseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;\n\t\t\tbuildSettings = {\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n\t\t\t\tDEVELOPMENT_TEAM = " + TEAM + ";\n",
)
# Profile
replace_once(
    "\t\t249021D4217E4FDB00AE95B9 /* Profile */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbaseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;\n\t\t\tbuildSettings = {\n",
    "\t\t249021D4217E4FDB00AE95B9 /* Profile */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbaseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;\n\t\t\tbuildSettings = {\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n\t\t\t\tDEVELOPMENT_TEAM = " + TEAM + ";\n",
)

# 13. deployment target 13.0 -> 15.0 (project-level Debug/Release/Profile)
assert txt.count("IPHONEOS_DEPLOYMENT_TARGET = 13.0;") == 3, "expected 3 deployment targets"
txt = txt.replace("IPHONEOS_DEPLOYMENT_TARGET = 13.0;", "IPHONEOS_DEPLOYMENT_TARGET = 15.0;")

assert txt != orig, "no changes made"
assert txt[:1] != "\ufeff"

with open(PBX, "wb") as f:
    f.write(txt.encode("utf-8"))

print("PATCH OK")
print("NSE_TARGET", NSE_TARGET)
