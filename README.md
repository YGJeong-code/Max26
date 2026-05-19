# MaxScripts

Autodesk 3ds Max 용 MaxScript 툴 모음. UE 익스포트 파이프라인용 리깅 자동화 중심.

## 폴더 구조

| 폴더 | 설명 |
|------|------|
| `bipToPoint/` | Biped ↔ FBX 본 정렬, IK Bone, Root Motion 셋업 |
| `skinToPoint/` | Skin 모디파이어 메시의 본 계층을 Point 헬퍼로 스왑 |
| `sceneDump/` | 씬 노드 / 컨트롤러 / CA / 와이어 텍스트 덤프 |
| `_diag/` | 일회성 진단 / 검증 스크립트 |

## bipToPoint

| 단계 | 버튼 | 기능 |
|------|------|------|
| 1 | Make Biped | 선택 메시 높이에 맞춘 Biped 생성 (twist links 3) |
| 2 | Make Point | Biped 본 위치에 `pt_*` Point 헬퍼 생성 |
| 3 | Biped To Point | Point 를 따라가도록 Biped 정렬 |
| 4 | FBX connect To Biped | FBX 스킨본을 Biped 에 Position/Orient 컨스트레인 + 레이어 정리 |
| Extras | IK Bone | UE 스타일 `ik_foot_*`, `ik_hand_*` 헬퍼 생성 |
| Extras | Root Motion | `RootIK_Xtras` Custom Attribute 리그 + 와이어 자동 셋업 |

`lib/` 분할: `structs.ms` (본 매핑 테이블 + 동적 struct 생성), `makeBiped.ms`, `makePoint.ms`, `bipAlign.ms`, `fbxToBip.ms`, `layer.ms`, `ikBone.ms`, `rootMotion.ms`.

## skinToPoint

단일 버튼으로 6단계 자동 진행 — envelope 저장 → 본 이름 스냅샷 → Point 계층 생성 → 원본 본 삭제 → Point 이름 takeover → Skin 재등록 + envelope 재로드. 본 이름 패턴별 시각 스타일(root / pelvis / twist / finger / weapon / ik_* / FACIAL) 자동 분류.

## sceneDump

씬 구조를 텍스트로 저장해 `.max` 파일을 직접 공유하지 않고도 구조 분석 가능. 노드 트리, 컨트롤러, Custom Attributes, paramWire, 헬퍼 시각 속성 포함.

## 실행 방법

1. **한 번 실행**: Max 에서 `MAXScript > Run Script…` 또는 `.ms` 파일을 뷰포트에 드래그.
2. **개발 중 리로드**: Listener 에 `fileIn @"d:\YGJeong\MaxScripts\<Tool>\<Tool>.ms"`.
3. **macro 설치**: `.mcr` 파일을 뷰포트에 드래그 → `usermacros/` 로 복사됨 → `Customize User Interface` 의 "YG Tools" 카테고리에서 툴바/메뉴로 등록.

## 환경

- 3ds Max 2024 / 2025 / 2026
- MaxScript only (Python / pymxs 사용 안 함)
- `.ms` / `.mcr` 인코딩: UTF-8 with BOM 또는 ANSI (Max 파서는 UTF-16 비호환)

자세한 컨벤션과 환경 의존성(MaxScript gotchas)은 [CLAUDE.md](CLAUDE.md) 참고.
