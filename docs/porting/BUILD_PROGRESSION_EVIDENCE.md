# 빌드와 탐험 성장의 공개 근거 재조사

조사일: 2026-10-10. 목표: The Severed Gods **EA v0.2.102**.
대조 문서: 2026-10-08 기획서 `ashen-oath-severed-gods-mechanics-porting-plan.md`
전체 357행의 BUILD-01/02/03, PROG-01/02/03/04와 [GAP_MATRIX.md](GAP_MATRIX.md).
기획서는 요구사항이며 원작의 실측 증거가 아니다. GAP_MATRIX의 기존 상태는 그
문서에 명시된 이전 Ashen 기준선이고, 이번 작업에서 현재 실행 상태를 재감사하지 않았다.

**결론:** 획득·장착·강화·합성, 보상 장착, 서로 다른 NPC 서비스, 영구 해금의
구조는 공개 공식자료로 더 구체화할 수 있다. 그러나 목표 버전의 슬롯 제약,
레벨·변형 표, Empower 분배, Sigil 비용·성공률, Soul 정산·시설 가격을 완성하는
증거는 확보하지 못했다. 사용자 승인 임시 전투 프로필을 유지하되, 그 승인을
성장·탐험의 새 임시 규칙 승인으로 확대하지 않는다. 아래 조사만으로 원작
성장 이식 완료, 콘텐츠 수 충족 또는 Phase 0 통과를 선언할 수 없다.

## 증거의 등급과 사용 경계

- **T: 목표 버전 공식 변경 기록.** 그 변경·UI·존재만 확인한다. 생략된 공식은 미확정이다.
- **H: 과거 공식 패치 또는 데모 설명.** 기록된 빌드/발표에만 귀속한다.
- **M: 공식 소개.** 공개된 구조·예시이며 목표 버전의 실행 결과나 전체 표가 아니다.
- **U: 비공식 위키.** 독립 교차검증 전에는 구현값으로 채택하지 않는다.
- **O: 목표 버전 실측.** 이번 조사에서는 없음. 게임 구매·설치·로그인·실행 없음.

본문의 판정은 공개 웹의 읽기 결과다. 직접 공지 대신 Steam 공식 피드로 본문을
확보한 경우 피드 URL과 패치 제목을 함께 적었다. 피드는 여러 게임을 포함하므로
반드시 **The Severed Gods 또는 The Severed Gods Playtest** 제목 아래의 항목을
찾아야 한다. 다른 게임의 같은 단어를 근거로 섞지 않는다.

## 목표 버전에서 직접 좁힐 수 있는 구조

아래는 [S1: 공식 v0.2.102 공지](https://steamcommunity.com/app/3755930/)의
`Features & Gameplay Updates`, `Skill & Relic UI`, `Reward & Result UI`,
`NPC & Content Updates`, `Bug Fixes` 절을 요약한 것이다. 등급은 모두 T다.

| 영역 | 확인한 한정된 사실 | 확정하지 않는 것 |
|---|---|---|
| 장착 | 전투 결과 화면에서 스킬·유물 Quick Equip, 인벤토리/상점 장비 설명이 존재한다 | 슬롯수, 교체 제한, 전투 중 교체 |
| 레벨 | Dulling Stab의 상위 레벨 조정, Iron Wall의 레벨별 효과 수정이 있다 | 공통 최대 레벨, 비용, 각 레벨 수치 |
| 보상 | 동일 아이템 보상을 수량 표기로 묶는다. Empower 규칙을 변경했다 | 같은 유물을 중복 장착하거나 효과를 중첩할 수 있다는 뜻은 아님 |
| 영웅 | 미선택 영웅이 City 1/2 조우에 등장하고 NPC Hero 스킬 풀이 수정됐다 | 출현 확률, 영입 비용, 동료 상한·이탈 규칙 |
| Soul | 적 HP 표시 해금 노드가 MP 회복 노드로 바뀌었다 | 회복량, 발생 시점, 가격·선행 노드 |
| 시설 | Karma Shop 할인과 별도 Karma Festival, Recruit Companion 사건이 언급된다 | 할인율, 축제 발동·서비스 순서 |
| 미완성 기능 | Morph Sigil과 Campfire는 개발 진행 50%로 명시됐다 | 완성된 서비스 목록이나 정상 실행 가능 범위 |

따라서 이전 Empower 공식을 가져오거나, 위키의 완성형 캠프를 목표 버전에
대입해서는 안 된다. 기존 영웅 초기 스킬도 Swordsman/Merchant/Scholar 변경
기록이 있으므로 오래된 시작 장비를 그대로 확정할 수 없다.

## 과거 공식자료에서 확보한 구체 선택 구조

각 행은 해당 자료의 역사적 사실이다. **EA 0.2.102의 동작 보증이 아니다.**

| 근거 | 공개된 내용 | 구현/검증에 주는 한계 |
|---|---|---|
| [S3: 2월 11일 공식 데모 발표](https://store.steampowered.com/news/posts/?enddate=1770865388&feed=steam_community_announcements), `Meta Progression (Soul System)` | Fate Prayers는 스킬·유물 해금, Hero Marks는 영웅별 NPC 상호작용 강화, Prosperity Blessings는 여관·상점 등 시설 강화라는 세 범주 | 세 범주를 HP/공격/MP 수치 강화 세 개로 치환할 수 없다. 가격·선행 조건·대상 목록은 없음 |
| S3, `A Dynamic World & Meaningful Choices` | Chef는 음식의 임시 버프, Spirit은 스킬 강화, Berserker는 콤보 기술이라는 서로 다른 서비스 역할 | 세 NPC를 모두 같은 회복 선택으로 치환할 수 없다. 실제 선택지·효과 표는 없음 |
| [S5: 플레이테스트 v0.2.9, 7월 10일](https://store.steampowered.com/news/posts/?enddate=1783737356&feed=steam_community_announcements), `NEW CONTENT`, `UI & UX` | 7번째 Skill Slot 추가와 Transform Skill 슬롯 UI 수정 | 7슬롯의 존재는 과거 근거. 일반/고정/변형 슬롯 구분, 시작 개수, 목표 버전 상한은 미확정 |
| [S6: 플레이테스트 v0.1.201, 7월 1일](https://store.steampowered.com/news/posts/?appgroupname=Batman+Arkham+City%3A+Arkham+City+Skins+Pack+DLC&enddate=1782904792&feed=steam_community_announcements), `Balance / Tuning`, `UI / UX` | 노인 사건의 스킬 선택 수를 줄임. Upgrade/Merge는 해당 NPC 경로가 아니면 금화 비용 버튼을 숨김. 업그레이드 선택 뒤 Hold to Upgrade 표시 | 획득 경로에 따른 맥락 차이가 있음. 비NPC 경로가 무조건 무료라는 뜻도, 고정 3택1이라는 뜻도 아님 |
| S6, `World / Visual Updates` | NPC Service가 Behemoth 격파 없이 시작부터 등장하도록 변경 | 모든 시설/영웅이 첫 여정부터 해금된다고 확대하지 않음 |
| [S7: 플레이테스트 v0.2.25, 7월 22일](https://store.steampowered.com/news/posts/?enddate=1784730653&feed=steam_community_announcements), `Tuning`, `Test Case` | 사건 스킬 보상에 실제 레벨 표시. Eye of Ra를 가진 Single + Single Skill Merge의 검증 항목 존재 | 모든 보상이 레벨1은 아니다. 기재된 검증 예정 사례는 합성 성공 결과나 공식의 증명이 아님 |
| [S8: 플레이테스트 v0.2.15, 7월 15일](https://store.steampowered.com/news/posts/?enddate=1784123878&feed=steam_community_announcements), `Bug Fixes`, `Pending Tuning / QA` | Karma 차단 후 3번째 노드에서 다시 등장하는 문제, 재발동 억제 노드 수의 명확화/검증 과제가 있다 | 단순한 선악 수치 하나 외에 사건 이력/차단 상태가 필요할 수 있다. 억제 기간을 3노드로 확정하면 안 됨 |
| [S9: 공식 v0.2.88, 8월 28일](https://steamcommunity.com/app/3755930/?l=russian), `Gameplay & Balance`, `UI & Improvements` | Transform Skills의 레벨업 규칙 변경, Hero Sigil 사용 비용 증가, 캐릭터 능력치 표시 후 보상 흐름, Empower 선택 UI | 규칙·비용의 존재만 확인. 전후 수치와 세부 적용 조건은 없음 |
| [S10: 6월 16일 공식 Next Fest 데모 발표](https://store.steampowered.com/news/posts/?enddate=1781608479&feed=steam_community_announcements), `Hero Sigil Action System`, `Demo` | 훔치기·모집·학습·협상·정보 수집, 분기 첫 월드와 변화하는 마을을 소개 | 영웅마다 가능한 행동/실패 결과/수수료/횟수는 없음. 데모 범위와 EA를 혼합하지 않음 |

### 최신 공식 소개의 의미

[S2: Steam 소개](https://store.steampowered.com/app/3755930/The_Severed_Gods/)는
Thief의 NPC 물건 절도, Scholar의 적 약점 조사, Merchant의 동료 모집을
구체 예로 든다. 죽어가는 병사의 물자를 가져갈지 안전하게 호송할지,
어둠의 선물을 받을지 거부할지라는 선택도 제시한다. 이는 M등급의 실제
**공개 선택 예시**이며 사건 텍스트·수치·출현 조건을 완전히 확보한 것은 아니다.
공식 홍보 규모는 5영웅/3월드/100+스킬/80+유물이다. 이 숫자는 카탈로그가 아니다.

[S4: 제작사 itch 소개](https://topeboxgames.itch.io/the-severed-gods)는 유물을
장착해 원소·상태·다단/콤보 등 스킬 작동을 바꾸는 구조, 여관·상점·NPC·스킬의
영구 성장을 설명한다. 다만 8영웅/80+스킬/90+유물이라는 다른 규모를 제시하고
빌드를 특정하지 않는다. 따라서 전부 목표 EA 데이터라고 합칠 수 없다.

## BUILD와 PROG별 판정

아래의 ‘가능’은 **원작과 무관하게 검증할 수 있는 소프트웨어 기반 작업**을
뜻한다. 새 게임 규칙을 자유롭게 만들어도 된다는 뜻이 아니다.

| 요구사항 | 확보한 구조/관련 근거 | 아직 필요한 원작 증거 | 현재 안전하게 구현 가능한 기반 |
|---|---|---|---|
| BUILD-01 스킬 | 장착·업그레이드·합성·변형 슬롯이 서로 구분되는 화면/기록. S1/S5/S6/S7/S9 | 전체 스킬 ID와 속성/높이/비용/레벨표, 슬롯 해금, 교체 가능 시점, Merge 입력/출력과 Transform의 관계 | 스킬 정의와 소유 인스턴스 분리, 안정 ID, 레벨별 설명·비교 UI, 원자적 장착/해제, 근거 없는 정의 거부 |
| BUILD-02 유물 | 스킬 작동 변화와 조건부 발동 존재. S4와 기존 [역사적 반격 근거](HISTORICAL_EFFECTS.md) | 유물 슬롯/중복, 개별 트리거, 중첩·연쇄 순서, 변형 수치와 우선순위 | 사건 타입과 발동 출처를 기록하는 해석기 경계, 동일 입력 재현, 순환/중복 방지 검증. 검증되지 않은 유물은 활성화하지 않음 |
| BUILD-03 보상/Empower | 보상 장착, 선택 UI, 보상 수량과 획득 경로 차이. S1/S6/S7/S9 | 전투별 획득 시점·률·희귀도·개수, 보상 순서, 적용 대상/효과, 선택 취소·중복 | 보상 묶음과 선택 상태 저장, 중복 수령 차단, 장착 UI 재사용, 선택 미완료 상태의 저장/재개 |
| PROG-01 영웅/NPC/Sigil | 클래스별 상호작용과 미선택 영웅 조우. S1/S2/S3/S10 | 시작 구성/해금, 영웅↔동료 역할, NPC 능력치/스킬, 성공률·비용·실패·이탈 | 주인공/동료/NPC의 역할 ID, 가용 행동 목록과 조건 평가, 결과 기록, 편성 표시/저장. 고정3인을 원작 파티로 간주하지 않음 |
| PROG-02 탐험 | 분기/마을/시설 구조. S4/S6/S10 | 목표 지도 노드 수·연결·생성·전투 간격·출구, 월드 전환과 자원 이월 | 노드 그래프 자료형, 현재/방문/해금 노드 검증, 이동 중단 복구, 결정적 지도 시드. 임의의 9/12/18노드 지도를 원작으로 활성화하지 않음 |
| PROG-03 Karma | 선택으로 후속 사건/보상 변화, 차단 이력 존재. S2/S8 | Virtue/Sin 저장 방식, 변화량·문턱·성공률 수정·재등장·중첩/리셋 표 | 사건 ID·이력·차단/해제 조건·결과의 선언형 기록. 기존 음수 Karma→실드+1을 원작 대응값으로 옮기지 않음 |
| PROG-04 환생/영구 성장 | 콘텐츠 해금/NPC능력/시설이라는 서로 다른 세 축. S3/S4 | Soul 획득·실패/승리 정산, 가격·상한·선행 조건, 실제 해금 풀, 다음 Cycle 적용/리셋 | 영구 해금과 여정 획득 상태 분리, 정산 멱등성, 다음 여정 후보 풀 필터, 구규칙 저장 보존. Ash→Soul 환산 금지 |

### 구현 시 반드시 분리할 상태

다음은 원작 수치가 아니라 이식 과정의 오류를 막기 위한 **엔지니어링 제안**이다.

1. 콘텐츠 정의: `id`, `source_id`, `source_version`, `verification_status`,
   `eligibility`, `level_records`, `transform_relation`. 모르는 값은 미확정으로 둔다.
2. 여정 소유 상태: 획득 인스턴스, 장착 위치, 실제 레벨, 획득 경로, 선택 대기 보상.
3. 영구 상태: 해금된 콘텐츠 ID, 영웅별 상호작용 성장, 시설 서비스 성장,
   정산 식별자. 현재의 ‘소유’와 미래 드롭 풀의 ‘해금’을 같은 boolean으로 합치지 않는다.
4. 합성/변형: 입력 목록·출력 정의·비용·소모 여부를 증거로 지정할 수 있는 계약.
   Merge와 Transform을 같은 연산으로 단정하지 않으며, 확인 전에는 실행을 거부한다.
5. 출처 경계: `historical_not_target_verified`와 승인된 Ashen 임시 프로필을 별도 저장.
   임시값이 레벨표·해금 풀을 통해 목표 프로필로 누출되지 않도록 한다.

이 구조의 테스트에는 합성 fixture를 쓸 수 있다. fixture의 수치와 선택 수는
테스트용일 뿐, 원작 콘텐츠나 플레이 가능한 성장 구현 개수로 세지 않는다.
읽기·비교·저장·검증 기반은 전진시킬 수 있지만, 미확정 비용을 0으로 두어
무료 서비스처럼 실행하거나 UI만 붙인 뒤 BUILD/PROG를 완료 처리하지 않는다.

## 위키 검토 결과와 배제한 주장

[U1: Hero Sigils](https://theseveredgods.wiki/players/hero-sigils/)와
[U2: Relics & Builds](https://theseveredgods.wiki/guides/relics-and-builds/),
[U3: Camp & Rest](https://theseveredgods.wiki/guides/camp-and-rest/)는 본문을
읽었다. 모두 2026-08-11 갱신 표기이며 사이트가 비공식·비제휴라고 명시한다.

- U1은 Hero Marks를 영웅별 조각 화폐, Sigils를 제작·장착하는 장비로 설명하고
  1~3 슬롯, 분기별 랜덤 효과 제작을 주장한다. 공식 S3/S10의 NPC 행동/강화
  설명과 다른 구조인데, 이를 연결하는 원본 영상·패치·표가 제시되지 않았다.
  이 제작 시스템과 슬롯 숫자를 채택하지 않는다.
- U2의 초기 유물3~5개, 캠프3택1, 다단 공격의 매타격 발동, 중복 효과의 부분
  중첩은 이 조사에서 1차 근거를 확보하지 못했다. 각각 별도 검증 대상이다.
- U3의 3택1 캠프, 여관 Sigil 재설정, 할인50%, 데모 v2.0.4 Short Rest 설명도
  목표 버전의 원본 기록과 연결되지 않는다. 같은 사이트 안에서도 U1의 향후
  reroll 가능성 표현과 U3의 재설정 설명 사이에 구분이 필요하다.
- [U4: Heroes Hub](https://theseveredgods.wiki/players/)는 검색색인에서
  Swordsman/Axeman/Scholar/Thief/Taoist를 시작5인으로 제시했다. 공식 S1/S2는
  Merchant를 구체적으로 다룬다. 위키의 로스터와 ‘전원 즉시 선택’도 확정하지 않는다.
  U4 직접 본문 열기는 실패했으므로 검색색인 관찰 수준으로만 기록한다.
- 위키의 [Reincarnation Meta](https://theseveredgods.wiki/guides/reincarnation-meta/)
  직접 본문 열기는 실패했다. 내용/가격표를 확인했다고 주장하지 않는다.

이는 해당 사이트 전체가 거짓이라는 판정이 아니라, 정밀 이식의 숫자·공식을
여기에 의존할 수 없다는 증거 품질 판정이다. 위키는 조사 질문을 만드는 데만
사용하고 코드의 권위 자료로 삼지 않는다.

## 다음 증거 수집의 최소 패킷

새 구매/설치 없이 확보할 수 있는 **버전이 보이는 연속 플레이 기록**이나
사용자가 제공하는 목표 빌드 기록이 있으면 아래 패킷부터 채운다. 짧은 단일
스크린샷이나 오래된 위키 숫자만으로 빈칸을 채우지 않는다.

1. **장착:** 새 영웅 선택 → 전체 슬롯 화면 → 새 스킬 획득 → 비교 → 장착/교체
   → 전투 사용 → 재개. 고정/일반/변형 슬롯, 장착·교체 제한과 보유/장착 구분.
2. **성장:** 같은 스킬의 모든 표시 레벨, Upgrade 전후 자원과 효과, Merge의
   입력 두 개·순서·레벨·소모·출력, Transform 진입/해제. NPC와 보상 경로를 따로.
3. **Empower:** 같은 조우의 전투 전→승리→모든 보상 단계→적용 후 인벤토리.
   획득 사실만으로 확률을 산출하지 않고 샘플수·조건을 남긴다.
4. **Sigil/NPC:** 영웅별 대화 선택 목록, 사용 전 비용/성공률, 성공과 실패,
   Karma·소유 스킬·동료·시설 상태 변화. Hero Mark와 Sigil의 실제 메뉴 관계.
5. **환생:** 종료 전 Soul/해금→정산→세 성장 메뉴 전체→구매 전후→다음 여정.
   죽음·클리어·중도포기의 차이, 아이템 보유와 드롭풀 해금의 차이를 기록.
6. **지도/시설/Karma:** 전체 월드 지도와 방문 순서, 첫/이후 여정의 시설 서비스,
   동일 Karma 사건의 차단·재등장과 다음 노드 상태. 영구 변화와 여정 변화를 분리.

## 이번 변경 범위

이 문서만 추가했다. production 코드, 임시 전투 프로필, 원작 카탈로그,
`severed_v0_2_102/evidence.json`과 28개 미확정 계약을 변경하지 않았다.
본 조사는 새로운 성장·탐험 규칙을 승인하거나 게임을 실행한 작업이 아니다.
