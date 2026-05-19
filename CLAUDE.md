# CLAUDE.md

이 파일은 Claude Code (claude.ai/code) 가 이 리포지토리에서 작업할 때 따라야 할 가이드라인입니다.

## 프로젝트

Autodesk 3ds Max (2024/2025/2026 대상) 용 MaxScript 도구 모음. 스크립트는 모두 MaxScript (`.ms`, `.mcr`) 로 작성합니다. Python (pymxs) 은 사용하지 않습니다.

## 도구 목록

### bipToPoint — Biped ↔ FBX 본 변환 / 루트모션 셋업
FBX 스켈레톤 메시에 Biped 를 맞추고, Point 헬퍼를 통해 정렬한 뒤 FBX 본을 Biped 에 연결하는 워크플로 + 루트모션 리그 자동 생성.

UI 그룹:
- **Build (4 버튼)**: 1.Make Biped → 2.Make Point → 3.Biped To Point → 4.FBX connect To Biped
- **Extras (2 버튼)**: IK Bone (UE 스타일 ik_foot/hand 헬퍼), Root Motion (RootIK_Xtras 셋업)

lib 분할:
- `structs.ms` — 본 매핑 테이블 + 동적 struct 생성 (bipStruct/pointStruct/fbxStruct)
- `makeBiped.ms`, `makePoint.ms`, `bipAlign.ms`, `fbxToBip.ms`, `layer.ms`, `ikBone.ms`, `rootMotion.ms`

### skinToPoint — 스킨 본을 Point 로 스왑
Skin 모디파이어가 적용된 메시의 루트 본 계층을 walk 해서 Point 헬퍼로 교체하는 도구. 단독 폴더로 분리됨.

워크플로 (단일 버튼으로 6단계 자동 진행):
1. Skin envelope `.env` 파일로 저장 + 메시에 `skin_` 프리픽스
2. 본 이름 스냅샷 (재등록용)
3. 루트 본 이하 전체 계층을 `pt_<name>` Point 로 생성 (부모-자식 관계 미러링)
4. 원본 본 전체 삭제
5. 모든 `pt_*` Point 의 프리픽스 제거 → 원래 본 이름 takeover
6. Skin 모디파이어에 새 Point 들을 본으로 재등록 + envelope 재로드

본 이름 패턴별 시각 스타일 자동 분류 (root/pelvis/twist/finger/weapon/ik_*/attach/camera/FACIAL).

### sceneDump — 씬 구조 텍스트 덤프
씬의 노드 트리·컨트롤러·CA·와이어·헬퍼 시각 속성을 텍스트로 저장. `.max` 파일을 직접 공유하지 않고도 구조 분석 가능.

## 리포지토리 구조

각 도구는 자체 폴더로 분리해서 독립적으로 개발/배포합니다.

```
/<ToolName>/
    <ToolName>.ms        # 메인 스크립트 / 엔트리포인트 (rollout)
    <ToolName>.mcr       # macroScript 래퍼 (툴바/메뉴 설치용)
    /lib/                # 도구 내부 헬퍼들 (struct 별 파일 분리)
    /ui/                 # rollout / dotNet UI 코드 (필요 시)
    /icons/              # 24x24 + 16x16 아이콘 (macro 등록 시)
```

새 도구를 추가할 때는 최상위에 도구 이름의 새 폴더를 만들고 — 루트에 `.ms` 파일을 흩어놓지 않습니다.

## 스크립트 실행 / 리로드

빌드 단계는 없고 3ds Max 가 MaxScript 를 직접 해석합니다.

- **한 번 실행**: Max 에서 `MAXScript > Run Script…` 또는 `.ms` 파일을 뷰포트에 드래그
- **개발 중 리로드**: Listener 에 `fileIn @"d:\YGJeong\MaxScripts\<ToolName>\<ToolName>.ms"` — 글로벌 덮어쓰기 + 롤아웃 재생성
- **macro 설치**: `.mcr` 를 뷰포트에 한 번 드래그 → `usermacros/` 로 복사됨 → `Customize User Interface` 의 카테고리에서 사용 가능
- **Listener 출력**: `format "...\n"` 으로 출력. 에러와 스택 트레이스도 여기 표시

## MaxScript 컨벤션

- **스코프 위생**: 도구는 `struct` 또는 단일 롤아웃 + 지역 변수로 감싼다. 글로벌 누출 금지 — Max 는 세션 내 글로벌을 씬 간에도 유지하므로 도구 간 이름 충돌 실제로 발생.
- **롤아웃**: UI 는 `rollout` 으로 정의하고 `createDialog` 로 연다. 핸들러 본문은 얇게 — struct 메서드에 위임해서 UI 없이도 호출 가능하게 (배치 사용에 유리).
- **Undo**: 씬 수정 동작은 `undo on (...)` 으로 감싸 한 번의 Ctrl+Z 로 도구 전체 동작이 되돌려지게.
- **Selection 안전성**: `$` (현재 선택) 가 비어있지 않다고 가정하지 말 것. `selection.count > 0` 체크하고 명확한 메시지로 종료.
- **경로**: Windows 경로는 `@"..."` 리터럴 문자열 사용 — `\` 이스케이프 문제 회피.
- **인코딩**: `.ms` / `.mcr` 는 UTF-8 with BOM (또는 ANSI) 로 저장. Max 파서는 **UTF-16 을 못 읽는다** — PowerShell 의 `Out-File` 기본값이 UTF-16 LE 라서 Max 가 못 읽는 파일을 만든다. `Set-Content -Encoding utf8` 또는 Write 도구로 작성.

## macroScript (.mcr) 패턴

`.mcr` 는 매크로를 Max UI 시스템에 등록한다. 두 가지 방식이 있는데 이 리포에서는 **하드코딩 경로** 방식을 사용:

```maxscript
macroScript MyTool
    category:"YG Tools"
    tooltip:"My Tool"
    buttonText:"My Tool"
(
    -- 하드코딩 dev 경로 — usermacros 로 설치되어도 동작
    fileIn @"d:\YGJeong\MaxScripts\<ToolName>\<ToolName>.ms"
)
```

**왜 하드코딩?** `getFilenamePath (getSourceFileName())` 패턴은 `.mcr` 가 dev 폴더에 있을 때만 작동한다. Max 가 macro 를 usermacros 로 복사하면 `.mcr` 의 자기 경로가 usermacros 가 되고, 거기엔 `.ms` 가 없어서 fileIn 이 실패한다. 하드코딩이 단순하고 확실.

설치된 매크로가 옛 버전을 캐시하면 — Max 재시작 또는 `.mcr` 재드래그로 갱신.

## MaxScript 환경 의존성 (Gotchas)

이 작업 환경 (YGJeong, Max 2025) 에서 발견된 비표준 동작들:

### 1) 파일 최상위에서 `local` 금지
```maxscript
-- ❌ 에러: "no local declarations at top level"
local thisFolder = getFilenamePath (getSourceFileName())

-- ❌ 익명 블록 `(...)` 도 top level 로 취급됨
(
    local thisFolder = ...
)

-- ✅ fn / struct / rollout 내부에서만 local 가능
-- 또는 인라인 처리
fileIn ((getFilenamePath (getSourceFileName())) + "lib/x.ms")
```

### 2) 예약어 변수명 금지
`tool`, `box`, `point`, `case`, `do`, `for`, `in`, `on`, `where` 등은 변수명으로 못 쓴다. struct 메서드 안에서 임시 변수는 `t`, `tl` 같은 비예약어 사용.

### 3) `attributes` 블록 이름 바인딩 안 됨
표준 문서대로면 `attributes MyCA (...)` 가 `MyCA` 라는 글로벌 식별자를 만들어야 하지만 이 환경에선 안 됨. `execute "MyCA"` 도 `globalVars.get` 도 모두 undefined.

**해결 패턴**: `attributes` 를 **expression 으로 변수에 직접 할당**.

```maxscript
global gMyCA

gMyCA = attributes MyCA version:1
(
    parameters main rollout:r
    (
        flag type:#float default:1.0  -- #boolean 은 paramWire subAnim 노출이 안 됨, #float 사용
    )
    rollout r "Title" (
        checkbox cb_flag "Flag"
        -- 수동 sync: float ↔ checkbox 자동 바인딩이 안 됨
        on r open do cb_flag.checked = (flag > 0.5)
        on cb_flag changed st do flag = (if st then 1.0 else 0.0)
    )
)

-- 사용 시:
custAttributes.add modifier gMyCA
```

### 4) struct 메서드에서 CA 파라미터 paramWire 불가
CA 파라미터는 `mod.numSubs == 0`. fn / execute / fileIn 스코프에서 `mod.MyCA[#param]` 으로 접근해도 paramWire.connect 가 "requires subAnims" 에러로 거부. 동작하는 유일한 경로는 **Listener** 에 명령을 직접 붙여넣는 것. 도구가 자동화 못하는 wires 는 Listener 출력 블록으로 찍어 사용자가 복사-붙여넣기 하도록.

### 5) `getNodeByName` vs `execute "$..."` 의 공백 처리
- `execute "$Bip001Pelvis"` 는 `$` 의 fuzzy 매칭으로 `"Bip001 Pelvis"` (공백 포함) 도 찾음
- `getNodeByName "Bip001Pelvis" exact:true` 는 공백 무시 안 함 → 못 찾음

→ Biped/Point (공백 포함 이름) 는 `execute "$..."`, FBX 본 (소문자/언더스코어, 공백 없음) 은 `getNodeByName ... exact:true`.

### 6) `rc.pos` 작동, `rc.rot` 작동 안 함
Point 노드의 위치는 `node.pos` 와 `node.position` 둘 다 별칭으로 작동. 회전은 `node.rotation` 만 작동, `node.rot` 는 "Unknown property" 에러. 명시적 이름 사용 권장.

### 7) `if X do (...)` 에 else 못 붙임
```maxscript
-- ❌ Syntax error: at 'else'
if cond do ( ... )
else ( ... )

-- ✅
if cond then ( ... ) else ( ... )
```

`do` 는 단일 분기, `then` + `else` 는 분기 분기.

## 도구 만들 때 패턴 (관찰된 모범 사례)

### 동적 struct 생성으로 반복 제거
본 50개를 3개 struct (bipStruct/pointStruct/fbxStruct) 에 하드코딩하면 150줄 중복. 대신 본 매핑 테이블 한 곳에 정의 + `execute` 로 struct 코드 문자열을 만들어 실행:

```maxscript
global b2p_BoneMap = #(
    #("Pelvis", "Pelvis", "pelvis"),
    -- ... 50 entries
)

fn _b2p_buildStructs = (
    local s = "struct bipStruct (\n"
    s += "    myName = \"Bip001\",\n"
    for e in b2p_BoneMap do
        s += "    my" + e[1] + " = execute (\"$\" + myName + \"" + e[2] + "\"),\n"
    s += "    myAllList = #(...)\n)\n"
    execute s
)
_b2p_buildStructs()
```

myAllList 도 필드 참조로 (재룩업 방지):
```maxscript
myAllList = #(myPelvis, mySpine, ...)  -- 이미 정의된 필드만 참조 (룩업 1회만)
```

### 진행률 표시
씬 수정이 오래 걸리는 작업은 Max 상태바 진행률 사용:
```maxscript
progressStart "Title"
progressUpdate 0
-- 단계마다
progressUpdate <0-100>
progressEnd()
```

### 에러 출력 정책
- 정상 경로의 verbose 출력은 제거. 핸들러 단위로 결과 messageBox 만.
- 에러/경고는 `try ... catch` 안에서 `format` 으로 Listener 에 (사용자가 보이게).
- 진단 dump (sub-anim 트리 등) 는 실패 시에만 출력.

## 테스트

MaxScript 는 표준 단위 테스트 프레임워크가 없다. 비자명한 로직은 struct 안에 순수 함수로 두고 Listener 에서 호출:

```maxscript
fileIn @"d:\YGJeong\MaxScripts\<ToolName>\<ToolName>.ms"
MyTool.someFunction 1 2  -- expected: 3
```

`format` 으로 어설션 로그, `throw "message"` 로 시끄럽게 실패시켜 Listener 에서 회귀 확인.

진단 스크립트는 `_diag/` 에 두고 임시로 드래그해서 사용 (e.g. `_diag/testCA.ms` 가 CA 동작 검증용).
