extends RefCounted
## Display-only Korean localization. Canonical model fields and saved logs stay English.
## Object.tr is non-static in Godot; preload callers use translate() or t().
## Unknown text is returned unchanged and exposed by missing_sources(), never guessed.

const FONT_PATH: String = "res://assets/fonts/AshenKorean-Regular.otf"
const PREFERENCES_PATH: String = "user://ashen_oath_language.cfg"
const SUPPORTED_LANGUAGES: Array[String] = ["ko", "en"]
static var language: String = "ko"
static var tooltips_enabled: bool = true
static var _ready_catalog: bool = false
static var _upper: Dictionary = {}
static var _compiled: Array[Dictionary] = []
static var _cache: Dictionary = {}
static var _missing: Dictionary = {}

const CATALOG: Dictionary = {
	"T / Tooltips on": "T / 툴팁 켜짐",
	"T / Tooltips off": "T / 툴팁 꺼짐",
	"D / Details": "D / 상세",
	"D / ESC / RETURN": "D / ESC / 돌아가기",
	"BATTLE DETAILS": "전투 상세",
	"SYMBOL GUIDE": "기호 안내",
	"HP": "체력",
	"Focus": "집중",
	"Shield": "방어막",
	"Damage": "피해",
	"Weakness": "약점",
	"Next": "다음",
	"Ready": "행동 가능",
	"Acted": "행동 완료",
	"Guard": "방어",
	"Fallen": "쓰러짐",
	"Break": "붕괴",
	"Sever": "절단",
	"Exposed": "노출",
	"Cancelled": "취소됨",
	"Warded": "의식 차단",
	"Missed": "대상 없음",
	"Half": "절반",
	"Incoming": "공격 예고",
	"Round": "라운드",
	"Actions": "행동",
	"Source": "공격 부위",
	"Target": "대상",
	"Costs": "소모",
	"RECENT HISTORY": "최근 기록",
	"SELECTED HERO / SKILLS": "선택한 영웅 / 기술",
	"SELECTED PART": "선택한 부위",
	"LIVE OMEN": "현재 전조",
	"NEXT ROUND": "다음 라운드",
	"Tab / inspect · 1–3 / hero · Up/Down / target": "Tab / 살펴보기 · 1–3 / 영웅 · 위/아래 / 부위",
	"Heart: HP. Diamond: Focus cost, or recovery with +. Shield: defense. Attack-type icon + number: part damage. Crosshair: marked target. Broken shield: break. Split blade: sever. Type icons match weaknesses.": "하트: 체력. 마름모: 집중 소모, +는 회복. 방패: 방어막. 공격 유형 기호와 수치: 부위 피해. 조준선: 지정 대상. 깨진 방패: 붕괴. 갈라진 검: 절단. 공격 유형 기호를 약점과 맞추세요.",
	"Tab / Shift+Tab inspects controls without acting. 1–3 selects a hero; Up/Down selects a part. Q/W/E attacks; R defends. Space ends the round. D opens these details, even with tooltips off.": "Tab / Shift+Tab으로 행동 없이 정보를 살펴봅니다. 1–3은 영웅, 위/아래는 부위 선택. Q/W/E 공격, R 방어, Space 라운드 종료. 툴팁을 꺼도 D로 상세 정보를 볼 수 있습니다.",
	"Toggle hover and keyboard inspection tooltips. This display preference is saved separately from your journey. Details remain available with D.": "마우스와 키보드 정보 툴팁을 켜거나 끕니다. 여정과 별도로 저장하는 화면 설정입니다. 꺼도 D로 상세 정보를 볼 수 있습니다.",
	"The tooltip preference could not be saved.": "툴팁 설정을 저장하지 못했습니다.",
	"No target": "대상 없음",
	"No second source": "추가 부위 없음",
	"Two sources": "두 부위 공격",
	"One source": "한 부위 공격",
	"R cancels": "R로 취소",
	"END ROUND": "라운드 종료",
	"Resolve": "실행",
	"Safe": "안전",
	"Sever the source to cancel. Break it to halve damage.": "공격 부위를 절단하면 취소, 붕괴하면 피해가 절반이 됩니다.",
	"Attacks resolve in numbered order. Values are the exact HP and Focus losses after current guards and broken sources.": "번호 순서대로 공격합니다. 수치는 현재 방어와 붕괴를 반영한 정확한 체력·집중 손실입니다.",
	"Skill descriptions, symbols, the current omen, and recent history.": "기술 설명, 기호, 현재 전조와 최근 기록을 확인합니다.",
	"Half incoming damage": "받는 피해 절반",
	"Ward + half": "의식 차단 + 절반",

	"Halve incoming damage this round. Restore 2 focus and 3 HP.": "이번 라운드 받는 피해를 절반으로 줄이고 집중 2, 체력 3을 회복합니다.",
	"A newer checkpoint exists.": "더 최신 체크포인트가 있습니다.",
	"A newer checkpoint was saved by another window. Reload the saved journey before retrying.": "다른 창에서 더 최신 체크포인트를 저장했습니다. 저장된 여정을 다시 불러온 뒤 저장을 재시도하세요.",
	"A newer checkpoint exists. Reload it before retrying.": "더 최신 체크포인트가 있습니다. 다시 불러온 뒤 저장을 재시도하세요.",
	"A newer checkpoint exists. Reload it before retrying. Changes are still in memory; saving must succeed before closing.": "더 최신 체크포인트가 있습니다. 다시 불러온 뒤 저장을 재시도하세요. 변경 사항은 아직 실행 중인 게임에 남아 있습니다. 게임을 닫기 전에 저장을 완료해야 합니다.",
	"SAVE ERROR / REVIEW": "저장 오류 / 확인",
	"RELOAD SAVED JOURNEY?": "저장된 여정을 다시 불러올까요?",
	"Reloading discards unsaved actions in this window and opens the latest valid checkpoint. Conflicting save files will not be overwritten.": "다시 불러오면 이 창에서 저장하지 않은 행동은 사라지고 최신의 정상 체크포인트를 엽니다. 충돌하는 저장 파일을 덮어쓰지는 않습니다.",
	"ENTER / RELOAD": "ENTER / 다시 불러오기",
	"Saved checkpoint reloaded.": "저장된 체크포인트를 다시 불러왔습니다.",
	"SAVE RECOVERY NOTICE": "저장 복구 안내",
	"RELOAD SAVED JOURNEY": "저장된 여정 불러오기",
	"ENTER / CONTINUE": "ENTER / 계속하기",
	"SAVE NEEDS ATTENTION": "저장 상태를 확인하세요",
	"ENTER / RETRY SAVE": "ENTER / 저장 재시도",
	"Two saves disagree at the same checkpoint. Automatic recovery stopped; no save files were changed.": "동일한 체크포인트의 두 저장 파일이 서로 다릅니다. 자동 복구를 중단했으며 저장 파일은 변경하지 않았습니다.",
	"ASHEN OATH — Character Studio": "재의 맹세 — 캐릭터 스튜디오",
	"L  한국어": "L  한국어",
	"L  English": "L  English",
	"L / Change language (한국어 / English)": "L / 언어 변경 (한국어 / English)",
	"The language preference could not be saved.": "언어 설정을 저장하지 못했습니다.",
	"MAX": "최고 단계",
	"+5 max HP": "최대 체력 +5",
	"+2 damage": "피해 +2",
	"+1 max Focus": "최대 집중 +1",
	"WARD RITE + HALVE": "의식 취소·피해 절반",
	"HALVE INCOMING": "받는 피해 절반",
	"YOUR FIRST BATTLE": "첫 전투 안내",
	"ENTER / START BATTLE": "ENTER / 전투 시작",
	"ESC / DISMISS · H / GUIDE ANYTIME": "ESC / 닫기 · H / 도움말 다시 보기",
	"1. Choose a hero, then a body part. Match its weakness to remove extra shields and BREAK it.\n\n2. A later strike can SEVER a broken part once its HP reaches zero. Sever the source of an omen to cancel that attack.\n\n3. Q is a free attack. R is Defend: halve normal damage and recover up to 2 Focus. A marked hero can Defend to cancel a wardable rite.\n\nRead the live omen and damage forecast before committing. Nothing moves until you act.": "1. 영웅과 부위를 선택하세요. 약점에 맞는 공격은 방어막을 더 많이 깎습니다. 방어막이 0이 되면 붕괴합니다.\n\n2. 붕괴된 뒤의 후속 공격으로 부위 체력을 0으로 만들면 절단됩니다. 전조의 공격 부위를 절단하면 그 공격이 취소됩니다.\n\n3. Q는 집중을 쓰지 않는 공격입니다. R은 방어: 일반 피해를 절반으로 줄이고 집중을 최대 2 회복합니다. 방어 가능한 의식의 대상 영웅이 방어하면 의식도 취소됩니다.\n\n행동 전에 전조와 예상 피해를 확인하세요. 선택하기 전에는 시간이 흐르지 않습니다.",
	"The ember vault could not be read. No saved progress was overwritten.": "잿불 금고를 읽지 못했습니다. 저장된 진행 상황은 덮어쓰지 않았습니다.",
	"The saved journey is damaged and could not be resumed. The vault was kept.": "저장된 여정이 손상되어 이어할 수 없습니다. 금고는 보존했습니다.",
	"Two saves disagree at the same checkpoint. The vault was kept; the journey was not resumed.": "동일한 체크포인트의 두 저장 파일이 서로 다릅니다. 금고는 보존했으며 여정은 불러오지 않았습니다.",
	"Recovered the newer ember vault. An older or conflicting journey was retired to prevent banking it twice.": "최신 잿불 금고를 복구했습니다. 재가 중복 보관되지 않도록 오래되었거나 충돌하는 여정은 제외했습니다.",
	"Recovered the newer ember vault, including its purchased upgrades.": "구매한 영구 강화를 포함해 최신 잿불 금고를 복구했습니다.",
	"Recovered the newer journey and its matching ember vault.": "최신 여정과 이에 맞는 잿불 금고를 복구했습니다.",
	"A damaged or interrupted save was recovered from a complete checkpoint. Some recent actions may need to be repeated.": "손상되거나 중단된 저장을 온전한 체크포인트에서 복구했습니다. 최근 행동 일부는 다시 해야 할 수 있습니다.",
	"Journey and ember vault saved together.": "여정과 잿불 금고를 함께 저장했습니다.",
	"The save data failed validation.": "저장 데이터 검증에 실패했습니다.",
	"The save data failed validation. Changes are still in memory; saving must succeed before closing.": "저장 데이터 검증에 실패했습니다. 변경 사항은 아직 실행 중인 게임에 남아 있습니다. 게임을 닫기 전에 저장을 완료해야 합니다.",
	"The checkpoint could not be written.": "체크포인트를 기록하지 못했습니다.",
	"The checkpoint could not be written. Changes are still in memory; saving must succeed before closing.": "체크포인트를 기록하지 못했습니다. 변경 사항은 아직 실행 중인 게임에 남아 있습니다. 게임을 닫기 전에 저장을 완료해야 합니다.",
	"The previous checkpoint could not be protected.": "이전 체크포인트를 안전하게 보존하지 못했습니다.",
	"The previous checkpoint could not be protected. Changes are still in memory; saving must succeed before closing.": "이전 체크포인트를 안전하게 보존하지 못했습니다. 변경 사항은 아직 실행 중인 게임에 남아 있습니다. 게임을 닫기 전에 저장을 완료해야 합니다.",
	"The checkpoint could not be committed.": "체크포인트 저장을 확정하지 못했습니다.",
	"The checkpoint could not be committed. Changes are still in memory; saving must succeed before closing.": "체크포인트 저장을 확정하지 못했습니다. 변경 사항은 아직 실행 중인 게임에 남아 있습니다. 게임을 닫기 전에 저장을 완료해야 합니다.",
	"Changes are still in memory; saving must succeed before closing.": "변경 사항은 아직 실행 중인 게임에 남아 있습니다. 게임을 닫기 전에 저장을 완료해야 합니다.",
	"ASHEN OATH — The Hollow Crown": "재의 맹세 — 공허한 왕관",
	"Mara": "마라",
	"Ivo": "이보",
	"Sable": "세이블",
	"Ironbound": "철의 맹세자",
	"Ash Cantor": "재의 성가사",
	"Gloam Scout": "황혼 정찰자",
	"Ashen Oath": "재의 맹세",
	"A S H E N   O A T H": "재 의   맹 세",
	"THE HOLLOW CROWN": "공허한 왕관",
	"Red Thread": "붉은 실",
	"Hollow Bell": "공허한 종",
	"Glass Tooth": "유리 이빨",
	"Pilgrim Coin": "순례자의 동전",
	"Cinder Heart": "잿불 심장",
	"Defend": "방어",
	"Oathblade": "맹세의 칼날",
	"Anvil Blow": "모루 강타",
	"Sundering Arc": "분쇄의 참격",
	"Ash Spark": "재의 불꽃",
	"Hollow Hymn": "공허한 찬가",
	"Blood Lantern": "피의 등불",
	"Needle Shot": "바늘 사격",
	"Raking Hook": "갈고리 베기",
	"Last Mercy": "마지막 자비",
	"The Cinder Causeway": "잿불 둑길",
	"The Hollow Orchard": "공허한 과수원",
	"Gate of the Bellkeeper": "종지기의 문",
	"The Salt Reliquary": "소금 성유물당",
	"The Drowned Steps": "물에 잠긴 계단",
	"Court of the Veiled Judge": "가면 심판자의 법정",
	"The Sunless Road": "해 없는 길",
	"The Last Pilgrim": "마지막 순례자",
	"Throne of the Pale Sun": "창백한 태양의 왕좌",
	"The Bellkeeper": "종지기",
	"The Veiled Judge": "가면 심판자",
	"The Pale Sun": "창백한 태양",
	"Cinder Colossus": "잿불 거상",
	"Hollow Adjudicator": "공허한 재판관",
	"Sunless Remnant": "해 없는 잔재",
	"The Uncrowned": "왕관 없는 자",
	"Rooted Legs": "뿌리내린 다리",
	"Offering Arm": "제물의 팔",
	"Crowned Head": "왕관 쓴 머리",
	"Gravewake": "무덤의 파동",
	"Tithe of Iron": "철의 공물",
	"Choir of Ash": "재의 합창",
	"Split Verdict": "이중 판결",
	"Single Verdict": "단일 판결",
	"Second Verdict": "두 번째 판결",
	"Gathering Light": "빛의 응집",
	"Zenith Release": "절정의 방출",
	"Fading Light": "저무는 빛",
	"Solar Brand": "태양의 낙인",
	"CINDER FOREST": "잿불 숲",
	"DROWNED RELIQUARY": "수몰 성유물당",
	"PALE THRONE": "창백한 왕좌",
	"vitality": "생명력",
	"force": "공격력",
	"focus": "집중",
	"slash": "참격",
	"blunt": "타격",
	"arcane": "비전",
	"pierce": "관통",
	"guard": "방어",
	"LOW": "하단",
	"MID": "중단",
	"HIGH": "상단",
	"SEVERED": "절단됨",
	"BROKEN": "붕괴됨",
	"SEVER": "절단",
	"BREAK": "붕괴",
	"EXPOSED": "노출",
	"FALLEN": "쓰러짐",
	"ACTED": "행동 완료",
	"READY": "행동 가능",
	"NO TARGET": "대상 없음",
	"WARD": "완전 방어",
	"incoming": "공격 예고",
	"staggered": "위력 감소",
	"cancelled": "취소됨",
	"warded": "완전 방어",
	"missed": "대상 소멸",
	"none": "없음",
	"Waiting": "대기 중",
	"title": "시작",
	"map": "지도",
	"battle": "전투",
	"boss": "군주",
	"reward": "보상",
	"event": "만남",
	"camp": "야영",
	"relic": "유물",
	"victory": "승리",
	"defeat": "패배",
	"Road": "길",
	"Choice": "선택",
	"None yet": "아직 없음",
	"Muted": "음소거",
	"Sound": "소리 켜짐",
	"idle": "대기",
	"walk": "걷기",
	"attack": "공격",
	"hurt": "피격",
	"death": "쓰러짐",
	"down": "아래",
	"left": "왼쪽",
	"right": "오른쪽",
	"up": "위",
	"LOOP": "반복",
	"ONE SHOT": "한 번 재생",
	"impact": "타격",
	"hit": "타격",
	"+2 damage on every attack": "모든 공격 피해 +2",
	"Restore 3 party HP after each round": "매 라운드 종료 후 아군 전체 체력 3 회복",
	"+1 shield damage when exploiting a weakness": "약점 공격 시 방어막 피해 +1",
	"+8 gold after every battle": "전투 승리마다 금화 +8",
	"Defend restores 3 extra HP": "방어 시 체력 3 추가 회복",
	"The oath is sworn. Nine crossings stand between you and the last sun.": "맹세를 세웠다. 마지막 태양까지 아홉 갈림길이 남았다.",
	"Halve incoming damage this round; cancel a wardable rite targeting this hero. Restore 2 focus and 3 HP.": "이번 라운드 받는 피해를 절반으로 줄이고, 자신을 겨눈 방어 가능한 의식을 취소합니다. 집중 2, 체력 3을 회복합니다.",
	"14 slash damage. Exploit SLASH weakness to remove 2 shields.": "참격 피해 14. 참격 약점에 적중하면 방어막 2를 깎습니다.",
	"12 blunt damage. Remove 1 extra shield.": "타격 피해 12. 방어막 1을 추가로 깎습니다.",
	"24 slash damage. +8 damage against a broken part.": "참격 피해 24. 붕괴된 부위에 피해 8을 추가합니다.",
	"13 arcane damage. Exploit ARCANE weakness to remove 2 shields.": "비전 피해 13. 비전 약점에 적중하면 방어막 2를 깎습니다.",
	"10 arcane damage. Remove 2 extra shields.": "비전 피해 10. 방어막 2를 추가로 깎습니다.",
	"21 arcane damage. Restore 7 HP to every living ally.": "비전 피해 21. 살아 있는 아군 전체의 체력을 7 회복합니다.",
	"13 pierce damage. Exploit PIERCE weakness to remove 2 shields.": "관통 피해 13. 관통 약점에 적중하면 방어막 2를 깎습니다.",
	"10 slash damage. Remove 1 extra shield.": "참격 피해 10. 방어막 1을 추가로 깎습니다.",
	"23 pierce damage. +10 damage against a broken part.": "관통 피해 23. 붕괴된 부위에 피해 10을 추가합니다.",
	"Face a sovereign. Sever its limbs to silence its rites.": "군주와 맞섭니다. 부위를 절단해 의식을 봉쇄하세요.",
	"Challenge a god-fragment. Earn gold, essence and a chosen reward.": "신의 파편에 도전합니다. 금화와 재를 얻고 보상을 선택합니다.",
	"Rest by a dying flame. Recover the party or sharpen your weapons.": "희미한 불가에서 쉽니다. 일행을 회복하거나 무기를 강화합니다.",
	"An oath waits to be answered. Choose its price and its consequence.": "대답을 기다리는 맹세가 있습니다. 대가와 결과를 선택하세요.",
	"Search a silent shrine for a relic that lasts this run.": "고요한 성소에서 이번 여정에 쓸 유물을 찾습니다.",
	"Hunt a god-fragment": "신의 파편 사냥",
	"Rest at the ember camp": "잿불 야영지에서 휴식",
	"Meet the oathless pilgrim": "맹세 없는 순례자와 만남",
	"Enter the relic shrine": "유물 성소에 입장",
	"Choose an available path on the map.": "지도에서 이동할 수 있는 길을 선택하세요.",
	"Begin a run before entering battle.": "새 여정을 시작한 뒤 전투에 들어가세요.",
	"Finish the current choice before entering battle.": "현재 선택을 마친 뒤 전투에 들어가세요.",
	"A prayer trapped inside bronze": "청동 안에 갇힌 기도",
	"Mercy has forgotten its name": "자비는 제 이름을 잊었다",
	"The final light demands a sacrifice": "마지막 빛은 희생을 요구한다",
	"A cruel oath is remembered: negative karma gives every enemy part +1 shield.": "잔혹한 맹세의 대가: 업보가 음수이므로 적의 모든 부위에 방어막이 1 추가됩니다.",
	"There is no battle in progress.": "진행 중인 전투가 없습니다.",
	"Choose a hero.": "영웅을 선택하세요.",
	"That hero cannot act this round.": "이 영웅은 이번 라운드에 행동할 수 없습니다.",
	"Choose an available skill.": "사용할 수 있는 기술을 선택하세요.",
	"Not enough focus for that skill.": "이 기술을 쓰기에는 집중이 부족합니다.",
	"Choose a part that has not been severed.": "아직 절단되지 않은 부위를 선택하세요.",
	" · WEAKNESS": " · 약점",
	"Blood Lantern restores 7 HP to every living ally.": "피의 등불: 살아 있는 아군 전체의 체력을 7 회복합니다.",
	"There is no round to end.": "종료할 라운드가 없습니다.",
	"The oath falls silent": "맹세가 침묵한다",
	"No attack is prepared.": "예고된 공격이 없습니다.",
	"Source severed. This rite is cancelled.": "공격 부위가 절단되어 이 의식이 취소됩니다.",
	"Its fixed target has fallen. This rite will not retarget.": "지정된 대상이 쓰러졌습니다. 이 의식은 다른 대상을 노리지 않습니다.",
	"Defend halves damage to that hero.": "방어하면 해당 영웅이 받는 피해가 절반이 됩니다.",
	"guarded": "방어 중",
	"WEAKNESS": "약점",
	"Hits every living hero": "살아 있는 모든 영웅에게",
	"Second Verdict marks one hero, who can Defend to cancel that rite. Next round: Single Verdict.": "두 번째 판결은 한 영웅을 겨눕니다. 대상이 방어하면 의식이 취소됩니다. 다음 라운드: 단일 판결.",
	"One source acts. Next round: Split Verdict adds Second Verdict from a second intact source if one remains. Its marked hero can Defend to cancel that rite.": "한 부위가 공격합니다. 다음 라운드의 이중 판결은 온전한 다른 부위가 있으면 두 번째 판결을 추가합니다. 대상 영웅이 방어하면 추가 의식이 취소됩니다.",
	"Only one source remains. Second Verdict cannot form. Next round: Single Verdict.": "공격 부위가 하나만 남아 두 번째 판결이 발생하지 않습니다. 다음 라운드: 단일 판결.",
	"Next round: Split Verdict, but only one source remains. Second Verdict cannot form.": "다음 라운드: 이중 판결. 공격 부위가 하나만 남아 두 번째 판결은 발생하지 않습니다.",
	"Next round: Zenith Release adds a second source if one remains. Its marked hero can Defend to cancel it.": "다음 라운드의 절정의 방출은 온전한 다른 부위가 있으면 공격을 추가합니다. 대상 영웅이 방어하면 추가 의식이 취소됩니다.",
	"Two sources can strike. The hero marked by Solar Brand can Defend to cancel that rite.": "두 부위가 공격할 수 있습니다. 태양의 낙인이 겨눈 영웅이 방어하면 그 의식이 취소됩니다.",
	"Recovery: one source attacks at half its usual strength. Next round: Gathering Light.": "회복기: 한 부위가 평소의 절반 위력으로 공격합니다. 다음 라운드: 빛의 응집.",
	"Next round: Zenith Release. Only one source remains, so no second rite can form.": "다음 라운드: 절정의 방출. 공격 부위가 하나만 남아 추가 의식이 발생하지 않습니다.",
	"Only one source remains. Solar Brand cannot form. Next round: Fading Light.": "공격 부위가 하나만 남아 태양의 낙인이 발생하지 않습니다. 다음 라운드: 저무는 빛.",
	"No second source remains; the additional rite is silenced.": "두 번째 공격 부위가 없어 추가 의식이 봉쇄됩니다.",
	"A god is unmade": "신이 무너졌다",
	"Mend the oath": "맹세를 기우기",
	"Restore 24 HP and 3 focus to all heroes. Revive fallen allies.": "아군 전체 체력 24, 집중 3 회복. 쓰러진 아군도 부활합니다.",
	"Take the tribute": "공물 거두기",
	"Gain 25 gold and 2 extra essence.": "금화 25와 재 2를 추가로 얻습니다.",
	"Claim a relic": "유물 획득",
	"Gain a random unclaimed relic for the rest of this run.": "아직 없는 유물 하나를 무작위로 얻어 이번 여정 동안 사용합니다.",
	"Keep the relic echo": "유물의 잔향 간직하기",
	"All relics are claimed. Gain 4 unbanked ash instead.": "모든 유물을 얻었습니다. 대신 여정의 재 4를 얻습니다.",
	"Choose one of the offered rewards.": "제시된 보상 중 하나를 선택하세요.",
	"A flame that remembers": "기억하는 불꽃",
	"The fire bends toward your hands. You may tend your wounds or temper your resolve.": "불꽃이 손끝으로 기울어집니다. 상처를 돌보거나 결의를 벼릴 수 있습니다.",
	"Rest together": "함께 쉬기",
	"Heal 30 HP, restore all focus, and revive fallen allies.": "체력 30과 집중 전부 회복. 쓰러진 아군도 부활합니다.",
	"Temper the blades": "칼날 벼리기",
	"Spend 15 gold. All attacks gain +2 damage this run.": "금화 15 소비. 이번 여정의 모든 공격 피해가 2 증가합니다.",
	"The shrine of small mercies": "작은 자비의 성소",
	"Something ancient has been left here for the next foolish pilgrim.": "다음 어리석은 순례자를 위해 오래된 무언가가 남겨져 있습니다.",
	"Take its relic": "유물 가져가기",
	"Receive a random unclaimed relic. Gain 1 karma.": "아직 없는 유물 하나를 무작위로 얻고 업보가 1 증가합니다.",
	"Leave an offering": "공물 남기기",
	"Spend 10 gold. Gain 5 essence and heal the party by 12 HP.": "금화 10 소비. 재 5를 얻고 아군 전체 체력을 12 회복합니다.",
	"The oathless pilgrim": "맹세 없는 순례자",
	"A pilgrim carries a bell with no tongue. 'A little warmth,' they ask, 'and I will tell the dark your names.'": "순례자가 울리지 않는 종을 들고 있습니다. “온기를 조금 나눠 주시오. 어둠에 당신들의 이름을 전하리다.”",
	"Offer shelter": "쉼터 내어주기",
	"Spend 12 gold. Heal 18 HP, revive fallen allies, and gain 2 karma.": "금화 12 소비. 체력 18 회복, 쓰러진 아군 부활, 업보 2 증가.",
	"Share your ember": "잿불 나누기",
	"Each living hero loses 8 HP (cannot kill). Gain a relic and 3 essence.": "살아 있는 영웅마다 체력 8 감소(사망하지 않음). 유물 하나와 재 3 획득.",
	"Seize their supplies": "물자 빼앗기",
	"+24 gold, -2 karma. Negative karma adds 1 shield to enemy parts.": "금화 +24, 업보 -2. 업보가 음수이면 적의 모든 부위에 방어막이 1 추가됩니다.",
	"Receive the relic echo": "유물의 잔향 받기",
	"All relics are claimed. Gain 4 unbanked ash and 1 karma.": "모든 유물을 얻었습니다. 여정의 재 4를 얻고 업보가 1 증가합니다.",
	"Each living hero loses 8 HP (cannot kill). All relics claimed: gain 7 unbanked ash instead.": "살아 있는 영웅마다 체력 8 감소(사망하지 않음). 모든 유물을 얻었으므로 대신 여정의 재 7 획득.",
	"Choose an available event option.": "현재 가능한 선택지를 고르세요.",
	"The dawn belongs to no god": "새벽은 어느 신의 것도 아니다",
	"Nine crossings. Three fallen sovereigns. The oath is fulfilled. +10 essence.": "아홉 갈림길. 쓰러진 세 군주. 맹세를 이루었습니다. 재 +10.",
	"Every relic is claimed. Its echo becomes 4 essence.": "모든 유물을 얻었습니다. 그 잔향이 재 4로 바뀝니다.",
	"Permanent upgrades are available between runs.": "영구 강화는 여정과 여정 사이에 할 수 있습니다.",
	"That upgrade is unavailable or already at its maximum rank.": "사용할 수 없는 강화이거나 이미 최고 단계입니다.",
	"Not enough banked essence.": "보관된 재가 부족합니다.",
	"The ember vault could not be saved.": "잿불 금고를 저장하지 못했습니다.",
	"YOUR REWARD IS READY": "보상을 선택할 수 있습니다",
	"FINAL STRIKE": "마지막 일격",
	"SPACE / ESC / SKIP": "SPACE / ESC / 건너뛰기",
	"V  Sprites": "V  캐릭터",
	"H  Guide": "H  도움말",
	"M  Muted": "M  음소거",
	"M  Sound": "M  소리 켜짐",
	"A MEMORY WORTH KEEPING": "간직할 만한 기억",
	"Choose recovery, tribute, or a relic for this journey.": "이번 여정을 위해 회복, 공물, 유물 중 하나를 선택하세요.",
	"The road remembers every choice.": "길은 모든 선택을 기억합니다.",
	"THE GODS LEFT THEIR CROWNS.": "신들은 왕관을 남겼다.",
	"We learned\nto break them.": "우리는 배웠다.\n부수는 법을.",
	"Three wanderers. Nine crossings. One hollow throne.\nRead the omen. Break a defense. Sever the source of its power.": "세 방랑자. 아홉 갈림길. 비어 있는 왕좌.\n전조를 읽고, 방어막을 무너뜨리고, 힘의 근원을 잘라내세요.",
	"BEGIN A NEW CYCLE": "새 여정 시작",
	"REVIEW LAST JOURNEY": "지난 여정 결과 보기",
	"RESUME CURRENT JOURNEY": "현재 여정 이어하기",
	"Original tactical roguelite • mouse or keyboard • no time pressure": "턴제 전술 로그라이트 • 마우스·키보드 지원 • 시간제한 없음",
	"LEAVE THIS JOURNEY?": "이 여정을 떠날까요?",
	"Ending now gives up their remaining actions and resolves the omen. You can still attack or defend first.": "지금 종료하면 남은 행동을 포기하고 예고된 공격이 실행됩니다. 먼저 공격하거나 방어할 수 있습니다.",
	"ESC / KEEP PLAYING": "ESC / 계속하기",
	"ENTER / END ROUND": "ENTER / 라운드 종료",
	"ENTER / NEW CYCLE": "ENTER / 새 여정",
	"Legacy strengthened.": "영구 강화를 마쳤습니다.",
	"HERO > PART > SKILL   /   DAMAGE FORECAST: PART HP": "영웅 > 부위 > 기술 선택 / 예상 피해: 부위 체력",
	"B / VIEW BUILD": "B / 유물·강화 보기",
	"SPACE / END ROUND": "SPACE / 라운드 종료",
	"OMEN CANCELLED": "전조 취소됨",
	"RESOLVE OMEN": "예고된 공격 실행",
	"Sever this source to cancel its attack.": "이 부위를 절단하면 공격이 취소됩니다.",
	"The party is safe this round.": "이번 라운드는 안전합니다.",
	"Break this source to halve its attack.": "이 부위를 붕괴시키면 공격 위력이 절반이 됩니다.",
	"SEVERED / NO ATTACK": "절단됨 / 공격 없음",
	"0 HP / 0 FOCUS (DEFEND)": "체력·집중 손실 0 (방어)",
	"NO LIVING TARGET": "생존 대상 없음",
	"Read the next omen": "다음 전조 확인",
	"Defend halves normal attacks and cancels a wardable rite targeting this hero. The live omen updates after Defend.": "방어는 일반 공격 피해를 절반으로 줄이고, 자신을 겨눈 방어 가능한 의식을 취소합니다. 방어 후 전조가 즉시 갱신됩니다.",
	"YOUR ROAD": "여정의 길",
	"CHECK: PASSED   /   GOLD: HERE   /   CROWN: SOVEREIGN": "체크: 완료 / 금색: 현재 위치 / 왕관: 군주",
	"CHOOSE YOUR NEXT ACT": "다음 행동 선택",
	"THE CROWN IS SILENT": "왕관이 침묵한다",
	"THE ASH REMEMBERS": "재는 기억한다",
	"The wanderers leave the throne empty. Beyond the mist, another road begins.": "방랑자들은 왕좌를 비워 둡니다. 안개 너머에서 또 다른 길이 시작됩니다.",
	"Your journey ends here. Its lessons remain. Spend your ash on a lasting legacy, then return stronger.": "여정은 여기서 끝납니다. 배운 것은 남습니다. 재로 영구 강화한 뒤 더 강해져 돌아오세요.",
	"RETURN TO THE EMBER": "잿불로 돌아가기",
	"THE ART OF UNMAKING": "신을 무너뜨리는 법",
	"CLOSE GUIDE": "도움말 닫기",
	"MEMORIES OF THIS JOURNEY": "이번 여정의 기억",
	"No relics yet. Win battles or visit a shrine to shape this build.": "아직 유물이 없습니다. 전투에서 승리하거나 성소를 찾아 조합을 완성하세요.",
	"Attack relics are included in damage forecasts. Hollow Bell heals after enemy attacks.": "공격 유물 효과는 예상 피해에 반영됩니다. 공허한 종은 적의 공격 후 회복합니다.",
	"B / ESC / RETURN": "B / ESC / 돌아가기",
	"Earned ash is banked on victory or defeat. Starting a new cycle abandons it.": "여정의 재는 승리하거나 패배하면 보관됩니다. 도중에 새 여정을 시작하면 잃습니다.",
	"Language": "언어",
	"LANGUAGE": "언어",
	"Korean": "한국어",
	"English": "English",
	"LANGUAGE / 한국어": "언어 / 한국어",
	"LANGUAGE / English": "언어 / English",
	"CHARACTER STUDIO  /  GENERATED ART + ANIMATION RIG": "캐릭터 스튜디오 / 생성 원화 + 애니메이션",
	"ESC  Back to game": "ESC  게임으로",
	"THE WANDERERS": "방랑자들",
	"ANIMATION": "애니메이션",
	"R  Reset": "R  초기화",
	"FACING": "방향",
	"P  Pause": "P  일시정지",
	"P  Play": "P  재생",
	"A  Show foot anchors": "A  발 고정점 표시",
	"C  Transparency checker": "C  투명 배경 격자",
	"ARROWS   Move in four directions\nSPACE   Attack     H   Hurt\nK   Death     R   Reset": "방향키   네 방향 이동\nSPACE   공격     H   피격\nK   쓰러짐     R   초기화",
	"Image-generated poses  /  2.5× preview  /  live mesh animation": "생성 원화 포즈 / 2.5배 미리보기 / 실시간 메시 애니메이션",
	"Hold arrow keys to walk": "방향키를 누르면 걷기",
	"Clips hold their foot anchor; movement is controlled separately": "애니메이션은 발 고정점을 유지하며 이동은 별도로 제어됩니다",
	"FOUR DISTINCT FACINGS  /  synchronized frames, no runtime mirroring": "독립된 네 방향 / 프레임 동기화, 실행 중 좌우 반전 없음",
	"Foot anchor  48, 101 px": "발 고정점 48, 101 px",
	"1. Select a hero, then one of the titan's three body parts.\n2. Match a skill's type to the part's weakness to break its shield.\n3. Keep attacking the broken part. Depleting its HP severs it and removes its move.\n4. Each living hero acts once per round. End Round resolves every visible omen.\n5. Defend halves normal damage and cancels a wardable rite marked on that hero.\n6. Between battles, choose relics, rests and moral encounters. Death earns a new beginning; ash upgrades persist.\n\nMouse: click heroes, parts, skills and choices\nKeyboard: 1–3 hero • ↑/↓ target • Q/W/E attack • R guard\nSpace end round • B build / relics • V studio • H guide • M sound • Esc menu\n\nThere are no timers. Skill buttons predict damage and break/sever.\nThe omen updates after break, sever and guard. B shows relic effects.\nYour journey and legacy save after every choice. Resume from the title screen.": "1. 영웅을 고른 뒤 거인의 세 부위 중 하나를 선택하세요.\n2. 기술의 속성을 부위의 약점에 맞추면 방어막을 더 빨리 깎습니다.\n3. 붕괴된 부위를 계속 공격하세요. 체력을 모두 깎으면 절단되어 해당 기술을 봉쇄합니다.\n4. 살아 있는 영웅은 라운드마다 한 번 행동합니다. 라운드 종료 시 표시된 전조가 모두 실행됩니다.\n5. 방어는 일반 피해를 절반으로 줄이고, 자신에게 지정된 방어 가능한 의식을 취소합니다.\n6. 전투 사이에 유물, 휴식, 도덕적 선택을 고르세요. 패배해도 영구 강화는 남습니다.\n\n마우스: 영웅, 부위, 기술, 선택지를 클릭\n키보드: 1–3 영웅 • ↑/↓ 대상 • Q/W/E 공격 • R 방어\nSPACE 라운드 종료 • B 유물·강화 • V 스튜디오 • H 도움말 • M 소리 • ESC 메뉴\n\n시간제한은 없습니다. 기술 버튼에서 예상 피해와 붕괴·절단 여부를 확인하세요.\n전조는 붕괴·절단·방어 후 갱신됩니다. B로 유물 효과를 확인하세요.\n선택할 때마다 여정과 영구 강화가 저장됩니다. 시작 화면에서 이어할 수 있습니다.",
	"Rest together.": "함께 쉬기.",
	"Temper the blades.": "칼날 벼리기.",
	"Take its relic.": "유물 가져가기.",
	"Leave an offering.": "공물 남기기.",
	"Offer shelter.": "쉼터 내어주기.",
	"Share your ember.": "잿불 나누기.",
	"Seize their supplies.": "물자 빼앗기.",
	"Receive the relic echo.": "유물의 잔향 받기.",
}

const TEMPLATES: Array[Array] = [
	["%s defends: incoming damage halved; +2 focus, +%d HP.", "{0} 방어: 받는 피해 절반. 집중 +2, 체력 +{1}."],
	["%s %d/5 · %s\n%s / next run", "{0} {1}/5 · {2}\n{3} / 다음 여정"],
	["%d ash", "재 {0}"],
	["Each rank: %s. Applies to the next new journey. Rank %d of 5.", "단계마다 {0}. 다음 새 여정부터 적용됩니다. 현재 {1}/5단계."],
	["%s\n+%d HP / +%d Focus", "{0}\n체력 +{1} / 집중 +{2}"],
	["%s  %s\n%s", "{0}  {1}\n{2}"],
	["Crossing %d: %s.", "갈림길 {0}: {1}."],
	["%s rises. Break a part's shields, then strike its exposed flesh to sever it.", "{0} 등장. 부위의 방어막을 붕괴시킨 뒤 노출된 부위를 공격해 절단하세요."],
	["%s defends: normal attacks halved, wardable rites cancelled; +2 focus, +%d HP.", "{0} 방어: 일반 피해 절반, 방어 가능한 의식 취소. 집중 +2, 체력 +{1}."],
	["BREAK! %s is exposed. The next strike can sever it.", "붕괴! {0} 노출. 이후 공격으로 체력을 모두 깎으면 절단됩니다."],
	["%s uses %s on %s: %d damage%s.", "{0} → {2}: {1}, 피해 {3}{4}."],
	["SEVERED: %s. %s is silenced forever. %d rupture damage.", "절단: {0}. {1} 영구 봉쇄. 파열 피해 {2}."],
	["The party falls. %d essence returns to the ember vault.", "일행이 쓰러졌습니다. 재 {0}가 잿불 금고에 보관됩니다."],
	["%s wards this rite: no damage or focus loss", "{0} 완전 방어: 체력·집중 손실 없음"],
	["%s -%d HP / -%d focus / guarded", "{0} 체력 -{1} / 집중 -{2} / 방어 중"],
	["%s -%d HP / -%d focus", "{0} 체력 -{1} / 집중 -{2}"],
	["%s -%d HP / guarded", "{0} 체력 -{1} / 방어 중"],
	["%s -%d HP / -%d MP", "{0} 체력 -{1} / 집중 -{2}"],
	["%s -%d HP", "{0} 체력 -{1}"],
	["Break %s to halve; sever it to cancel.", "{0} 붕괴 시 위력 절반, 절단 시 취소."],
	["%s: Defend cancels this rite. %s", "{0}: 방어하면 이 의식을 취소합니다. {1}"],
	["Break %s to halve; sever it to cancel. Defend halves damage to that hero.", "{0} 붕괴 시 위력 절반, 절단 시 취소. 방어하면 해당 영웅이 받는 피해가 절반이 됩니다."],
	["WARD RITE + HALVE / +%d HP", "의식 취소·피해 절반 / 체력 +{0}"],
	["HALVE INCOMING / +%d HP", "피해 절반 / 체력 +{0}"],
	["WARD RITE / +%d HP", "의식 취소 / 체력 +{0}"],
	["-%d SHIELD", "방어막 -{0}"],
	["%d DMG / %s", "피해 {0} / {1}"],
	["%s fails. Its source was severed.", "{0} 취소. 공격 부위가 절단되었습니다."],
	["%s fails. Its fixed target has fallen; it does not retarget.", "{0} 실패. 지정된 대상이 쓰러져 다른 대상을 공격하지 않습니다."],
	["%s is staggered: %s deals half damage.", "{0} 붕괴: {1} 피해가 절반이 됩니다."],
	["%s wards %s completely.", "{0}: {1} 완전 방어."],
	["%s strikes %s for %d (guarded).", "{0} → {1}: 피해 {2} (방어 중)."],
	["%s strikes %s for %d.", "{0} → {1}: 피해 {2}."],
	["%s has fallen. Rest or a healing reward can revive them.", "{0} 쓰러짐. 휴식 또는 회복 보상으로 부활할 수 있습니다."],
	["Hits every living hero for %d damage. Break to halve it; sever to cancel it.", "살아 있는 모든 영웅에게 피해 {0}. 공격 부위 붕괴 시 위력 절반, 절단 시 취소."],
	["Hits every living hero and drains 1 focus from unguarded heroes for %d damage. Break to halve it; sever to cancel it.", "살아 있는 모든 영웅에게 피해 {0}. 방어하지 않은 영웅은 집중 1 감소. 공격 부위 붕괴 시 위력 절반, 절단 시 취소."],
	["Targets %s for %d damage. Break to halve it; sever to cancel it.", "{0}에게 피해 {1}. 공격 부위 붕괴 시 위력 절반, 절단 시 취소."],
	["Targets %s for %d damage and drains 1 focus. %s can Defend to cancel this rite. Break %s to halve it; sever to cancel it.", "{0}에게 피해 {1}, 집중 1 감소. {2}: 방어하면 이 의식 취소. {3} 붕괴 시 위력 절반, 절단 시 취소."],
	["Targets %s for %d damage. %s can Defend to cancel this rite. Break %s to halve it; sever to cancel it.", "{0}에게 피해 {1}. {2}: 방어하면 이 의식 취소. {3} 붕괴 시 위력 절반, 절단 시 취소."],
	["Targets %s", "{0} 대상"],
	["Round %d · %s prepares %s.", "{0}라운드 · {1}: {2} 예고."],
	["%s falls. +%d gold, +%d essence.", "{0} 격파. 금화 +{1}, 재 +{2}."],
	["Reward: %s.", "보상: {0}."],
	["You need %d gold for that choice.", "이 선택에는 금화 {0}가 필요합니다."],
	["Relic claimed: %s. %s.", "유물 획득: {0}. {1}."],
	["Permanent upgrade: %s, rank %d.", "영구 강화: {0}, {1}단계."],
	["CYCLE %d  /  ASH %d  /  GOLD %d  /  KARMA %+d", "{0}회차 / 보관된 재 {1} / 금화 {2} / 업보 {3}"],
	["LEGACY  /  %d ASH", "영구 강화 / 보관된 재 {0}"],
	["%s +%d · %d ash", "{0} +{1} · 재 {2}"],
	["%d HEROES CAN STILL ACT", "아직 {0}명이 행동할 수 있습니다"],
	["Starting again replaces this journey. Your %d unbanked ash will be lost. Your existing legacy upgrades and banked ash stay with you.", "새 여정을 시작하면 현재 여정과 미보관 재 {0}를 잃습니다. 기존 영구 강화와 보관된 재는 유지됩니다."],
	["ROUND %d  /  %d ACTIONS LEFT  /  %s", "{0}라운드 / 남은 행동 {1} / {2}"],
	["TITAN  %d / %d", "거인 체력 {0} / {1}"],
	["SHIELD %d", "방어막 {0}"],
	["%s · %s\n%s  |  HP %d/%d\nWeak: %s", "{0} · {1}\n{2} | 체력 {3}/{4}\n약점: {5}"],
	["Severing removes %s from future rounds.", "절단하면 이후 라운드에서 {0} 봉쇄."],
	["OMEN %d / %s\n%s", "전조 {0} / {1}\n{2}"],
	["%d  %s  /  %s\nHP %d/%d   MP %d/%d  %s", "{0}  {1} / {2}\n체력 {3}/{4} 집중 {5}/{6} {7}"],
	["%s  %s\n%s · %d MP\n%s", "{0}  {1}\n{2} · 집중 {3}\n{4}"],
	["Forecast: %d titan HP, including any sever rupture. Part damage is shown on the button.", "예상 거인 체력 피해: {0}(절단 파열 포함). 버튼에는 부위 피해가 표시됩니다."],
	["OMEN / %s", "전조 / {0}"],
	["%s: DEFEND CANCELS THIS RITE", "{0}: 방어 시 의식 취소"],
	["NEXT / %s", "다음 / {0}"],
	["+%d GOLD / +%d UNBANKED ASH", "금화 +{0} / 여정의 재 +{1}"],
	["THE PILGRIMAGE / %s", "순례 / {0}"],
	["Crossing %d of 9. Rest when wounded, gather relics, and choose what kind of memory you leave behind.", "아홉 갈림길 중 {0}번째. 다쳤다면 쉬고, 유물을 모으며, 어떤 기억을 남길지 선택하세요."],
	["A MOMENT ON THE ROAD / %s", "길 위의 한순간 / {0}"],
	["%s  %d/%d HP", "{0} 체력 {1}/{2}"],
	["FOCUS %d/%d", "집중 {0}/{1}"],
	["RELICS / %s", "유물 / {0}"],
	["Titans overcome: %d   •   Karma: %+d", "쓰러뜨린 군주: {0} • 업보: {1}"],
	["ASH RECOVERED  +%d  /  VAULT  %d", "회수한 재 +{0} / 금고 {1}"],
	["ASH / %d banked · %d earned this journey\nEarned ash is banked on victory or defeat. Starting a new cycle abandons it.\nTEMPERED WEAPONS / +%d damage to every attack", "재 / 보관 {0} · 이번 여정 {1}\n여정의 재는 승리·패배 시 보관됩니다. 도중에 새 여정을 시작하면 잃습니다.\n무기 강화 / 모든 공격 피해 +{2}"],
	["Animation event: %s  /  frame 05  /  foot position unchanged", "애니메이션 이벤트: {0} / 05 프레임 / 발 위치 고정"],
	["%s  /  %s  /  %02d OF %02d", "{0} / {1} / {2} / {3} 프레임"],
	["%d FPS  ·  %s", "{0} FPS · {1}"],
	["Speed  %s×", "속도 {0}배"],
	["%d  %s  /  %s", "{0}  {1} / {2}"],
	["%02d  /  %s", "{0} / {1}"],
	["%d / %s", "{0} / {1}"],
]

## Change only in-memory display language. Persist explicitly with save_preferences().
static func set_language(value: String) -> bool:
	var normalized: String = value.to_lower().replace("_", "-").get_slice("-", 0)
	if normalized not in SUPPORTED_LANGUAGES:
		return false
	language = normalized
	_cache.clear()
	_missing.clear()
	return true

static func get_language() -> String:
	return language

static func load_preferences(path: String = PREFERENCES_PATH) -> bool:
	# Fresh installs and invalid files always use Korean. No journey/meta file is read.
	set_language("ko")
	tooltips_enabled = true
	var preferences: ConfigFile = ConfigFile.new()
	if preferences.load(path) != OK:
		return false
	var tips: Variant = preferences.get_value("display", "tooltips", true)
	tooltips_enabled = tips if tips is bool else true
	var saved: Variant = preferences.get_value("display", "language", "ko")
	return set_language(saved) if saved is String else false

static func save_preferences(path: String = PREFERENCES_PATH) -> bool:
	# Separate atomic display preferences cannot overwrite journey or legacy data.
	if path.get_file() in ["ashen_oath_meta.json", "ashen_oath_journey.save"]:
		return false
	var preferences: ConfigFile = ConfigFile.new()
	preferences.set_value("display", "language", language)
	preferences.set_value("display", "tooltips", tooltips_enabled)
	var temporary: String = path + ".tmp"
	if preferences.save(temporary) != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK

static func translate(source: String) -> String:
	if language == "en" or source.is_empty():
		return source
	_prepare_catalog()
	if _cache.has(source):
		return _cache[source]
	var result: Dictionary = _resolve(source, 0)
	for missing: String in result.missing:
		_missing[missing] = true
	if _cache.size() >= 4096:
		_cache.clear()
	_cache[source] = result.text
	return result.text

static func t(source: String) -> String:
	return translate(source)

## Sorted unresolved English leaves for source/UI coverage checks, not user-facing text.
static func missing_sources() -> Array[String]:
	var result: Array[String] = []
	result.assign(_missing.keys())
	result.sort()
	return result

static func clear_diagnostics() -> void:
	_missing.clear()
	_cache.clear()

static func _prepare_catalog() -> void:
	if _ready_catalog:
		return
	for source: String in CATALOG:
		_upper[source.to_upper()] = CATALOG[source]
	# Combined omen descriptions are generated by the canonical model and can also
	# occur in older saves. Decompose their grammar before the simple templates.
	_add_pattern("(?s)^(.+?) Second source: (.+?) from (.+?)\\. (.+)$", "{0}\n추가 부위: {2} / {1}. {3}")
	_add_pattern("(?s)^(.+) No second source remains; the additional rite is silenced\\.$", "{0} 두 번째 공격 부위가 없어 추가 의식이 봉쇄됩니다.")
	_add_pattern("(?s)^(.+?Break to halve it; sever to cancel it\\.) (Split Verdict|Single Verdict|Gathering Light|Zenith Release|Fading Light): (.+)$", "{0}\n{1}: {2}")
	# Most literal content wins, preventing a generic numeric heading from
	# swallowing a longer combat/card template.
	var ordered: Array[Array] = TEMPLATES.duplicate()
	ordered.sort_custom(func(a: Array, b: Array) -> bool: return _literal_weight(a[0]) > _literal_weight(b[0]))
	for entry: Array in ordered:
		var pattern: String = "(?s)^"
		var source: String = entry[0]
		var cursor: int = 0
		var specifier: RegEx = RegEx.create_from_string("%[+0-9.]*[dsf]")
		for match_value: RegExMatch in specifier.search_all(source):
			pattern += _escape_regex(source.substr(cursor, match_value.get_start() - cursor))
			var token: String = match_value.get_string()
			pattern += "([+-]?[0-9]+)" if token.ends_with("d") else ("([+-]?[0-9]+(?:\\.[0-9]+)?)" if token.ends_with("f") else "(.*?)")
			cursor = match_value.get_end()
		pattern += _escape_regex(source.substr(cursor)) + "$"
		_add_pattern(pattern, entry[1], source.contains("\n"))
	_ready_catalog = true

static func _literal_weight(source: String) -> int:
	var pattern: RegEx = RegEx.create_from_string("%[+0-9.]*[dsf]")
	return pattern.sub(source, "", true).length()

static func _add_pattern(pattern: String, translated: String, multiline: bool = false) -> void:
	var regex: RegEx = RegEx.new()
	var error: Error = regex.compile(pattern)
	assert(error == OK, "Invalid localization pattern: " + pattern)
	_compiled.append({"regex": regex, "target": translated, "multiline": multiline})

static func _escape_regex(value: String) -> String:
	var result: String = ""
	for character: String in value:
		if character in "\\.^$|?*+()[]{}":
			result += "\\"
		result += character
	return result

static func _result(text: String, missing: Array[String] = []) -> Dictionary:
	return {"text": text, "missing": missing}

static func _resolve(source: String, depth: int) -> Dictionary:
	if source.is_empty():
		return _result(source)
	if CATALOG.has(source):
		return _result(CATALOG[source])
	if _upper.has(source.to_upper()):
		return _result(_upper[source.to_upper()])
	if depth > 18:
		return _result(source, [source])
	for rule: Dictionary in _compiled:
		if source.contains("\n") and not bool(rule.multiline): continue
		var matched: RegExMatch = rule.regex.search(source)
		if matched == null:
			continue
		var result: String = rule.target
		var unresolved: Array[String] = []
		for index: int in range(1, matched.get_group_count() + 1):
			var nested: Dictionary = _resolve(matched.get_string(index), depth + 1)
			result = result.replace("{" + str(index - 1) + "}", nested.text)
			unresolved.append_array(nested.missing)
		return _result(result, unresolved)
	# Boundary-only composition supports existing joined logs, cards, names and
	# status headings. It never replaces words inside an unrecognized sentence.
	for delimiter: String in ["\n", "  /  ", " / ", " · ", " | ", ", ", " + ", ": "]:
		if not source.contains(delimiter):
			continue
		var translated_parts: PackedStringArray = []
		var unresolved: Array[String] = []
		for piece: String in source.split(delimiter):
			var nested: Dictionary = _resolve(piece, depth + 1)
			translated_parts.append(nested.text)
			unresolved.append_array(nested.missing)
		return _result(delimiter.join(translated_parts), unresolved)
	# Preserve leading/trailing padding on captured suffixes (e.g. WEAKNESS).
	var trimmed: String = source.strip_edges()
	if source != trimmed:
		var nested: Dictionary = _resolve(trimmed, depth + 1)
		var beginning: int = source.find(trimmed) if not trimmed.is_empty() else 0
		return _result(source.substr(0, beginning) + nested.text + source.substr(beginning + trimmed.length()), nested.missing)
	# Key legends and measurements are intentionally language-neutral.
	if source in ["Q", "W", "E", "R", "H", "M", "B", "V", "K", "P", "C", "A", "ESC", "SPACE", "ENTER", "FPS", "px", "English"]:
		return _result(source)
	var latin: RegEx = RegEx.create_from_string("[A-Za-z]")
	return _result(source, [source]) if latin.search(source) != null else _result(source)

## Both language modes can render Hangul in the language menu and tooltips.
static func load_display_font() -> Font:
	var korean: Font = load(FONT_PATH)
	if language == "ko": return korean
	var latin: Font = load("res://assets/fonts/PixelifySans.ttf")
	latin.fallbacks = [korean]
	return latin
