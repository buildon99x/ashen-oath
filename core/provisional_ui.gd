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
		label(g,g.display_text(str(attack.name))+" / "+g.display_text(str(m.parts[int(attack.part)].level)),Vector2(40,y),18,g.PALE,290)
		var lines: Array[String] = []
		for value: Variant in attack.targets:
			var target: int = int(value)
			lines.append("%s  HP -%d" % [g.display_text(str(m.heroes[target].name)),attack.losses[target]])
		if attack.status=="cancelled": lines=[loc("SOURCE STOPPED / NO ATTACK","부위 무력화 / 공격 취소")]
		elif attack.status=="warded": lines.append(loc("PARRY → FREE COUNTER","패링 → 무료 반격"))
		paragraph(g,"\n".join(lines),Vector2(40,y+28),290,17,g.omen_shade(str(attack.status)))
	paragraph(g,loc("Break stops the next enemy phase. Sever removes its move. Defend halves damage. Match Parry to the incoming height.","붕괴는 다음 적 행동을 취소합니다. 절단은 기술을 영구 제거합니다. 방어는 피해 절반, 패링은 공격 높이를 맞추세요."),Vector2(40,435),290,15,g.TEAL)
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
	button(g,loc("F / SEVER · 1 EP","F / 절단 · EP 1"),Rect2(763,530,264,38),g.provisional_special.bind("sever"),false,current!=g.selected_hero or is_counter or int(hero.ep)<1 or not selected.broken or int(selected.hp)>0 or selected.severed,14)
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
		if i==3: copy="R / "+loc("DEFEND","방어")+"\n"+loc("HALVE ALL DAMAGE","모든 받는 피해 절반")+"\nMP +%d / HP +%d" % [prediction.get("focus",0),prediction.get("heal",0)]
		var b: Button=button(g,copy,Rect2(40+i*250,689,235,88),g.perform.bind(i),false,not prediction.get("valid",false),15)
		b.set_meta("skill_index",i)
		b.mouse_entered.connect(g.set_port_hover.bind(i,g.port_ui_generation))
		b.mouse_exited.connect(g.clear_port_hover.bind(i,g.port_ui_generation))
		b.tooltip_text=loc("Matching height deals full damage; mismatch deals half. MP is paid once, each allocated EP adds one hit.","공격 높이가 맞으면 온전한 피해, 다르면 절반입니다. MP는 한 번만 소비하며 EP마다 타격이 1회 늘어납니다.") if i!=3 else loc("Recover the displayed capped MP. Guard lasts until next round.","표시된 MP만큼 상한까지 회복합니다. 방어는 다음 라운드까지 유지됩니다.")
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
		"break": return loc("BREAK: %s · next enemy phase stopped","붕괴: %s · 다음 적 행동 취소") % part
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
	var text: String=loc("Original-game equality is unverified. These explicit Ashen rules make the combat playable.\n\n1. Follow the turn queue. EP starts at2, cap6. [ / ] or wheel selects0–3 Boost. Each EP adds a hit; MP is paid once. Spend no EP to recover2 next round.\n\n2. Match attack height for full damage; other heights deal half. Break cancels the next enemy phase. Surviving limbs then recover shields. Broken legs lower other targets.\n\n3. Wound an exposed limb to0HP, then use F / Sever on another hero turn for1EP. Its move is removed permanently. Severed legs keep the enemy collapsed.\n\n4. R / Defend halves damage and restores up to15MP. T / Parry costs5MP: select the incoming source height. Success grants a free Q Counter; a mismatch takes full damage.\n\n5. Space passes only this actor or resolves the enemy. Counter uses the same height and relic checks. Your selected ruleset and turn state are saved.\n\nMap, rewards and growth currently remain transitional Ashen content.","원작과의 동일성은 미검증입니다. 전투를 진행할 수 있도록 명시한 Ashen 임시 규칙입니다.\n\n1. 차례대로 행동하세요. 시작 EP 2, 상한 6. [ / ] 또는 휠로 최대 3을 배분합니다. EP마다 타격이 1회 늘고 MP는 한 번만 소비합니다. EP를 쓰지 않으면 다음 라운드에 2 회복합니다.\n\n2. 높이가 맞으면 온전한 피해, 다르면 절반입니다. 붕괴는 다음 적 행동을 취소합니다. 살아 있는 부위는 그 뒤 방어막을 회복합니다. 다리 붕괴는 다른 부위 높이를 낮춥니다.\n\n3. 노출된 부위 체력을 0으로 만든 뒤 다른 영웅 차례에 F / 절단(EP 1)을 사용하세요. 연결 기술을 영구 제거하며 다리 절단은 높이 저하를 유지합니다.\n\n4. R / 방어는 피해 절반·MP 최대 15 회복. T / 패링(MP 5)은 공격의 높이를 맞추세요. 성공하면 무료 Q 반격, 틀리면 피해를 그대로 받습니다.\n\n5. Space는 현재 영웅만 넘기거나 적 행동을 진행합니다. 반격에도 같은 높이·유물 규칙이 적용됩니다. 규칙과 차례 상태는 저장됩니다.\n\n지도·보상·성장은 아직 기존 Ashen 콘텐츠입니다.")
	paragraph(g,text,Vector2(285,196),850,18)
	button(g,loc("ENTER / START BATTLE","ENTER / 전투 시작") if coach else loc("CLOSE GUIDE","안내 닫기"),Rect2(825,729,330,50),g.dismiss_first_battle_coach if coach else func(): g.help_open=false;g.refresh(),true)
