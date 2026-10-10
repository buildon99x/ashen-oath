extends RefCounted
## UI for the saved Ashen provisional profile. Copy is deliberately bilingual.
const L = preload("res://localization.gd")
static func loc(en: String, ko: String) -> String:
	return ko if L.get_language()=="ko" else en
static func label(g, text: String, pos: Vector2, size: int, color: Color, width: float) -> Label:
	var node: Label = g.label_at("",pos,size,color,width)
	node.text = text
	return node
static func paragraph(g, text: String, pos: Vector2, width: float, size: int = 17, color: Color = Color("e4e5db")) -> Label:
	var node: Label = g.paragraph("",pos,width,size,color)
	node.text = text
	return node
static func button(g, text: String, area: Rect2, action: Callable, active: bool = false, disabled: bool = false, size: int = 16) -> Button:
	var node: Button = g.button("",area,action,active,disabled,false,size)
	node.text = g.wrap_button(text,area.size.x-34,size)
	return node

static func draw(g) -> void:
	var m = g.model
	var hero: Dictionary = m.heroes[g.selected_hero]
	var current: int = m.active_actor()
	var actor_name: String = loc("ENEMY","적") if current<0 else g.display_text(str(m.heroes[current].name))
	var is_counter: bool = m.run.combat.mode=="counter"
	label(g,g.display_text(str(m.boss.name)),Vector2(40,105),27,g.PALE,480)
	label(g,"HP %d / %d" % [m.boss.hp,m.boss.max_hp],Vector2(530,105),18,g.GOLD,490)
	label(g,loc("ASHEN TEMPORARY RULES / ORIGINAL PARITY UNVERIFIED","ASHEN 임시 규칙 / 원작 동일성 미검증"),Vector2(40,146),13,g.TEAL,620)
	label(g,loc("ROUND %d · %s %s","라운드 %d · %s %s") % [m.round_number,actor_name,loc("COUNTER","반격") if is_counter else loc("TURN","차례")],Vector2(700,146),14,g.GOLD,650)
	var threat: Dictionary = m.preview_intent()
	label(g,loc("OMEN / HEIGHT","전조 / 높이"),Vector2(40,187),17,g.TEAL,290)
	for i in range(threat.attacks.size()):
		var attack: Dictionary = threat.attacks[i]
		var y: int = 220+i*112
		var omen_label: Label=label(g,g.display_text(str(attack.source))+" / "+g.display_text(str(m.parts[int(attack.part)].level)),Vector2(40,y),18,g.PALE,290)
		omen_label.tooltip_text=g.display_text(str(attack.name))
		var lines: Array[String] = []
		for value: Variant in attack.targets:
			var target: int = int(value)
			lines.append("%s  HP -%d%s" % [g.display_text(str(m.heroes[target].name)),attack.losses[target],loc(" / PARRY"," / 패링") if target in attack.get("parried",[]) else ""])
		if m.run.combat.enemy_resolved: lines=[loc("ENEMY ACTION ALREADY RESOLVED","이번 적 행동 완료")]
		elif attack.status=="cancelled": lines=[loc("SOURCE STOPPED / NO ATTACK","부위 무력화 / 공격 취소")]
		elif attack.status=="warded" and not threat.counters.is_empty(): lines.append(loc("PARRY → FREE COUNTER","패링 → 무료 반격"))
		paragraph(g,"\n".join(lines),Vector2(40,y+28),290,17,g.omen_shade(str(attack.status)))
	paragraph(g,loc("Break blocks that limb through next enemy phase. Sever removes its move. Guard halves; Parry matches height.","붕괴한 부위는 적 행동 때 공격하지 못합니다. 절단은 기술을 영구 제거합니다. 방어는 피해 절반, 패링은 높이를 맞추세요."),Vector2(40,435),290,15,g.TEAL)
	var names: Array[String] = []
	for value: Variant in m.run.combat.queue:
		var index: int = int(value)
		names.append(loc("ENEMY","적") if index<0 else g.display_text(str(m.heroes[index].name)))
	label(g," → ".join(names),Vector2(380,476),16,g.TEAL,650)
	for i in range(m.parts.size()):
		var p: Dictionary = m.parts[i]
		var status: String = loc("SEVERED","절단됨") if p.severed else (loc("SEVER READY","절단 가능") if p.broken and int(p.hp)==0 else (loc("BROKEN","붕괴") if p.broken else loc("SHIELD %d","방어막 %d") % int(p.shield)))
		var copy: String = "%s · %s\n%s / HP %d/%d\n%s %s" % [g.display_text(str(p.level)),g.display_text(str(p.name)),status,p.hp,p.max_hp,loc("Weak:","약점:"),g.display_text(str(p.weakness))]
		button(g,copy,Rect2(1080,182+i*118,320,106),g.select_part.bind(i),g.selected_part==i,p.severed,16)
		g.meter(Rect2(1100,278+i*118,280,4),float(p.hp)/maxf(1,float(p.max_hp)),g.TEAL)
	button(g,loc("B / BUILD & RELICS","B / 빌드·유물"),Rect2(1080,538,320,36),func(): g.build_open=true; g.refresh(),false,false,14)
	button(g,"[  − EP",Rect2(40,530,105,38),g.change_boost.bind(-1),false,current!=g.selected_hero or is_counter or int(hero.boost)<=0,14)
	button(g,"]  + EP",Rect2(150,530,105,38),g.change_boost.bind(1),false,current!=g.selected_hero or is_counter or int(hero.boost)>=mini(3,int(hero.ep)),14)
	label(g,loc("BOOST %d / EP %d","부스트 %d / EP %d") % [hero.boost,hero.ep],Vector2(269,535),17,g.GOLD,235)
	button(g,loc("T / PARRY · 5 MP","T / 패링 · MP 5"),Rect2(515,530,237,38),g.provisional_special.bind("parry"),false,current!=g.selected_hero or is_counter or int(hero.mp)<5,14)
	var selected: Dictionary = m.parts[g.selected_part]
	var sever_button: Button=button(g,loc("F / SEVER · 1 EP","F / 절단 · EP 1"),Rect2(763,530,264,38),g.provisional_special.bind("sever"),false,current!=g.selected_hero or is_counter or int(hero.ep)<1 or not selected.broken or int(selected.hp)>0 or selected.severed,14)
	sever_button.tooltip_text=loc("Deal %d body damage, gain 1 Karma, remove the limb. Sever every limb to win. If EP is empty, Defend or Pass through an unspent round to recover 2 EP.","본체 피해 %d, 업보 +1, 부위 제거. 모든 부위를 절단하면 승리합니다. EP가 없으면 방어/넘기기로 EP를 쓰지 않는 라운드를 보내 2를 회복하세요.") % (12+int(m.boss.tier)*3)
	if int(selected.hp)==0 and not selected.severed and g.message.is_empty():
		var hint: String=loc("F / SEVER: %d body damage +1 Karma. Need EP? Defend or Pass an unspent round.","F / 절단: 본체 피해 %d · 업보 +1. EP가 없으면 방어/넘기기로 미소비 라운드를 보내세요.") % (12+int(m.boss.tier)*3)
		if is_counter: hint=loc("COUNTER: choose a living limb or Space to pass. Sever is available on a normal turn.","반격: 살아 있는 부위를 고르거나 Space로 넘기세요. 절단은 일반 차례에 가능합니다.")
		paragraph(g,hint,Vector2(380,174),650,16,g.GOLD)

	for i in range(m.heroes.size()):
		var h: Dictionary = m.heroes[i]
		var state: String = loc("FALLEN","쓰러짐") if int(h.hp)<=0 else (loc("GUARD","방어") if h.guard else (loc("PARRY ","패링 ")+g.display_text(str(h.parry_height)) if not str(h.parry_height).is_empty() else (loc("ACTED","행동 완료") if h.acted else loc("READY","대기"))))
		if i==current: state=loc("COUNTER","반격") if is_counter else loc("YOUR TURN","현재 차례")
		button(g,"%d %s / %s\nHP %d/%d · MP %d/%d · EP %d/6" % [i+1,g.display_text(str(h.name)),state,h.hp,h.max_hp,h.mp,h.max_mp,h.ep],Rect2(40+i*455,592,440,84),g.select_hero.bind(i),i==g.selected_hero,int(h.hp)<=0,17)
		g.meter(Rect2(58+i*455,664,190,4),float(h.hp)/maxf(1,float(h.max_hp)),g.TEAL)
		g.meter(Rect2(272+i*455,664,190,4),float(h.mp)/maxf(1,float(h.max_mp)),g.GOLD)
		if int(threat.losses[i])>0:
			var loss=ColorRect.new()
			loss.position=Vector2(58+i*455+190*float(int(h.hp)-int(threat.losses[i]))/maxf(1,float(h.max_hp)),664)
			loss.size=Vector2(190*float(threat.losses[i])/maxf(1,float(h.max_hp)),4)
			loss.color=Color("f18d71")
			loss.mouse_filter=Control.MOUSE_FILTER_IGNORE
			g.ui.add_child(loss)
	for i in range(hero.skills.size()):
		var skill: Dictionary=hero.skills[i]
		var prediction: Dictionary=m.preview_action(g.selected_hero,i,g.selected_part)
		var keys: Array=["Q","W","E","R"]
		var heights: Array[String]=[]
		for value: Variant in skill.heights: heights.append(g.display_text(str(value)))
		var copy: String="%s %s / %d MP\n%s / %d%s\nHP -%d · %s -%d" % [keys[i],g.display_text(str(skill.name)),skill.cost,"/".join(heights),prediction.get("hits",1),loc(" HITS","회"),prediction.get("titan_damage",0),loc("SHIELD","방어막"),prediction.get("shield_loss",0)]
		if prediction.get("spent_limb",false): copy=keys[i]+" / "+loc("LIMB SPENT\nF / SEVER OR RETARGET","부위 체력 0\nF / 절단 또는 대상 변경")
		if i==3: copy="R / "+loc("DEFEND","방어")+"\n"+(loc("INCOMING HP -%d (HALVED)","예상 받는 피해 %d (절반)") % int(prediction.get("incoming_loss",0)))+"\nMP +%d / HP +%d" % [prediction.get("focus",0),prediction.get("heal",0)]
		var b: Button=button(g,copy,Rect2(40+i*250,689,235,88),g.perform.bind(i),false,not prediction.get("valid",false),15)
		b.set_meta("skill_index",i)
		b.mouse_entered.connect(g.set_port_hover.bind(i,g.port_ui_generation))
		b.mouse_exited.connect(g.clear_port_hover.bind(i,g.port_ui_generation))
		b.tooltip_text=loc("Matching height deals full damage; mismatch deals half. MP is paid once, each allocated EP adds one hit.","공격 높이가 맞으면 온전한 피해, 다르면 절반입니다. MP는 한 번만 소비하며 EP마다 타격이 1회 늘어납니다.") if i!=3 else loc("The displayed incoming loss includes each attack halved and current stances. Recover the capped MP/HP. Guard lasts until next round.","예상 받는 피해는 각 공격의 절반과 현재 자세를 반영합니다. MP/HP는 상한까지만 회복하며 방어는 다음 라운드까지 유지됩니다.")
		if prediction.get("spent_limb",false):
			b.tooltip_text=loc("A zero-HP limb cannot take another hit. Select a living limb, or use F / Sever with 1 EP. With no EP, Defend or Pass an unspent round; a Counter can always be passed.","체력 0인 부위는 다시 공격할 수 없습니다. 다른 부위를 고르거나 EP 1로 F / 절단하세요. EP가 없으면 방어/넘기기로 회복하고, 반격은 언제든 넘길 수 있습니다.")
		if prediction.has("party_heal") and prediction.party_heal.max()>0:
			var healed: Array[String]=[]
			for ally in range(m.heroes.size()): healed.append("%s +%d" % [g.display_text(str(m.heroes[ally].name)),prediction.party_heal[ally]])
			b.tooltip_text += "\n"+loc("Party HP once per action: ","행동당 한 번 아군 체력: ")+", ".join(healed)

	var end_copy: String=loc("SPACE / RESOLVE ENEMY","SPACE / 적 행동 진행") if current<0 else (loc("SPACE / PASS COUNTER","SPACE / 반격 넘기기") if is_counter else loc("SPACE / PASS THIS HERO","SPACE / 현재 영웅 넘기기"))
	button(g,end_copy,Rect2(1060,689,340,88),g.request_end_round,true,false,17)
	var event_lines: Array[String]=[]
	for e: Dictionary in m.run.combat.events.slice(maxi(0,m.run.combat.events.size()-3)):
		event_lines.append(event_text(g,e))
	paragraph(g,"\n".join(event_lines),Vector2(42,795),1345,16)
	if not g.message.is_empty(): paragraph(g,g.display_text(g.message),Vector2(380,174),650,15,g.GOLD)

static func event_text(g,e: Dictionary) -> String:
	var part: String = g.display_text(str(g.model.parts[int(e.part)].name)) if e.has("part") else ""
	match str(e.kind):
		"hit": return loc("Hit %d → %s · %d damage%s","%d번째 타격 → %s · 피해 %d%s") % [e.hit,part,e.damage,"" if e.height_match else loc(" / wrong height: half"," / 높이 불일치: 절반")]
		"break": return loc("BREAK: %s · blocked through next enemy phase","붕괴: %s · 다음 적 행동 때 이 부위 공격 취소") % part
		"sever": return loc("SEVER: %s · linked move permanently removed","절단: %s · 연결 기술 영구 제거") % part
		"defend": return loc("Defend · MP +%d · half incoming damage","방어 · MP +%d · 받는 피해 절반") % e.mp
		"parry_stance": return loc("Parry stance: ","패링 준비: ")+g.display_text(str(e.height))
		"successful_parry": return loc("Parry success → hero-only free Counter","패링 성공 → 해당 영웅의 무료 반격")
		"normal_attack": return loc("Normal attack: ","일반 공격: ")+g.display_text(str(e.hero))
	return ""

static func guide(g, coach: bool = false) -> void:
	var blocker=ColorRect.new()
	blocker.color=Color(0,0,0,0.85)
	blocker.size=Vector2(1440,900)
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	g.ui.add_child(blocker)
	g.panel_at(Rect2(245,100,950,700))
	label(g,loc("ASHEN PROVISIONAL COMBAT","ASHEN 임시 전투 안내"),Vector2(285,135),28,g.GOLD,850)
	var text: String=loc("Temporary Ashen rules; original-game equality is unverified.\n\n1. Follow the queue. EP starts at2 (cap6). [ / ] or wheel assigns0–3 Boost. Each EP adds a hit; MP is paid once. An unspent round restores2 EP.\n\n2. Matching height deals full damage, other heights half. Break blocks that limb through the next enemy phase. Surviving limbs regain shields; broken legs lower other targets.\n\n3. At limbHP0, hits stop. Choose another limb or F / Sever (normal turn,1EP). Sever adds rupture damage and Karma; every limb severed wins. With no EP, Defend or Pass an unspent round.\n\n4. R / Defend halves each hit and restores up to15MP. T / Parry costs5MP and matches the selected height. Success grants a free Q Counter. Space passes an actor or Counter, or resolves the enemy.\n\n5. Tier2+ may attack one hero at two heights. Read both limb sources: Break one and Parry the other, or Defend. The turn state is saved.\n\nMap, rewards and growth remain transitional Ashen content.","Ashen 임시 규칙입니다. 원작과의 동일성은 미검증입니다.\n\n1. 차례대로 행동하세요. EP 시작 2·상한 6. [ / ] 또는 휠로 최대 3을 배분합니다. EP마다 타격 1회, MP는 한 번만 소비합니다. EP를 쓰지 않은 라운드 뒤 2 회복합니다.\n\n2. 높이가 맞으면 온전한 피해, 다르면 절반입니다. 붕괴한 부위는 다음 적 행동까지 공격하지 못합니다. 살아 있는 부위는 그 뒤 방어막을 회복하며 다리 붕괴는 높이를 낮춥니다.\n\n3. 부위 HP 0에서 타격이 멈춥니다. 다른 부위를 고르거나 F / 절단(일반 차례·EP 1)하세요. 파열 피해와 업보를 얻고 전 부위 절단 시 승리합니다. EP가 없으면 방어/넘기기로 회복하세요.\n\n4. R / 방어는 각 피해 절반·MP 최대 15 회복. T / 패링(MP 5)은 선택한 높이를 맞춰 무료 Q 반격을 얻습니다. Space는 현재 차례·반격을 넘기거나 적 행동을 진행합니다.\n\n5. 2단계부터 한 영웅에게 두 높이 공격이 옵니다. 공격원 하나를 붕괴시키고 다른 높이는 패링하거나 방어하세요. 차례 상태는 저장됩니다.\n\n지도·보상·성장은 기존 과도기 콘텐츠입니다.")
	paragraph(g,text,Vector2(285,196),850,17)
	button(g,loc("ENTER / START BATTLE","ENTER / 전투 시작") if coach else loc("CLOSE GUIDE","안내 닫기"),Rect2(825,729,330,50),g.dismiss_first_battle_coach if coach else func(): g.help_open=false;g.refresh(),true)
