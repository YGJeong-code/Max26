# MaxScripts

Autodesk 3ds Max 용 MaxScript 툴 모음. UE 익스포트 파이프라인용 리깅 자동화 중심.

## 폴더 구조

| 폴더 | 설명 |
|------|------|
| `bipToPoint/` | Biped ↔ FBX 본 정렬, IK Bone, Root Motion, Foot Contact, Reset 셋업 |
| `sceneDump/` | 씬 노드 / 컨트롤러 / CA / 와이어 텍스트 덤프 |
| `_diag/` | 일회성 진단 / 검증 스크립트 |

## bipToPoint

| 그룹 | 버튼 / 컨트롤 | 기능 |
|------|------|------|
| Build | 1. Make Biped | 선택 메시 높이에 맞춘 Biped 생성 + 림당 트위스트 3 링크 |
| Build | 2. Make Point | Biped 본 위치에 `pt_*` Point 헬퍼 생성 → FBX 위치로 정렬 + LookAt → Euler 베이크 |
| Build | 3. Biped To Point | Point 를 따라가도록 Biped 정렬 + 모든 본 / 트위스트 박스 모드 |
| Build | 4. FBX connect To Biped | FBX 스킨본을 Biped 에 컨스트레인 (트위스트는 회전만) + 레이어 정리 (FBX 트위스트는 99_CurrectiveBone) |
| Extras | IK Bone | UE 스타일 `ik_foot_*`, `ik_hand_*` 헬퍼 생성 |
| Extras | Root Motion | `RootIK_Xtras` + RootController_Xtras Custom Attribute 리그 + FBX root 의 컨스트레인 |
| Foot Contact | Ground Z / Threshold spinner | 접지 기준값 입력 |
| Foot Contact | Foot Contact / Remove | FBX root 에 `Foot_Contact` CA (ground_z / threshold / contact_l / contact_r) 추가/제거. contact 값은 라이브 Float_Script |
| Reset | Reset (FBX + Mesh only) | FBX 본 + 메시만 남기고 다 삭제 + FBX 본 컨스트레인트 제거 (transform 보존) |

`lib/` 분할: `structs.ms` (본 매핑 테이블 + 동적 struct 생성), `makeBiped.ms`, `makePoint.ms`, `bipAlign.ms`, `fbxToBip.ms`, `layer.ms`, `ikBone.ms`, `rootMotion.ms`, `footContact.ms`, `resetScene.ms`.

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
