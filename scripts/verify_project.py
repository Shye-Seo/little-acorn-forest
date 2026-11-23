#!/usr/bin/env python3
"""
도토리 숲 프로젝트 검증 스크립트.

이 환경에는 Swift 툴체인이 없어서 `swift test`를 돌릴 수 없다. 대신 두 층으로 검증한다.

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

import math
import re
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
    if m not in {"SwiftUI", "UIKit", "Foundation", "AcornForestCore"}
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
    check("Bundle ID 고정", bundle == "com.quoguri.littleacornforest.app", str(bundle))
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

    info_props = app_target.get("info", {}).get("properties", {})
    orientations = info_props.get("UISupportedInterfaceOrientations", [])
    check("세로 고정 레이아웃", orientations == ["UIInterfaceOrientationPortrait"], str(orientations))
    check("앱 표시 이름", bool(info_props.get("CFBundleDisplayName")), str(info_props.get("CFBundleDisplayName")))

    package_file = ROOT / "Packages/AcornForestCore/Package.swift"
    package_text = read(package_file)
    check("Core 패키지 이름", 'name: "AcornForestCore"' in package_text)
    check("Core 테스트 타깃", "AcornForestCoreTests" in package_text)
    check("Core 테스트 소스 경로", "Tests/AcornForestCoreTests" in package_text)

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

characters = re.findall(r"^\s{4}case (\w+)$", read(CORE_DIR / "Models/ForestCharacter.swift"), flags=re.M)
characters = [c for c in characters if c in {"tori", "songi", "mong", "rubi"}]
check("이웃 4명", len(characters) == 4, str(characters))

# 레시피
recipe_blocks = re.findall(
    r"Recipe\(\s*id: \"([^\"]+)\",\s*name: \"([^\"]+)\",\s*ingredients: \[([^\]]*)\]",
    recipe_text, flags=re.S)
recipes = {}
for rid, name, ingredients in recipe_blocks:
    items = re.findall(r"\.(\w+)", ingredients)
    recipes[rid] = (name, tuple(sorted(items)))
check("레시피 6종 이상", len(recipes) >= 6, f"{len(recipes)}종")
check("레시피 id 중복 없음", len(recipe_blocks) == len(recipes))
check("모든 레시피 2~3가지 재료", all(2 <= len(v[1]) <= 3 for v in recipes.values()),
      str({k: v[1] for k, v in recipes.items()}))
combos = [v[1] for v in recipes.values()]
check("조합 중복 없음", len(combos) == len(set(combos)), str(combos))
check("모든 레시피 재료가 실제 재료", all(
    set(v[1]) <= {"raspberry", "acorn", "honeyMushroom", "moonHerb"} for v in recipes.values()))
check("축제 케이크 존재", "starlight-cake" in recipes)

min_chapters = re.findall(r"minChapter: \.(\w+)", recipe_text)
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

check("이웃 4명 최애 요리 지정", set(favorite_map) == set(characters), str(favorite_map))
check("최애 요리가 실제 레시피", all(v in recipes for v in favorite_map.values()), str(favorite_map))
check("최애 요리가 겹치지 않음", len(set(favorite_map.values())) == len(favorite_map), str(favorite_map))
check("좋아하는/싫어하는 요리가 실제 레시피",
      all(v in recipes for values in liked_map.values() for v in values)
      and all(v in recipes for values in disliked_map.values() for v in values),
      f"{liked_map} / {disliked_map}")
check("호불호가 최애와 겹치지 않음",
      all(favorite_map[c] not in liked_map.get(c, []) + disliked_map.get(c, []) for c in characters),
      str(favorite_map))
check("이웃 모두 소원 문장 있음", len(re.findall(r"return \"[^\"]+\"", wish_block)) >= len(characters), wish_block[:80])

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
              if ing not in {"raspberry", "acorn", "honeyMushroom", "moonHerb"} or int(n) <= 0]
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
                  "for recipe in RecipeBook.all", "for character in CharacterID.allCases",
                  "for chapter in StoryChapter.ordered"]
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
check("재료별 채집 점수 4종", len(points_per) >= 4, str(points_per))


def gathering_score(catches: int, golden: int = 0) -> int:
    score, streak = 0, 0
    for index in range(catches):
        multiplier = 1 + min(streak, streak_cap) * streak_step
        base = points_per["raspberry"] * (2 if index < golden else 1)
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
        return (done("chapterThree") and "starlight-cake" in state["cookedIDs"] and close_count == 4)
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
              cookedIDs={"starlight-cake"}, affinity={c: close_threshold for c in characters})
check("케이크+단짝4명이면 에필로그 열림", chapter_unlock("epilogue", stage3))
check("케이크 없으면 에필로그 잠김", not chapter_unlock("epilogue", dict(stage3, cookedIDs=set())))

# 일기장 기대 수량
expected_diary = len(recipes) + len(characters) * 2 + len(chapters) + 1
check("일기장 칸 수 계산", expected_diary == 21, str(expected_diary))
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
        ("요리 이름", ["도토리 파이", "산딸기 잼", "꿀버섯 수프", "달빛 꿀차"]),
        ("번들 ID", ["com.quoguri.littleacornforest.app"]),
    ]
    for label, needles in required:
        missing = [n for n in needles if n not in readme]
        check(f"README: {label}", not missing, str(missing))
else:
    fail("README 내용", "README.md 없음")


# ---------------------------------------------------------------------------
# 결과
# ---------------------------------------------------------------------------

passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"도토리 숲 검증: {passed}/{total} 통과\n")
for name, ok, detail in results:
    mark = "PASS" if ok else "FAIL"
    line = f"[{mark}] {name}"
    if not ok and detail:
        line += f"  -> {detail}"
    print(line)

sys.exit(0 if passed == total else 1)
