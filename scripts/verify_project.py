#!/usr/bin/env python3
"""
달빛 잼 항아리 프로젝트 검증 스크립트.

이 리눅스 환경에서는 로컬 Swift 툴체인으로 단위 테스트를 실제로 돌린다.
    sh /workspace/.tools/swiftrun.sh test --package-path Packages/AcornForestCore
이 스크립트는 그 위에 두 층을 더 얹는다.

1) 정적 검사
   - 모든 Swift 파일의 괄호/문자열 균형, import 규칙(Core는 SwiftUI 금지)
   - 타입 선언 중복, 알 수 없는 타입 참조
   - project.yml(YAML)과 실제 파일 트리 일치, Info.plist 핵심 키
   - 테스트 케이스 수, README 필수 항목
2) 규칙 미러링
   - Swift 소스에서 상수(호감도 문턱, 요리 온도/품질 비율, 채집 점수/보너스, 챕터 해금 조건)를
     정규식으로 직접 읽어 파이썬으로 같은 계산을 수행한다.
   - 상수를 코드에서 읽으므로, Swift 쪽 숫자가 바뀌면 이 검증이 즉시 깨진다.
   - 대본(장면/대사/선택지/깃발/보상)도 파싱해 id 중복·일기장 참조·챕터 누락을 확인한다.

실행: python3 scripts/verify_project.py
"""

from __future__ import annotations

import json
import math
import re
import struct
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

ROOT = Path(__file__).resolve().parents[1]
CORE_DIR = ROOT / "Packages/AcornForestCore/Sources/AcornForestCore"
CORE_TEST_DIR = ROOT / "Packages/AcornForestCore/Tests/AcornForestCoreTests"
APP_DIR = ROOT / "App"
APP_TEST_DIR = ROOT / "Tests"

results: list[tuple[str, bool, str]] = []


def check(name: str, ok: bool, detail: str = "") -> bool:
    results.append((name, bool(ok), detail))
    return bool(ok)


def fail(name: str, detail: str) -> None:
    check(name, False, detail)


# ---------------------------------------------------------------------------
# Swift 소스 읽기
# ---------------------------------------------------------------------------

def swift_files(folder: Path) -> list[Path]:
    if not folder.exists():
        return []
    return sorted(folder.rglob("*.swift"))


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class SwiftSyntaxError(Exception):
    pass


def strip_strings_and_comments(source: str) -> str:
    """문자열/주석을 지운 소스를 만든다(괄호 균형 검사용). 문자열 안의 괄호는 무시된다."""
    out: list[str] = []
    i, n = 0, len(source)
    while i < n:
        ch = source[i]
        nxt = source[i + 1] if i + 1 < n else ""
        if ch == "/" and nxt == "/":
            while i < n and source[i] != "\n":
                i += 1
        elif ch == "/" and nxt == "*":
            depth = 1
            i += 2
            while i < n and depth:
                if source.startswith("/*", i):
                    depth += 1
                    i += 2
                elif source.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            if depth:
                raise SwiftSyntaxError("닫히지 않은 블록 주석")
        elif source.startswith('"""', i):
            end = source.find('"""', i + 3)
            if end < 0:
                raise SwiftSyntaxError("닫히지 않은 여러 줄 문자열")
            out.append('""')
            i = end + 3
        elif ch == '"':
            i += 1
            closed = False
            while i < n:
                if source[i] == "\\":
                    i += 2
                    continue
                if source[i] == '"':
                    i += 1
                    closed = True
                    break
                if source[i] == "\n":
                    break
                i += 1
            if not closed:
                raise SwiftSyntaxError("닫히지 않은 문자열 리터럴")
            out.append('""')
        else:
            out.append(ch)
            i += 1
    return "".join(out)


PAIRS = {"(": ")", "[": "]", "{": "}"}


def check_balanced(stripped: str, label: str) -> None:
    stack: list[tuple[str, int]] = []
    line = 1
    for ch in stripped:
        if ch == "\n":
            line += 1
        elif ch in PAIRS:
            stack.append((ch, line))
        elif ch in PAIRS.values():
            if not stack:
                raise SwiftSyntaxError(f"{label}: {line}행에서 여분의 '{ch}'")
            opener, opened_at = stack.pop()
            if PAIRS[opener] != ch:
                raise SwiftSyntaxError(f"{label}: {opened_at}행 '{opener}'와 {line}행 '{ch}' 불일치")
    if stack:
        opener, opened_at = stack[-1]
        raise SwiftSyntaxError(f"{label}: {opened_at}행 '{opener}'가 닫히지 않음")


TYPE_DECL = re.compile(r"\b(struct|enum|class|protocol|actor)\s+([A-Z][A-Za-z0-9_]*)")
EXTENSION_TARGET = re.compile(r"\bextension\s+([A-Z][A-Za-z0-9_]*)")
IMPORT_LINE = re.compile(r"^\s*(?:@testable\s+)?import\s+([A-Za-z_][A-Za-z0-9_]*)")


def declared_types(sources: dict[Path, str]) -> dict[str, list[str]]:
    found: dict[str, list[str]] = {}
    for path, source in sources.items():
        stripped = strip_strings_and_comments(source)
        for _, name in TYPE_DECL.findall(stripped):
            found.setdefault(name, []).append(str(path.relative_to(ROOT)))
    return found


# Swift 표준/프레임워크 타입. 프로젝트 타입이 아닌 식별자를 걸러내기 위한 목록.
SWIFT_BUILTINS = set(
    """
    String Int Double Float Bool Character Array Set Dictionary Optional Result Error Void Never Any AnyObject
    Self Type Data Date UUID URL Calendar Locale TimeInterval CGFloat CGPoint CGSize CGRect CGVector CGAffineTransform
    Angle UnitPoint Edge EdgeInsets Animation Gradient Path Canvas GraphicsContext StrokeStyle RoundedCornerStyle
    Color Image Text Font View Shape ViewModifier ButtonStyle Configuration Button ButtonRole Label Link Spacer Divider
    Group VStack HStack ZStack Section ScrollView LazyVStack LazyVGrid GridItem GeometryReader GeometryProxy
    TimelineView TimelineSchedule ProgressView NavigationStack NavigationLink ToolbarItem ToolbarItemPlacement
    Environment EnvironmentObject StateObject State Binding Published ObservableObject MainActor Task Duration
    ContinuousClock RandomNumberGenerator Hashable Equatable Codable Identifiable Sendable Comparable CaseIterable
    UInt UInt64 UInt32 Int8 Int16 Int32 Int64 Double UInt8 UInt16 XCTestCase XCTest
    LocalizedStringKey StringProtocol ViewBuilder Namespace EmptyView TupleView AnyView AnyShape InsettableShape
    PreviewProvider App Scene WindowGroup ColorScheme ContentMode FontDesign FontWeight FontTextStyle
    Capsule Circle Rectangle RoundedRectangle Ellipse LinearGradient RadialGradient AngularGradient
    ClosedRange Range Content Foundation SwiftUI UIKit JSONEncoder JSONDecoder DateEncodingStrategy ForEach
    UserDefaults Weight AcornForestCore LittleAcornForest
    AVFoundation AudioToolbox StoreKit Combine AVFAudio AVAudioEngine AVAudioPlayerNode AVAudioPCMBuffer AVAudioFormat
    AVAudioSession AVAudioTime AVNode AudioBufferList OSStatus AVAudioFrameCount AVAudioFramePosition
    Product Transaction VerificationResult AppStore ProductPurchaseResult PurchaseResult ProductID
    Published EnvironmentObject StateObject ObservedObject ObservableObject
    CodingKey Decoder Encoder DateDecodingStrategy DateEncodingStrategy ISO8601DateFormatter
    JSONSerialization NumberFormatter TextField Toggle Stepper Picker DatePicker SecureField
    Animation LinearGradient RadialGradient Canvas TimelineView TimelineSchedule
    Hashable String String
    """.split()
)

STDLIB_MEMBERS = set(
    """
    map flatMap compactMap filter reduce first last count isEmpty contains allSatisfy forEach sorted sortedBy
    append appendContentsOf remove removeAll removeFirst insert indices prefix suffix enumerated zip joined
    split dropFirst dropLast index offset min max abs round rounded floor ceil sin cos tan sqrt pow
    description debugDescription hashValue rawValue id self Self super init deinit get set newValue oldValue
    wrappedValue projectedValue body makeBody numberOfLines lineLimit tracking lineSpacing multilineTextAlignment
    fixedSize frame padding background overlay foregroundStyle foregroundColor tint opacity shadow cornerRadius
    clipShape fill stroke strokeBorder offset position scaleEffect rotationEffect animation transition zIndex
    onTapGesture onAppear onDisappear onChange task disabled alert sheet toolbar navigationTitle
    navigationBarTitleDisplayMode presentationDetents environmentObject buttonStyle labelStyle textCase
    Content Configuration Bundle standard set data object forKey removeObject key value
    attach connect mainMixerNode isRunning scheduleBuffer volume outputVolume frameLength frameCapacity
    floatChannelData setCategory setActive shared play stop start pause load displayPrice price
    now timeIntervalSinceReferenceDate timeIntervalSince1970 addingTimeInterval sleep seconds milliseconds
    nanoseconds isCancelled cancel wait async
    """.split()
)


# ---------------------------------------------------------------------------
# 1) 정적 검사
# ---------------------------------------------------------------------------

core_files = swift_files(CORE_DIR)
app_files = swift_files(APP_DIR)
app_test_files = swift_files(APP_TEST_DIR)
core_test_files = swift_files(CORE_TEST_DIR)
all_swift = core_files + app_files + core_test_files + app_test_files

sources: dict[Path, str] = {}
parse_errors: list[str] = []
for path in all_swift:
    text = read(path)
    sources[path] = text
    try:
        check_balanced(strip_strings_and_comments(text), str(path.relative_to(ROOT)))
    except SwiftSyntaxError as exc:
        parse_errors.append(str(exc))

check("모든 Swift 파일의 괄호/문자열 균형", not parse_errors, "; ".join(parse_errors[:5]))

imports_by_file: dict[Path, list[str]] = {}
for path, text in sources.items():
    modules = []
    for line in text.splitlines():
        match = IMPORT_LINE.match(line)
        if match:
            modules.append(match.group(1))
    imports_by_file[path] = modules

core_bad_imports = [
    f"{p.relative_to(ROOT)}: {m}"
    for p, mods in imports_by_file.items()
    if p in core_files
    for m in mods
    if m not in {"Foundation"}
]
check("Core 패키지는 Foundation만 import", not core_bad_imports, ", ".join(core_bad_imports))

app_bad_imports = [
    f"{p.relative_to(ROOT)}: {m}"
    for p, mods in imports_by_file.items()
    if p in app_files
    for m in mods
    if m not in {"SwiftUI", "UIKit", "Foundation", "AcornForestCore",
                 "AVFoundation", "AudioToolbox", "StoreKit", "Combine"}
]
check("앱 타깃 import 허용 범위", not app_bad_imports, ", ".join(app_bad_imports))

types = declared_types(sources)
duplicate_types = {name: paths for name, paths in types.items() if len(paths) > 1}
check("타입 이름 중복 없음", not duplicate_types,
      ", ".join(f"{n}: {p}" for n, p in list(duplicate_types.items())[:6]))

check("Core 소스가 12개 이상", len(core_files) >= 12, f"{len(core_files)}개")
check("앱 Swift 파일이 8개 이상", len(app_files) >= 8, f"{len(app_files)}개")

# 알 수 없는 타입 참조
known = set(types) | SWIFT_BUILTINS
used_pattern = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\b")
unknown: dict[str, set[str]] = {}
for path, text in sources.items():
    stripped = strip_strings_and_comments(text)
    for name in used_pattern.findall(stripped):
        if name in known:
            continue
        unknown.setdefault(name, set()).add(str(path.relative_to(ROOT)))
# swift-testing / XCTest 매크로와 한 글자 제네릭은 제외
ignored_prefixes = ("XCTAssert", "XCT", "UI", "NS")
unknown = {
    name: paths for name, paths in unknown.items()
    if not name.startswith(ignored_prefixes)
}
check("알 수 없는 타입 참조 없음", not unknown,
      "; ".join(f"{n} ({', '.join(sorted(p)[:2])})" for n, p in sorted(unknown.items())[:12]))

# Core public API가 참조하는 멤버 존재 확인(engine./state. 등)
member_decl = re.compile(
    r"\b(?:var|let|func|case|static\s+var|static\s+let|static\s+func|public\s+var|public\s+let|public\s+func)\s+([a-zA-Z_][A-Za-z0-9_]*)"
)
core_members = set(member_decl.findall("".join(strip_strings_and_comments(read(p)) for p in core_files)))
app_members = set(member_decl.findall("".join(strip_strings_and_comments(read(p)) for p in app_files + app_test_files)))
usable_members = core_members | app_members | STDLIB_MEMBERS

receivers = ["engine", "state", "session", "cooking", "record", "recipe", "summary", "outcome",
             "affinity", "quality", "level", "character", "ingredient", "stack", "chapter", "beat",
             "choice", "gift", "completion", "settings"]
missing_members: list[str] = []
for path in app_files + app_test_files:
    stripped = strip_strings_and_comments(read(path))
    for receiver in receivers:
        for name in re.findall(rf"\b{receiver}\.([a-zA-Z_][A-Za-z0-9_]*)", stripped):
            if name not in usable_members:
                missing_members.append(f"{path.relative_to(ROOT)}: {receiver}.{name}")
check("앱에서 참조하는 멤버가 Core에 존재", not missing_members, "; ".join(missing_members[:8]))


# ---------------------------------------------------------------------------
# 2) project.yml / 파일 트리
# ---------------------------------------------------------------------------

project_path = ROOT / "project.yml"
if yaml is None:
    fail("project.yml 파싱", "PyYAML 없음")
else:
    try:
        project = yaml.safe_load(read(project_path))
        check("project.yml 파싱", isinstance(project, dict))
    except Exception as exc:  # noqa: BLE001
        project = None
        fail("project.yml 파싱", str(exc))

if isinstance(project, dict):
    targets = project.get("targets", {})
    check("project.yml에 앱/테스트 타깃", "LittleAcornForest" in targets and "LittleAcornForestTests" in targets)
    app_target = targets.get("LittleAcornForest", {})
    test_target = targets.get("LittleAcornForestTests", {})
    bundle = app_target.get("settings", {}).get("base", {}).get("PRODUCT_BUNDLE_IDENTIFIER")
    check("Bundle ID 고정", bundle == "com.quoguri.moonlightjamjar.app", str(bundle))
    deployment = project.get("options", {}).get("deploymentTarget", {}).get("iOS")
    check("iOS 17.0 배포 타깃", str(deployment) == "17.0", str(deployment))
    swift_version = project.get("settings", {}).get("base", {}).get("SWIFT_VERSION")
    check("Swift 5.9", str(swift_version) == "5.9", str(swift_version))
    check("패키지 경로 존재", (ROOT / "Packages/AcornForestCore").exists())

    source_paths = [s.get("path") for s in app_target.get("sources", []) if isinstance(s, dict)]
    check("앱 소스 경로 = App", source_paths == ["App"], str(source_paths))
    test_paths = [s.get("path") for s in test_target.get("sources", []) if isinstance(s, dict)]
    check("테스트 소스 경로 = Tests", test_paths == ["Tests"], str(test_paths))
    check("앱 테스트 파일 존재", len(app_test_files) >= 1, f"{len(app_test_files)}개")

    compiler_settings = app_target.get("settings", {}).get("base", {})
    check("앱 아이콘 컴파일러 설정",
          compiler_settings.get("ASSETCATALOG_COMPILER_APPICON_NAME") == "AppIcon",
          str(compiler_settings.get("ASSETCATALOG_COMPILER_APPICON_NAME")))

    info_props = app_target.get("info", {}).get("properties", {})
    orientations = info_props.get("UISupportedInterfaceOrientations", [])
    check("세로 고정 레이아웃", orientations == ["UIInterfaceOrientationPortrait"], str(orientations))
    check("앱 표시 이름", info_props.get("CFBundleDisplayName") == "달빛 잼 항아리",
          str(info_props.get("CFBundleDisplayName")))

    package_file = ROOT / "Packages/AcornForestCore/Package.swift"
    package_text = read(package_file)
    check("Core 패키지 이름", 'name: "AcornForestCore"' in package_text)
    check("Core 테스트 타깃", "AcornForestCoreTests" in package_text)
    check("Core 테스트 소스 경로", "Tests/AcornForestCoreTests" in package_text)

# ---------------------------------------------------------------------------
# 2b) 앱 아이콘 (Assets.xcassets / AppIcon.appiconset)
# ---------------------------------------------------------------------------

asset_root = APP_DIR / "Assets.xcassets"
icon_set = asset_root / "AppIcon.appiconset"
icon_catalog_path = icon_set / "Contents.json"

check("Assets.xcassets 존재", (asset_root / "Contents.json").exists(), str(asset_root.relative_to(ROOT)))
check("AppIcon.appiconset 존재", icon_set.is_dir(), str(icon_set.relative_to(ROOT)))

icon_entry: dict = {}
if icon_catalog_path.exists():
    try:
        icon_catalog = json.loads(read(icon_catalog_path))
        check("AppIcon Contents.json 파싱", isinstance(icon_catalog, dict))
    except json.JSONDecodeError as exc:
        icon_catalog = {}
        fail("AppIcon Contents.json 파싱", str(exc))
    icon_images = icon_catalog.get("images", []) if isinstance(icon_catalog, dict) else []
    check("AppIcon 1024 단일 슬롯", len(icon_images) == 1
          and icon_images[0].get("size") == "1024x1024"
          and icon_images[0].get("idiom") == "universal", str(icon_images))
    icon_entry = icon_images[0] if icon_images else {}
    check("AppIcon 슬롯 platform = ios", icon_entry.get("platform") == "ios",
          str(icon_entry.get("platform")))
    icon_info = icon_catalog.get("info", {}) if isinstance(icon_catalog, dict) else {}
    check("AppIcon info.author = xcode", icon_info.get("author") == "xcode", str(icon_info))
else:
    fail("AppIcon Contents.json 존재", str(icon_catalog_path.relative_to(ROOT)))

icon_png = icon_set / icon_entry["filename"] if icon_entry.get("filename") else None
check("AppIcon 파일 이름 지정", icon_png is not None, str(icon_entry))
if icon_png is not None and icon_png.exists():
    icon_bytes = icon_png.read_bytes()
    check("AppIcon PNG 시그니처", icon_bytes[:8] == b"\x89PNG\r\n\x1a\n")
    icon_width, icon_height = struct.unpack(">II", icon_bytes[16:24])
    icon_depth, icon_color = icon_bytes[24], icon_bytes[25]
    check("AppIcon 1024x1024", icon_width == 1024 and icon_height == 1024,
          f"{icon_width}x{icon_height}")
    check("AppIcon 8비트 RGB(알파 없음)", icon_depth == 8 and icon_color == 2,
          f"depth={icon_depth} colorType={icon_color}")
    check("AppIcon tRNS 투명도 없음", b"tRNS" not in icon_bytes)
else:
    icon_bytes = b""
    fail("AppIcon 파일 존재", str(icon_png))

readme_icon = ROOT / "docs/images/app-icon.png"
check("docs/images/app-icon.png 존재", readme_icon.exists())
if readme_icon.exists() and icon_bytes:
    check("docs 아이콘이 AppIcon과 동일한 파일", readme_icon.read_bytes() == icon_bytes)

check("LICENSE 파일 없음", not (ROOT / "LICENSE").exists())
check(".gitignore 존재", (ROOT / ".gitignore").exists())
check("README 존재", (ROOT / "README.md").exists())


# ---------------------------------------------------------------------------
# 3) 테스트 케이스 집계
# ---------------------------------------------------------------------------

test_functions = []
for path in core_test_files + app_test_files:
    test_functions.extend(re.findall(r"func\s+(test\w+)\s*\(", read(path)))
check("테스트 케이스 15개 이상", len(test_functions) >= 15, f"{len(test_functions)}개")
check("테스트 이름 중복 없음", len(test_functions) == len(set(test_functions)),
      str([n for n in set(test_functions) if test_functions.count(n) > 1]))

for path in core_test_files:
    if "import AcornForestCore" not in read(path):
        fail("Core 테스트 import", str(path.relative_to(ROOT)))


# ---------------------------------------------------------------------------
# 4) Swift 소스에서 상수/데이터 파싱
# ---------------------------------------------------------------------------

def grab(pattern: str, text: str, name: str, flags=re.S) -> str:
    match = re.search(pattern, text, flags)
    if not match:
        fail(f"상수 파싱: {name}", pattern)
        return ""
    return match.group(1)


story_text = read(CORE_DIR / "Story/StoryScript.swift")
recipe_text = read(CORE_DIR / "Models/Recipe.swift")
cooking_text = read(CORE_DIR / "Cooking/CookingSession.swift")
gathering_text = read(CORE_DIR / "Gathering/GatheringSession.swift")
affinity_text = read(CORE_DIR / "Models/ForestCharacter.swift")
chapter_text = read(CORE_DIR / "Progress/ChapterRules.swift")
diary_text = read(CORE_DIR / "Diary/ForestDiary.swift")
chapter_enum_text = read(CORE_DIR / "Models/StoryChapter.swift")

chapters = re.findall(r"^\s{4}case (\w+)$", chapter_enum_text, flags=re.M)
chapters = [c for c in chapters if c not in {"locked", "available", "inProgress", "completed"}]
check("챕터 5개(프롤로그~에필로그)", chapters == ["prologue", "chapterOne", "chapterTwo", "chapterThree", "epilogue"], str(chapters))

character_cases = re.findall(r"^\s{4}case (\w+)$", read(CORE_DIR / "Models/ForestCharacter.swift"), flags=re.M)
characters = [c for c in character_cases if c in {"tori", "songi", "mong", "rubi"}]
check("본편 이웃 4명", len(characters) == 4, str(characters))
CharacterID_CORE = ["tori", "songi", "mong", "rubi"]
CharacterID_EXPANSION = [c for c in character_cases if c in {"luna", "coco"}]
check("온실 이웃 2명(루나·코코)", CharacterID_EXPANSION == ["luna", "coco"], str(character_cases))
all_characters = characters + CharacterID_EXPANSION

# 레시피 (본편 + 사계절 온실 + 비밀 쪽지)
greenhouse_text = read(CORE_DIR / "Greenhouse/GreenhouseRecipes.swift")
secret_text = read(CORE_DIR / "Mailbox/SecretRecipeBook.swift")


def parse_recipes(text: str):
    blocks = re.findall(
        r"Recipe\(\s*id: \"([^\"]+)\",\s*name: \"([^\"]+)\",\s*ingredients: \[([^\]]*)\]",
        text, flags=re.S)
    parsed = {}
    for rid, name, ingredients in blocks:
        items = re.findall(r"\.(\w+)", ingredients)
        parsed[rid] = (name, tuple(sorted(items)))
    return blocks, parsed


base_blocks, base_recipes = parse_recipes(recipe_text)
green_blocks, green_recipes = parse_recipes(greenhouse_text)
secret_blocks, secret_recipes = parse_recipes(secret_text)
recipe_blocks = base_blocks + green_blocks + secret_blocks
recipes = {**base_recipes, **green_recipes, **secret_recipes}
INGREDIENTS = {"dewberry", "fireflyNectar", "starMossShroom", "moonflakeSpice",
               "moonlitDew", "cherryHoney", "mapleSap", "snowBlossom"}
SIGNATURE_JAM = "golden-fullmoon-jam"

check("본편 레시피 7종", len(base_recipes) == 7, f"{len(base_recipes)}종")
check("온실 레시피 3종", len(green_recipes) == 3, f"{len(green_recipes)}종")
check("비밀 레시피 2종", len(secret_recipes) == 2, f"{len(secret_recipes)}종")
check("전체 레시피 12종", len(recipes) == 12, f"{len(recipes)}종")
check("레시피 id 중복 없음", len(recipe_blocks) == len(recipes))
check("모든 레시피 2~3가지 재료", all(2 <= len(v[1]) <= 3 for v in recipes.values()),
      str({k: v[1] for k, v in recipes.items()}))
combos = [v[1] for v in recipes.values()]
check("조합 중복 없음", len(combos) == len(set(combos)), str(combos))
check("모든 레시피 재료가 실제 재료", all(
    set(v[1]) <= INGREDIENTS for v in recipes.values()),
      str({k: v[1] for k, v in recipes.items() if not set(v[1]) <= INGREDIENTS}))
check("축제 시그니처 잼 존재", SIGNATURE_JAM in recipes)

min_chapters = re.findall(r"minChapter: \.(\w+)", recipe_text + greenhouse_text + secret_text)
check("레시피 등장 장이 유효", bool(min_chapters) and set(min_chapters) <= set(chapters), str(set(min_chapters)))

# 이웃의 최애/호불호 레시피가 실제 레시피를 가리키는지
character_text = read(CORE_DIR / "Models/ForestCharacter.swift")

def switch_block(prop: str) -> str:
    match = re.search(prop + r".*?\{\s*switch self \{(.*?)\n    \}", character_text, flags=re.S)
    return match.group(1) if match else ""

favorite_map = dict(re.findall(r"case \.(\w+): return \"([^\"]+)\"", switch_block(r"var favoriteRecipeID: String")))
liked_map = {c: re.findall(r'"([^"]+)"', v) for c, v in
             re.findall(r"case \.(\w+): return \[([^\]]*)\]", switch_block(r"var likedRecipeIDs: \[String\]"))}
disliked_map = {c: re.findall(r'"([^"]+)"', v) for c, v in
                re.findall(r"case \.(\w+): return \[([^\]]*)\]", switch_block(r"var dislikedRecipeIDs: \[String\]"))}
wish_block = switch_block(r"var wish: String")

check("이웃 6명 최애 요리 지정", set(favorite_map) == set(all_characters), str(favorite_map))
check("최애 요리가 실제 레시피", all(v in recipes for v in favorite_map.values()), str(favorite_map))
check("최애 요리가 겹치지 않음", len(set(favorite_map.values())) == len(favorite_map), str(favorite_map))
check("좋아하는/싫어하는 요리가 실제 레시피",
      all(v in recipes for values in liked_map.values() for v in values)
      and all(v in recipes for values in disliked_map.values() for v in values),
      f"{liked_map} / {disliked_map}")
check("호불호가 최애와 겹치지 않음",
      all(favorite_map[c] not in liked_map.get(c, []) + disliked_map.get(c, []) for c in all_characters),
      str(favorite_map))
check("이웃 모두 소원 문장 있음", len(re.findall(r"return \"[^\"]+\"", wish_block)) >= len(all_characters), wish_block[:80])

# 대본
scene_blocks = re.split(r"(?=StoryScene\()", story_text)[1:]
scenes = []
for block in scene_blocks:
    sid = re.search(r"StoryScene\(\s*id: \"([^\"]+)\"", block)
    if not sid:
        continue
    scenes.append({
        "id": sid.group(1),
        "chapter": re.search(r"chapter: \.(\w+)", block).group(1),
        "lines": re.findall(r"StoryLine\(id: \"([^\"]+)\"", block),
        "choices": re.findall(r"StoryChoice\(\s*id: \"([^\"]+)\"", block, flags=re.S),
        "flags": re.findall(r"flag: \"([^\"]+)\"", block),
        "diary": re.findall(r"\"([a-zA-Z]+\.[A-Za-z0-9.\-]+)\"", block),
        "grants": re.findall(r"ItemStack\(\.(\w+), (-?\d+)\)", block),
        "text": block,
    })

check("장면 8개 이상", len(scenes) >= 8, f"{len(scenes)}개")
check("장면 id 중복 없음", len({s["id"] for s in scenes}) == len(scenes))

all_lines = [line for s in scenes for line in s["lines"]]
check("대사 id 중복 없음", len(set(all_lines)) == len(all_lines), f"{len(all_lines)}줄")

all_choices = [c for s in scenes for c in s["choices"]]
check("선택지 id 중복 없음", len(set(all_choices)) == len(all_choices), f"{len(all_choices)}개")

choice_replies = re.findall(r"reply: StoryLine\(", story_text)
check("모든 선택지에 응답 대사", len(choice_replies) == len(all_choices),
      f"선택지 {len(all_choices)} / 응답 {len(choice_replies)}")

choice_gains = re.findall(r"AffinityGain\(\.(\w+), (\d+)\)", story_text)
bad_gains = [(c, v) for c, v in choice_gains if c not in characters or int(v) <= 0]
check("선택지 호감도 대상이 실제 이웃", not bad_gains, str(bad_gains))
check("선택지마다 호감도 효과", len(choice_gains) >= len(all_choices), f"{len(choice_gains)}개")

all_flags = [f for s in scenes for f in s["flags"]]
check("선택지 깃발 중복 없음", len(set(all_flags)) == len(all_flags), str(all_flags))

scene_chapters = {s["chapter"] for s in scenes}
check("모든 챕터에 장면 존재", scene_chapters == set(chapters), str(scene_chapters))

short_scenes = [s["id"] for s in scenes if len(s["lines"]) < 4]
check("모든 장면 4줄 이상", not short_scenes, str(short_scenes))

too_many_choices = [s["id"] for s in scenes if len(s["choices"]) > 4]
check("장면당 선택지 4개 이하", not too_many_choices, str(too_many_choices))

bad_grants = [(s["id"], ing, n) for s in scenes for ing, n in s["grants"]
              if ing not in INGREDIENTS or int(n) <= 0]
check("장면 보상이 실제 재료/양수", not bad_grants, str(bad_grants))

# 일기장 참조 확인
diary_ids = set(re.findall(r"id: \"([a-zA-Z]+\.[A-Za-z0-9.\-]+)\"", diary_text))
scene_diary_refs = re.findall(r"unlocksDiary: \[([^\]]*)\]", story_text, flags=re.S)
referenced_diary = [d for block in scene_diary_refs for d in re.findall(r"\"([^\"]+)\"", block)]
known_diary = (
    {f"recipe.{rid}" for rid in recipes}
    | {f"memory.{c}.{tier}" for c in characters for tier in (1, 2)}
    | {f"chapter.{c}" for c in chapters}
    | {"festival.starlight"}
)
bad_diary_refs = [d for d in referenced_diary if d not in known_diary]
check("대본의 일기장 참조가 실제 항목", not bad_diary_refs, str(bad_diary_refs))
# 일기장 구성 확인(항목 id는 코드에서 조립된다)
diary_builders = ["recipeEntryID", "memoryEntryID", "chapterEntryID", "festivalEntryID",
                  "for recipe in RecipeBook.base", "for character in CharacterID.coreNeighbours",
                  "for chapter in StoryChapter.ordered",
                  "GreenhouseRecipes.all", "SecretRecipeBook.all", "expandedEntries"]
check("일기장 생성 규칙 확인", all(token in diary_text for token in diary_builders),
      str([t for t in diary_builders if t not in diary_text]))


# ---------------------------------------------------------------------------
# 5) 규칙 미러링 — Swift 상수를 읽어 파이썬으로 같은 계산
# ---------------------------------------------------------------------------

def grab_float(pattern: str, name: str) -> float:
    raw = grab(pattern, cooking_text, name)
    return float(raw) if raw else float("nan")


cook_duration = grab_float(r"static let duration: Double = ([\d.]+)", "duration")
band_low = grab_float(r"static let idealBand: ClosedRange<Double> = ([\d.]+)\.\.\.", "idealBand.low")
band_high = grab_float(r"static let idealBand: ClosedRange<Double> = [\d.]+\.\.\.([\d.]+)", "idealBand.high")
heat_rate = grab_float(r"static let heatPerSecond: Double = ([\d.]+)", "heatPerSecond")
stir_cooling = grab_float(r"static let stirCooling: Double = ([\d.]+)", "stirCooling")
burn_threshold = grab_float(r"static let burnThreshold: Double = ([\d.]+)", "burnThreshold")
perfect_ratio = grab_float(r"if ratio >= ([\d.]+) \{ return \.perfect \}", "perfectRatio")
good_ratio = grab_float(r"if ratio >= ([\d.]+) \{ return \.good \}", "goodRatio")
gift_bonus = float(grab(r"case \.perfect: return (\d+)", cooking_text, "perfectGiftBonus") or 0)

check("요리 상수 파싱", all(not math.isnan(x) for x in
      [cook_duration, band_low, band_high, heat_rate, stir_cooling, burn_threshold, perfect_ratio, good_ratio]))
check("이상 구간이 0~1 안", 0 < band_low < band_high <= 1, f"{band_low}~{band_high}")


def cook(strategy: str, dt: float = 0.1) -> tuple[str, float, bool, int]:
    heat, elapsed, in_band, burned, stirs = 0.30, 0.0, 0.0, False, 0
    while elapsed < cook_duration - 1e-9:
        step = min(dt, cook_duration - elapsed)
        elapsed += step
        heat = min(1.0, heat + heat_rate * step)
        if band_low <= heat <= band_high:
            in_band += step
        if heat >= burn_threshold:
            burned = True
        if strategy == "hold" and heat > 0.62:
            heat = max(0.05, heat - stir_cooling)
            stirs += 1
    ratio = in_band / elapsed if elapsed else 0
    if burned:
        quality = "burnt"
    elif ratio >= perfect_ratio:
        quality = "perfect"
    elif ratio >= good_ratio:
        quality = "good"
    else:
        quality = "burnt"
    return quality, ratio, burned, stirs


hold_quality, hold_ratio, _, hold_stirs = cook("hold")
idle_quality, idle_ratio, idle_burned, _ = cook("idle")
check("불을 잡으면 완벽한 요리", hold_quality == "perfect", f"ratio={hold_ratio:.3f}")
check("젓지 않으면 탄 요리", idle_quality == "burnt" and idle_burned, f"ratio={idle_ratio:.3f}")
check("젓기 횟수 발생", hold_stirs > 0, str(hold_stirs))

# 호감도
affinity_enum = read(CORE_DIR / "Models/ForestCharacter.swift")
levels = {name: int(value) for name, value in
          re.findall(r"case (shy|greeting|close|family) = (\d+)", affinity_enum)}
check("호감도 단계 파싱", levels == {"shy": 0, "greeting": 20, "close": 45, "family": 70}, str(levels))
max_affinity = int(grab(r"public static let maximum = (\d+)", affinity_enum, "maximum"))
favorite_points = int(grab(r"if recipe\.id == character\.favoriteRecipeID \{ return (\d+) \}", affinity_enum, "favorite"))
liked_points = int(grab(r"if character\.likedRecipeIDs\.contains\(recipe\.id\) \{ return (\d+) \}", affinity_enum, "liked"))
disliked_points = int(grab(r"if character\.dislikedRecipeIDs\.contains\(recipe\.id\) \{ return (\d+) \}", affinity_enum, "disliked"))
neutral_points = int(grab(r"return (\d+)\n    \}", affinity_enum.split("dislikedRecipeIDs.contains")[-1], "neutral") or 0)

check("선물 점수 순서", favorite_points > liked_points > neutral_points > disliked_points,
      f"{favorite_points}/{liked_points}/{neutral_points}/{disliked_points}")
check("호감도 상한 100", max_affinity == 100)


def level_of(points: int) -> str:
    result = "shy"
    for name in ("shy", "greeting", "close", "family"):
        if points >= levels[name]:
            result = name
    return result


check("18 + 최애(12) + 완벽(3) = 단짝 문턱 전", level_of(18 + favorite_points + gift_bonus) == "greeting",
      str(18 + favorite_points + gift_bonus))
check("45는 단짝", level_of(levels["close"]) == "close")
check("100은 가족", level_of(max_affinity) == "family")

# 채집
lane_count = int(grab(r"static let laneCount = (\d+)", gathering_text, "laneCount"))
catch_window = float(grab(r"static let defaultCatchWindow: Double = ([\d.]+)", gathering_text, "catchWindow"))
miss_penalty = int(grab(r"static let missPenalty = (\d+)", gathering_text, "missPenalty"))
streak_step = float(grab(r"static let streakStep = ([\d.]+)", gathering_text, "streakStep"))
streak_cap = int(grab(r"static let streakCap = (\d+)", gathering_text, "streakCap"))
golden_chance = float(grab(r"goldenRoll < ([\d.]+)", gathering_text, "goldenChance"))
check("채집 상수 파싱", lane_count == 3 and catch_window > 0 and miss_penalty > 0)
check("연속 배율 상한 2배", abs((1 + streak_cap * streak_step) - 2.0) < 1e-9, f"{1 + streak_cap * streak_step}")
check("황금 재료 확률 0~1", 0 < golden_chance < 0.5, str(golden_chance))

points_per = {ing: int(v) for ing, v in re.findall(r"case \.(\w+): return (\d+)", read(CORE_DIR / "Models/Ingredient.swift"))}
check("재료별 채집 점수 8종", set(points_per) == INGREDIENTS, str(points_per))
check("확장 재료가 기본 재료보다 귀함",
      min(points_per[i] for i in ["moonlitDew", "cherryHoney", "mapleSap", "snowBlossom"]) > 15,
      str(points_per))


def gathering_score(catches: int, golden: int = 0) -> int:
    score, streak = 0, 0
    for index in range(catches):
        multiplier = 1 + min(streak, streak_cap) * streak_step
        base = points_per["dewberry"] * (2 if index < golden else 1)
        score += int(round(base * multiplier))
        streak += 1
    return score


check("3연속 점수 증가", gathering_score(3) > gathering_score(2) > gathering_score(1), str(gathering_score(3)))

# 챕터 해금 미러
caught_needed = int(grab(r"totalCaught >= (\d+)", chapter_text, "caughtNeeded"))
recipes_needed = [int(x) for x in re.findall(r"cookedRecipeCount >= (\d+)", chapter_text)]
check("2장 조건 파싱", caught_needed == 4 and recipes_needed and recipes_needed[0] == 1, str(recipes_needed))

close_threshold = levels["close"]
greeting_threshold = levels["greeting"]


def chapter_unlock(chapter: str, state: dict) -> bool:
    status = state["status"]

    def done(name: str) -> bool:
        return status.get(name) == "completed"

    if chapter == "prologue":
        return True
    if chapter == "chapterOne":
        return done("prologue")
    if chapter == "chapterTwo":
        return done("chapterOne") and state["caught"] >= caught_needed and state["recipes"] >= 1
    if chapter == "chapterThree":
        greeted = sum(1 for v in state["affinity"].values() if v >= greeting_threshold)
        return done("chapterTwo") and greeted == 4 and state["recipes"] >= 3
    if chapter == "epilogue":
        close_count = sum(1 for v in state["affinity"].values() if v >= close_threshold)
        return (done("chapterThree") and SIGNATURE_JAM in state["cookedIDs"] and close_count == 4)
    return False


base_state = {"status": {}, "caught": 0, "recipes": 0,
              "affinity": {c: 0 for c in characters}, "cookedIDs": set()}

check("새 게임에서 2장 잠김", not chapter_unlock("chapterTwo", base_state))
stage1 = dict(base_state, status={"prologue": "completed", "chapterOne": "completed"}, caught=4, recipes=1)
check("채집4+요리1이면 2장 열림", chapter_unlock("chapterTwo", stage1))
stage2 = dict(stage1, status={**stage1["status"], "chapterTwo": "completed"}, recipes=3,
              affinity={c: greeting_threshold for c in characters})
check("인사4명+요리3이면 3장 열림", chapter_unlock("chapterThree", stage2))
stage3 = dict(stage2, status={**stage2["status"], "chapterThree": "completed"},
              cookedIDs={SIGNATURE_JAM}, affinity={c: close_threshold for c in characters})
check("황금 보름달 잼+단짝4명이면 에필로그 열림", chapter_unlock("epilogue", stage3))
check("시그니처 잼 없으면 에필로그 잠김", not chapter_unlock("epilogue", dict(stage3, cookedIDs=set())))

# 일기장 기대 수량
expected_diary = len(base_recipes) + len(CharacterID_CORE) * 2 + len(chapters) + 1
check("일기장 칸 수 계산(본편 21칸)", expected_diary == 21, str(expected_diary))
expected_expanded = len(green_recipes) + len(secret_recipes) + len(CharacterID_EXPANSION) * 2
check("확장 일기장 칸 수 계산", expected_expanded == 9, str(expected_expanded))
check("일기장 코드가 같은 구조", "memoryEntriesUnlocked" in diary_text and "memoryTierUnlocked" in diary_text)


# ---------------------------------------------------------------------------
# 6) README 요구 사항
# ---------------------------------------------------------------------------

readme_path = ROOT / "README.md"
if readme_path.exists():
    readme = read(readme_path)
    required = [
        ("세계관", ["세계관"]),
        ("등장인물", ["등장인물"]),
        ("게임 방법", ["게임 방법"]),
        ("조작법", ["조작"]),
        ("아키텍처", ["아키텍처"]),
        ("실행 방법", ["xcodegen", "open LittleAcornForest.xcodeproj"]),
        ("캐릭터 이름", ["토리", "송이", "몽", "루비", "보리"]),
        ("재료 이름", ["이슬방울 베리", "반딧불 꽃꿀", "별이끼 버섯", "달조각 향신료"]),
        ("레시피 이름", ["새벽이슬 잼", "반딧불 스파클 잼", "별빛 안개 잼", "구름솜 마멀레이드",
                        "유성우 베리 콩포트", "달그림자 허브 젤리", "황금 보름달 잼"]),
        ("판타지 섹션", ["주요 판타지 재료"]),
        ("번들 ID", ["com.quoguri.moonlightjamjar.app"]),
        ("달의 위상", ["달의 위상", "달빛 비밀 정원", "월광 이슬", "보름달"]),
        ("잼 병 선반", ["다락 선반", "병 꾸미기", "손글씨 라벨"]),
        ("우체통", ["우체통", "비밀 레시피"]),
        ("집중 타이머", ["집중 타이머", "ASMR"]),
        ("확장팩 3종", ["사계절 온실", "빈티지 병 공방 스킨", "모닥불 ASMR 트랙 팩"]),
        ("IAP 구현", ["StoreKit", "Products.storekit", "4,400", "2,500", "1,900"]),
        ("온실 이웃", ["루나", "코코"]),
        ("계절 레시피", ["봄 벚꽃꿀 잼", "가을 단풍 콩포트", "겨울 눈꽃 잼"]),
        ("앱 이름", ["달빛 잼 항아리", "Moonlight Jam Jar"]),
    ]
    for label, needles in required:
        missing = [n for n in needles if n not in readme]
        check(f"README: {label}", not missing, str(missing))

    # README가 실제로 존재하는 일러스트를 가리키는지
    image_refs = re.findall(r"!\[[^\]]*\]\((docs/images/[^)\s]+)\)", readme)
    image_refs += re.findall(r"<img[^>]+src=\"(docs/images/[^\"]+)\"", readme)
    check("README: 일러스트 2장 이상", len(set(image_refs)) >= 2, str(sorted(set(image_refs))))
    missing_images = [ref for ref in set(image_refs) if not (ROOT / ref).exists()]
    check("README: 일러스트 파일 존재", not missing_images, str(missing_images))
    for name in ("docs/images/characters.png", "docs/images/fantasy-items.png"):
        check(f"README: {name} 포함", name in image_refs)
    icon_at = readme.find("docs/images/app-icon.png")
    first_section = readme.find("\n## ")
    check("README: 앱 아이콘을 제목 바로 아래에 게재", 0 <= icon_at < first_section,
          f"icon={icon_at} firstSection={first_section}")
else:
    fail("README 내용", "README.md 없음")


# ---------------------------------------------------------------------------
# 7) 확장 기능(달 위상·잼 병 선반·우체통·집중 타이머·IAP) 규칙 미러링
# ---------------------------------------------------------------------------

moon_text = read(CORE_DIR / "Moon/MoonPhase.swift")
blessing_text = read(CORE_DIR / "Moon/MoonBlessing.swift")
garden_text = read(CORE_DIR / "Moon/MoonGarden.swift")
jar_text = read(CORE_DIR / "Jar/JarStyle.swift")
shelf_text = read(CORE_DIR / "Jar/CustomJamJar.swift")
mailbox_text = read(CORE_DIR / "Mailbox/MailboxSystem.swift")
focus_text = read(CORE_DIR / "Focus/FocusTimer.swift")
store_text = read(CORE_DIR / "Store/StoreCatalog.swift")
cabin_text = read(CORE_DIR / "Cabin/CabinStyle.swift")
location_text = read(CORE_DIR / "Models/ForestLocation.swift")
dialogue_text = read(CORE_DIR / "Greenhouse/GreenhouseDialogue.swift")
engine_text = read(CORE_DIR / "GameEngine.swift")

for name, path in [
    ("달 위상", CORE_DIR / "Moon/MoonPhase.swift"),
    ("달 축복", CORE_DIR / "Moon/MoonBlessing.swift"),
    ("달빛 정원", CORE_DIR / "Moon/MoonGarden.swift"),
    ("잼 병 스타일", CORE_DIR / "Jar/JarStyle.swift"),
    ("커스텀 병 모델", CORE_DIR / "Jar/CustomJamJar.swift"),
    ("우체통 편지", CORE_DIR / "Mailbox/MailboxLetter.swift"),
    ("우체통 규칙", CORE_DIR / "Mailbox/MailboxSystem.swift"),
    ("비밀 레시피", CORE_DIR / "Mailbox/SecretRecipeBook.swift"),
    ("집중 타이머", CORE_DIR / "Focus/FocusTimer.swift"),
    ("상점 카탈로그", CORE_DIR / "Store/StoreCatalog.swift"),
    ("오두막 스킨", CORE_DIR / "Cabin/CabinStyle.swift"),
    ("온실 레시피", CORE_DIR / "Greenhouse/GreenhouseRecipes.swift"),
    ("온실 대화", CORE_DIR / "Greenhouse/GreenhouseDialogue.swift"),
]:
    check(f"Core 파일 존재: {name}", path.exists(), str(path.relative_to(ROOT)))

synodic = float(grab(r"static let synodicMonth: Double = ([\d.]+)", moon_text, "synodicMonth") or 0)
reference_epoch = float(grab(r"referenceNewMoon = Date\(timeIntervalSince1970: ([\d_]+)\)", moon_text, "referenceNewMoon").replace("_", "") or 0)
check("삭망월 29.53일 근사", abs(synodic - 29.530588853) < 0.001, str(synodic))
check("달 기준점 2000-01-06 삭", abs(reference_epoch - 947_182_440) < 1, str(reference_epoch))

phase_window_line = grab(r"static let phaseWindow: Double = (1\.0 / synodicMonth|[\d.]+)", moon_text, "phaseWindow")
check("보름달 인정 창 ±1일", "synodicMonth" in phase_window_line or
      abs(float(phase_window_line or 0) - 1 / synodic) < 1e-9, phase_window_line)

phase_titles = dict(re.findall(r"case \.(\w+): return \"(초승달|상현달|보름달|그믐달)\"", moon_text))
check("달 위상 4단계 이름", phase_titles == {"crescent": "초승달", "firstQuarter": "상현달",
                                        "fullMoon": "보름달", "waning": "그믐달"}, str(phase_titles))


def swift_phase(when: str) -> str:
    import datetime as dt
    moment = dt.datetime.fromisoformat(when).replace(tzinfo=dt.timezone.utc).timestamp()
    days = (moment - reference_epoch) / 86_400
    fraction = (days % synodic) / synodic
    def distance(target: float) -> float:
        raw = abs(fraction - target)
        return min(raw, 1 - raw)
    if distance(0.5) <= 1 / synodic:
        return "fullMoon"
    if distance(0.25) <= 1 / synodic:
        return "firstQuarter"
    return "crescent" if fraction < 0.5 else "waning"


check("실제 보름(2026-03-03)", swift_phase("2026-03-03T12:00:00") == "fullMoon", str(swift_phase("2026-03-03T12:00:00")))
check("실제 보름(2026-08-28)", swift_phase("2026-08-28T12:00:00") == "fullMoon", str(swift_phase("2026-08-28T12:00:00")))
check("삭 다음 날은 초승달", swift_phase("2024-04-09T12:00:00") == "crescent", str(swift_phase("2024-04-09T12:00:00")))

blessing_tags = set(re.findall(r'tag: "(blessing\.[A-Za-z]+)"', blessing_text))
check("위상별 축복 태그 4종", len(blessing_tags) == 4, str(blessing_tags))
check("보름달 축복은 접시 +1", "bonusServings: 1" in blessing_text)
check("상현달 축복은 완성도 한 단계", "qualityUpgrade: true" in blessing_text)
check("초승달·그믐달 축복은 재료", "bonusIngredient: .dewberry" in blessing_text and
      "bonusIngredient: .moonflakeSpice" in blessing_text)
check("축복이 잼 기록에 남는다", "blessingTags" in (CORE_DIR / "GameState.swift").read_text())

check("비밀 정원은 보름달 전용", "requiresFullMoon" in garden_text or "opensSecretGarden" in garden_text)
check("달빛 정원 재료 = 월광 이슬", "moonlitDew" in garden_text)

locations = re.findall(r"^    case (\w+)$", location_text, flags=re.M)
locations = [loc for loc in locations if loc in {
    "cabinKitchen", "berryPatch", "fireflyPond", "owlLibrary", "festivalGlade", "moonlitGarden", "greenhouse"}]
check("숲 장소 7곳(기존 5 + 비밀 정원 + 온실)", len(locations) == 7, str(locations))
garden_pool = grab(r"case \.moonlitGarden: return \[([^\]]*)\]", location_text, "gardenPool")
green_pool = grab(r"case \.greenhouse: return \[([^\]]*)\]", location_text, "greenhousePool")
check("비밀 정원에는 월광 이슬", ".moonlitDew" in garden_pool, garden_pool)
check("온실에는 계절 재료 3종", all(token in green_pool for token in
                                [".cherryHoney", ".mapleSap", ".snowBlossom"]), green_pool)
check("온실 장소는 확장팩 필요", ".greenhouse: return .greenhouse" in location_text)

shelf_capacity = int(grab(r"public static let capacity = (\d+)", shelf_text, "shelfCapacity") or 0)
label_limit = int(grab(r"public static let labelLimit = (\d+)", shelf_text, "labelLimit") or 0)
check("다락 선반 9칸", shelf_capacity == 9, str(shelf_capacity))
check("손글씨 라벨 18자", label_limit == 18, str(label_limit))


def enum_cases(text: str, name: str) -> list[str]:
    match = re.search(r"public enum " + name + r"[^{]*\{(.*?)\n\}", text, flags=re.S)
    return re.findall(r"^    case (\w+)$", match.group(1), flags=re.M) if match else []


bottles = enum_cases(jar_text, "JarBottleStyle")
caps = enum_cases(jar_text, "JarCapStyle")
ribbons = enum_cases(jar_text, "JarRibbonColor")
check("병 4종(무료 3 + 크리스탈)", len(bottles) == 4 and "crystal" in bottles, str(bottles))
check("마개 4종(무료 3 + 별)", len(caps) == 4 and "starCap" in caps, str(caps))
check("리본 6색", len(ribbons) == 6, str(ribbons))
check("병·마개 스킨은 공방 팩", "self == .crystal ? .bottleWorkshop : nil" in jar_text and
      "self == .starCap ? .bottleWorkshop : nil" in jar_text)

cabin_styles = enum_cases(cabin_text, "CabinStyle")
check("오두막 스킨 3종", len(cabin_styles) == 3, str(cabin_styles))
check("기본 오두막만 무료", "self == .attic ? nil : .bottleWorkshop" in cabin_text)

mail_threshold = 20 if "affinityThreshold = AffinityLevel.greeting.rawValue" in mailbox_text else 0
mail_capacity = int(grab(r"public static let capacity = (\d+)", mailbox_text, "mailCapacity") or 0)
mail_daily = int(grab(r"public static let dailyLimit = (\d+)", mailbox_text, "mailDaily") or 0)
mail_chance = float(grab(r"public static let letterChance = ([\d.]+)", mailbox_text, "mailChance") or 0)
check("우체통은 인사하는 사이부터", mail_threshold == 20)
check("우체통 용량 10통", mail_capacity == 10, str(mail_capacity))
check("하루 최대 3통", mail_daily == 3, str(mail_daily))
check("편지 확률 0~1", 0 < mail_chance < 1, str(mail_chance))
check("비밀 레시피는 기본 재료만 쓴다",
      all(ingredient in {"dewberry", "fireflyNectar", "starMossShroom", "moonflakeSpice"}
          for ingredient in secret_recipes.get("secret-rainy-day-jam", ("", ()))[1]
          + secret_recipes.get("secret-first-frost-jelly", ("", ()))[1]))
check("쪽지는 아직 모르는 비밀 레시피만 알려 준다",
      "SecretRecipeBook.unlearned" in mailbox_text and "secretRecipeID" in mailbox_text)

focus_durations = [int(v) for v in re.findall(r"case (?:five|fifteen|twentyFive) = (\d+)", focus_text)]
check("집중 타이머 5·15·25분", focus_durations == [5, 15, 25], str(focus_durations))
pack_multiplier = int(grab(r"public static let packMultiplier = (\d+)", focus_text, "packMultiplier") or 0)
check("ASMR 팩은 보상 2배", pack_multiplier == 2, str(pack_multiplier))
check("유료 ASMR 트랙 2종(밤벌레·풍경소리)",
      "case .nightInsects, .windChime: return .asmrTracks" in focus_text)
check("집중 보상에 반딧불이 가루", "fireflyDust" in focus_text and "fireflyDust" in engine_text)
check("보름달 집중 보너스", "fullMoonBonus" in focus_text)

pack_ids = dict(re.findall(r"case \.(\w+): return \"(com\.quoguri\.moonlightjamjar\.[a-z]+)\"", store_text))
pack_prices = {pack: int(v) for pack, v in re.findall(r"case \.(\w+): return (\d{3,5})\n", store_text)}
check("상품 3종 id", pack_ids == {"greenhouse": "com.quoguri.moonlightjamjar.greenhouse",
                                 "bottleWorkshop": "com.quoguri.moonlightjamjar.bottleskins",
                                 "asmrTracks": "com.quoguri.moonlightjamjar.asmrpack"}, str(pack_ids))
check("상품 가격 4400·2500·1900", pack_prices.get("greenhouse") == 4400 and
      pack_prices.get("bottleWorkshop") == 2500 and pack_prices.get("asmrTracks") == 1900, str(pack_prices))
check("총 가격 8800원", sum(pack_prices.get(k, 0) for k in ("greenhouse", "bottleWorkshop", "asmrTracks")) == 8800)

storekit_path = ROOT / "Products.storekit"
check("Products.storekit 존재", storekit_path.exists(), str(storekit_path))
if storekit_path.exists():
    try:
        storekit = json.loads(read(storekit_path))
        check("Products.storekit 파싱", isinstance(storekit, dict))
    except json.JSONDecodeError as exc:
        storekit = {}
        fail("Products.storekit 파싱", str(exc))
    products = storekit.get("products", []) if isinstance(storekit, dict) else []
    check("storekit 상품 3종", len(products) == 3, str(len(products)))
    storekit_ids = {item.get("productID"): item for item in products}
    check("storekit id가 카탈로그와 일치", set(storekit_ids) == set(pack_ids.values()),
          str(sorted(storekit_ids)))
    check("storekit 상품은 비소모품", all(item.get("type") == "NonConsumable" for item in products),
          str([item.get("type") for item in products]))
    prices_match = all(
        str(pack_prices.get(pack)) == str(storekit_ids.get(product_id, {}).get("displayPrice"))
        for pack, product_id in pack_ids.items()
    )
    check("storekit 가격이 카탈로그와 일치", prices_match,
          str({item.get("productID"): item.get("displayPrice") for item in products}))
    korean = all(
        any(loc.get("locale") == "ko_KR" and loc.get("displayName")
            for loc in item.get("localizations", []))
        for item in products
    )
    check("storekit 한국어 표시 이름", korean)

app_imports = " ".join(module for p in app_files for module in imports_by_file.get(p, []))
check("앱이 StoreKit을 쓴다", "StoreKit" in app_imports, app_imports)
check("앱이 AVFoundation으로 소리를 만든다", "AVFoundation" in app_imports, app_imports)
check("StoreKit 상품 조회 코드", "Product.products(for:" in read(APP_DIR / "Services/StoreManager.swift"))
check("StoreKit 구매 코드", "product.purchase()" in read(APP_DIR / "Services/StoreManager.swift"))
check("로컬 구매 시뮬레이션 토글", "isSimulated" in read(APP_DIR / "Services/StoreManager.swift"))

app_view_files = [p.name for p in app_files]
for view in ["ShelfView", "MailboxView", "FocusTimerView", "StoreView", "GreenhouseView", "MoonBadgeView"]:
    check(f"화면 존재: {view}", any(p.stem == view for p in app_files), str(app_view_files))

check("Core 소스 20개 이상", len(core_files) >= 20, f"{len(core_files)}개")
check("앱 Swift 파일 18개 이상", len(app_files) >= 18, f"{len(app_files)}개")
check("단위 테스트 100개 이상", len(test_functions) >= 100, f"{len(test_functions)}개")
check("확장 기능 테스트 파일", any("MoonPhaseTests" in p.name for p in core_test_files) and
      any("MailboxTests" in p.name for p in core_test_files) and
      any("JarShelfTests" in p.name for p in core_test_files) and
      any("FocusTimerTests" in p.name for p in core_test_files) and
      any("StoreCatalogTests" in p.name for p in core_test_files) and
      any("GreenhouseTests" in p.name for p in core_test_files),
      str([p.name for p in core_test_files]))
check("화면 전환에 새 화면 등록", all(token in read(APP_DIR / "LittleAcornForestApp.swift")
                              for token in [".shelf", ".mailbox", ".focus", ".store", ".greenhouse"]))
check("달 배지가 지도·채집·부엌에 있다",
      all("MoonBadgeView" in read(path) for path in
          [APP_DIR / "Views/ForestMapView.swift", APP_DIR / "Views/GatheringGameView.swift",
           APP_DIR / "Views/CookingView.swift"]))
check("우체통 버튼에 미확인 배지", "mailBadgeCount" in read(APP_DIR / "Views/ForestMapView.swift"))
check("선반에서 병 소리 재생", "playJarPop" in read(APP_DIR / "Views/ShelfView.swift"))
check("집중 타이머 ASMR 재생", "store.startFocus" in read(APP_DIR / "Views/FocusTimerView.swift") and
      "ForestAudio.shared.playAmbient" in read(APP_DIR / "GameStore.swift"))


# ---------------------------------------------------------------------------
# 결과
# ---------------------------------------------------------------------------

passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"달빛 잼 항아리 검증: {passed}/{total} 통과\n")
for name, ok, detail in results:
    mark = "PASS" if ok else "FAIL"
    line = f"[{mark}] {name}"
    if not ok and detail:
        line += f"  -> {detail}"
    print(line)

sys.exit(0 if passed == total else 1)
