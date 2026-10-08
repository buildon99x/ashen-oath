extends Node2D

const Model = preload("res://model.gd")
const ActorArt = preload("res://generated_actor_art.gd")
const MonsterArt = preload("res://generated_monster.gd")
const HeroAnimation = preload("res://animated_hero.gd")
const GOLD = Color("d6b77d")
const TEAL = Color("78c9be")
const INK = Color("0e171e")
const PALE = Color("e4e5db")
const FINISHER_DURATION: float = 1.15
const FINISHER_SKIP_RECT = Rect2(1080, 786, 300, 64)
var model = Model.new()
var firelit_arena: Texture2D = preload("res://assets/environments/firelit_arena.webp")
var forest: Texture2D = preload("res://assets/cinder_forest.png")
var titan_sprites: Array = []
var generated_monster: Node2D
var hero_sprites: Array = []
var actors: Array[Node2D]=[]
var environments: Array[Texture2D]=[]
var vignettes: Dictionary={}
var party_feet: Array[Vector2]=[Vector2(420,480),Vector2(520,510),Vector2(620,540)]
var victory_feet: Array[Vector2]=[Vector2(960,510),Vector2(1110,535),Vector2(1260,510)]
var ui: Control
var selected_hero: int = 0
var selected_part: int = 0
var clock_time: float = 0.0
var menu: bool = true
var help_open: bool = false
var build_open: bool = false
var muted: bool = false
var message: String = ""
var confirmation: String = ""
var hit_flash: float = 0.0
var fx_time: float=0.0
var fx_actor: int=0
var fx_part: int=0
var fx_kind: String="slash"
var fx_damage: int=0
var enemy_flash: float=0.0
var enemy_losses: Array[int] = [0,0,0]
var enemy_source: int = 0
var enemy_wards: Array[bool] = [false,false,false]
var finisher_remaining: float = 0.0
var finisher_cuts: Array = [false,false,false]
var finisher_action: String = ""
var finisher_awards: String = ""
var combat_feedback: Node2D
var audio: AudioStreamPlayer
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	RenderingServer.set_default_clear_color(INK)
	if ResourceLoader.exists("res://assets/fonts/PixelifySans.ttf"):
		font=load("res://assets/fonts/PixelifySans.ttf")
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	generated_monster=MonsterArt.new()
	add_child(generated_monster)
	for i in range(3):
		hero_sprites.append(load("res://assets/hero_%d.png" % i))
	model.load_meta()
	model.load_resume()
	restore_battle_selection()
	for i in range(3):
		var actor: Node2D=HeroAnimation.new()
		actor.hero_index=i
		actor.facing="right"
		actor.position=party_feet[i]
		actor.scale=Vector2(1.25,1.25)
		add_child(actor)
		actors.append(actor)
	combat_feedback = Node2D.new()
	combat_feedback.draw.connect(draw_enemy_feedback)
	add_child(combat_feedback)
	for path in ["cinder_forest","drowned_reliquary","pale_throne"]:
		var file: String="res://assets/environments/"+path+".png"
		environments.append(load(file) as Texture2D if ResourceLoader.exists(file) else forest)
	for key in ["camp","relic","event","reward"]:
		var path: String="res://assets/vignettes/"+key+".png"
		if ResourceLoader.exists(path): vignettes[key]=load(path)
	ui = Control.new()
	add_child(ui)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	refresh()

func _process(delta: float) -> void:
	clock_time += delta
	advance_finisher(delta)
	generated_monster.visible=menu or model.phase in ["battle","defeat"] or finisher_active()
	hit_flash = maxf(0.0, hit_flash - delta * 2.0)
	fx_time=maxf(0.0,fx_time-delta)
	enemy_flash=maxf(0.0,enemy_flash-delta)
	combat_feedback.queue_redraw()
	for i in range(actors.size()):
		var actor: Node2D=actors[i]
		actor.visible=not menu and (model.phase in ["battle","victory"] or finisher_active())
		actor.position=victory_feet[i] if model.phase=="victory" and not menu else party_feet[i]
		actor.facing="down" if model.phase=="victory" and not menu else "right"
		actor.scale=Vector2(1.8,1.8) if model.phase=="victory" and not menu else Vector2(1.25,1.25)
		if actor.visible and model.heroes.size()==3:
			if model.heroes[i].hp<=0 and actor.state!="death": actor.play_state("death",true)
			elif model.heroes[i].hp>0 and actor.state=="death": actor.play_state("idle",true)
	queue_redraw()

func finisher_active() -> bool:
	return finisher_remaining > 0.0

func advance_finisher(delta: float) -> void:
	if not finisher_active(): return
	finisher_remaining=maxf(0.0,finisher_remaining-maxf(delta,0.0))
	if finisher_remaining==0.0:
		refresh()

func finish_presentation() -> void:
	if not finisher_active(): return
	finisher_remaining=0.0
	refresh()

func show_finisher() -> void:
	label_at("A GOD IS UNMADE",Vector2(65,128),38,GOLD,1000)
	label_at(str(model.boss.get("name","The Uncrowned")),Vector2(68,185),25,PALE,1000)
	label_at(finisher_action+" / FINAL STRIKE",Vector2(68,665),21,TEAL,1290)
	label_at(finisher_awards,Vector2(68,714),24,PALE,980)
	label_at("YOUR REWARD IS READY",Vector2(68,807),16,GOLD,850)
	button("SPACE / ESC / SKIP",FINISHER_SKIP_RECT,finish_presentation,true,false,true)

func draw_finisher_feedback() -> void:
	var progress: float=1.0-finisher_remaining/FINISHER_DURATION
	var release: float=clampf((progress-0.22)/0.78,0.0,1.0)
	if release<=0.0: return
	for i in range(24):
		var seed_x: float=sin(float(i)*7.13)*92.0
		var seed_y: float=fmod(float(i)*53.0,204.0)
		var point: Vector2=Vector2(865+seed_x,246+seed_y)+Vector2(seed_x*release*0.55,-release*(35+i%5*13))
		combat_feedback.draw_rect(Rect2(point,Vector2(3,3)),Color(0.83,0.71,0.49,sin(release*PI)*0.85))

func _input(event: InputEvent) -> void:
	if not finisher_active(): return
	# The model has already awarded this victory and saved the reward choice.
	# Consume the skip event before new reward controls exist, including releases.
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE,KEY_ENTER,KEY_ESCAPE]: finish_presentation()
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if FINISHER_SKIP_RECT.has_point(event.position): finish_presentation()

func _unhandled_key_input(event: InputEvent) -> void:
	if finisher_active():
		_input(event)
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if not confirmation.is_empty():
		if key == KEY_ESCAPE:
			confirmation = ""
			refresh()
		elif key == KEY_ENTER:
			confirm_action()
		return
	if build_open:
		if key == KEY_ESCAPE or key == KEY_B:
			build_open = false
			refresh()
		return
	if key == KEY_V:
		get_tree().change_scene_to_file("res://character_studio.tscn")
	elif key == KEY_H:
		help_open = not help_open
		refresh()
	elif key == KEY_M:
		muted = not muted
		refresh()
	elif key == KEY_B and not model.run.is_empty():
		build_open = true
		refresh()
	elif key == KEY_ESCAPE:
		if help_open:
			help_open = false
		elif not model.heroes.is_empty() and model.phase != "title":
			menu = not menu
		refresh()
	elif not menu and not help_open and model.phase == "battle":
		if key >= KEY_1 and key <= KEY_3:
			selected_hero = key - KEY_1
			refresh()
		elif key == KEY_Q or key == KEY_W or key == KEY_E or key == KEY_R:
			var keys: Array = [KEY_Q, KEY_W, KEY_E, KEY_R]
			perform(keys.find(key))
		elif key == KEY_UP:
			cycle_part(-1)
		elif key == KEY_DOWN:
			cycle_part(1)
		elif key == KEY_SPACE:
			request_end_round()

func box(rect: Rect2, color: Color, border: Color = Color.TRANSPARENT) -> void:
	draw_style_box(style(color, border), rect)

func style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	s.shadow_color=Color(0,0,0,0.4)
	s.shadow_size=3
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func label_at(text: String, pos: Vector2, size: int = 20, color: Color = PALE, width: float = 1300) -> Label:
	var l = Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, 35)
	l.add_theme_font_override("font",font)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	ui.add_child(l)
	return l

func paragraph(text: String, pos: Vector2, width: float, size: int = 18, color: Color = PALE) -> Label:
	var l = Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = text
	l.position = pos
	l.size = Vector2(width, 0)
	l.add_theme_font_override("font",font)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	ui.add_child(l)
	return l

func button(text: String, rect: Rect2, action: Callable, active: bool = false, disabled: bool = false, during_finisher: bool = false) -> Button:
	var b = Button.new()
	b.text = wrap_button(text, rect.size.x - 34)
	b.position = rect.position
	b.size = rect.size
	b.disabled = disabled
	if model.phase == "battle" and not menu and not help_open and not build_open and confirmation.is_empty():
		b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_font_override("font",font)
	b.add_theme_color_override("font_color", GOLD if active else PALE)
	b.add_theme_stylebox_override("normal", pixel_frame("gold" if active else "normal"))
	b.add_theme_stylebox_override("hover", pixel_frame("hover"))
	b.add_theme_stylebox_override("pressed", pixel_frame("gold"))
	b.add_theme_stylebox_override("disabled", pixel_frame("disabled"))
	b.pressed.connect(func():
		if during_finisher or not finisher_active(): action.call())
	ui.add_child(b)
	return b

func wrap_button(text: String, max_width: float) -> String:
	var lines: Array[String] = []
	for source_line in text.split("\n"):
		var line: String = ""
		for word in source_line.split(" "):
			var trial: String = line + (" " if not line.is_empty() else "") + word
			if not line.is_empty() and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x > max_width:
				lines.append(line)
				line = word
			else:
				line = trial
		lines.append(line)
	return "\n".join(lines)

func refresh() -> void:
	if model.persist_meta and not model.run.is_empty():
		model.save_resume()
	for child in ui.get_children():
		child.queue_free()
	label_at("A S H E N   O A T H", Vector2(38, 22), 25, GOLD)
	label_at("THE HOLLOW CROWN", Vector2(40, 55), 12, TEAL)
	if finisher_active():
		show_finisher()
		return
	button("V  Sprites",Rect2(990,25,120,42),func(): get_tree().change_scene_to_file("res://character_studio.tscn"))
	button("H  Guide", Rect2(1120, 25, 120, 42), func(): help_open = not help_open; refresh())
	button("M  " + ("Muted" if muted else "Sound"), Rect2(1250, 25, 150, 42), func(): muted = not muted; refresh())
	if menu:
		show_menu()
	else:
		label_at("CYCLE %d  /  ASH %d  /  GOLD %d  /  KARMA %+d" % [int(model.meta.get("runs",0))+(0 if model.phase in ["victory","defeat"] else 1), model.meta.get("essence",0), model.run.get("gold",0), model.run.get("karma",0)], Vector2(420, 32), 16, PALE)
		match model.phase:
			"battle": show_battle()
			"map": show_map()
			"reward": show_choices(model.rewards, "A MEMORY WORTH KEEPING", "Choose recovery, tribute, or a relic for this journey.", true)
			"event", "camp", "relic": show_choices(model.event.get("options", []), model.title, model.event.get("description", "The road remembers every choice."), false)
			"victory", "defeat": show_ending()
	if help_open:
		show_help()
	if build_open:
		show_build()
	if not confirmation.is_empty():
		show_confirmation()

func show_menu() -> void:
	label_at("THE GODS LEFT THEIR CROWNS.", Vector2(70, 192), 18, TEAL)
	label_at("We learned\nto break them.", Vector2(65, 233), 62, PALE)
	paragraph("Three wanderers. Nine crossings. One hollow throne.\nRead the omen. Break a defense. Sever the source of its power.", Vector2(72, 405), 620, 21)
	button("BEGIN A NEW CYCLE", Rect2(72, 525, 330, 62), request_new_cycle, true)
	if not model.heroes.is_empty():
		button("RESUME CURRENT JOURNEY", Rect2(72, 601, 330, 52), func(): menu = false; refresh())
	label_at("LEGACY  /  %d ASH" % model.meta.get("essence",0), Vector2(72, 685), 19, GOLD)
	var i: int = 0
	for key in ["vitality", "force", "focus"]:
		var level: int = model.meta.get("upgrades",{}).get(key,0)
		button("%s +%d · %d ash" % [key.capitalize(), level, model.upgrade_cost(key)], Rect2(72+i*208, 729, 198, 62), upgrade.bind(key))
		i += 1
	label_at(message if not message.is_empty() else "Original tactical roguelite • mouse or keyboard • no time pressure", Vector2(72, 820), 15, Color("91a6a7"))

func begin_run() -> void:
	if finisher_active(): return
	confirmation = ""
	build_open = false
	model.new_run(int(Time.get_unix_time_from_system()) % 1000000)
	menu = false
	selected_hero = 0
	selected_part = 0
	message = ""
	refresh()

func request_new_cycle() -> void:
	if finisher_active(): return
	if not model.run.is_empty() and model.phase not in ["title", "victory", "defeat"]:
		confirmation = "new_cycle"
		refresh()
	else:
		begin_run()

func request_end_round() -> void:
	if finisher_active(): return
	if model.phase != "battle": return
	if model.actions_remaining() > 0:
		confirmation = "end_round"
		refresh()
	else:
		finish_round()

func confirm_action() -> void:
	if finisher_active(): return
	var pending: String = confirmation
	confirmation = ""
	if pending == "new_cycle": begin_run()
	elif pending == "end_round": finish_round()

func show_confirmation() -> void:
	var blocker = ColorRect.new()
	blocker.color = Color(0,0,0,0.78)
	blocker.size = Vector2(1440,900)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(blocker)
	panel_at(Rect2(370,260,700,350))
	var is_round: bool = confirmation == "end_round"
	label_at("%d HEROES CAN STILL ACT" % model.actions_remaining() if is_round else "LEAVE THIS JOURNEY?",Vector2(404,293),29,GOLD,640)
	paragraph("Ending now gives up their remaining actions and resolves the omen. You can still attack or defend first." if is_round else "Starting again replaces this journey. Your %d unbanked ash will be lost. Your existing legacy upgrades and banked ash stay with you." % model.run.get("essence",0),Vector2(406,355),615,22)
	button("ESC / KEEP PLAYING",Rect2(405,513,295,62),func(): confirmation=""; refresh(),true)
	button("ENTER / END ROUND" if is_round else "ENTER / NEW CYCLE",Rect2(718,513,314,62),confirm_action)

func upgrade(key: String) -> void:
	if finisher_active(): return
	var success: bool = model.buy_upgrade(key)
	message = "Legacy strengthened." if success else model.last_error
	refresh()

func show_battle() -> void:
	label_at("%02d  /  %s" % [int(model.run.get("node",0))+1, model.boss.get("name", "The Uncrowned")], Vector2(40, 104), 28, PALE)
	label_at("ROUND %d  /  %d ACTIONS LEFT" % [model.round_number, model.actions_remaining()], Vector2(40, 145), 15, TEAL)
	label_at("TITAN  %d / %d" % [model.boss.get("hp",0), model.boss.get("max_hp",0)], Vector2(530, 103), 15, GOLD)
	var threat: Dictionary = model.preview_intent()
	var omen_color: Color = TEAL if threat.status == "cancelled" else (GOLD if threat.status == "staggered" else Color("efa080"))
	show_omen(threat)
	label_at("HERO > PART > SKILL   /   DAMAGE FORECAST: PART HP", Vector2(40, 553), 14, TEAL)
	for i in range(model.parts.size()):
		var p: Dictionary = model.parts[i]
		var status: String = "SEVERED" if p.get("severed",false) else ("BROKEN" if p.get("broken",false) else "SHIELD %d" % p.get("shield",0))
		var t: String = "%s · %s\n%s  |  HP %d/%d\nWeak: %s" % [str(p.get("level","")), p.get("name",""), status, p.get("hp",0), p.get("max_hp",0), str(p.get("weakness",""))]
		var b = button(t, Rect2(1080, 183+i*119, 320, 104), select_part.bind(i), i == selected_part, p.get("severed",false))
		b.add_theme_font_size_override("font_size", 17)
		b.tooltip_text = "Severing removes %s from future rounds." % p.get("move","")
		for attack_index in range(threat.attacks.size()):
			var attack: Dictionary = threat.attacks[attack_index]
			if i == int(attack.part) and not p.severed:
				label_at(str(attack_index+1),Vector2(1088,185+i*119),16,omen_color,20)
				b.tooltip_text = "OMEN %d / %s\n%s" % [attack_index+1,attack.name,attack.counterplay]
	var build_button = button("B / VIEW BUILD",Rect2(1080,538,320,36),func(): build_open=true; refresh())
	build_button.add_theme_font_size_override("font_size",14)
	for i in range(model.heroes.size()):
		var h: Dictionary = model.heroes[i]
		var state: String = "FALLEN" if h.hp<=0 else ("GUARD" if h.guard else ("ACTED" if h.acted else "READY"))
		var t: String = "%d  %s  /  %s\nHP %d/%d   MP %d/%d  %s" % [i+1, h.get("name",""), h.get("role",""), h.get("hp",0), h.get("max_hp",0), h.get("mp",0), h.get("max_mp",0), state]
		var hero_button=button(t, Rect2(40+i*455, 592, 440, 84), select_hero.bind(i), i == selected_hero, h.get("hp",0)<=0)
		var portrait=AtlasTexture.new()
		portrait.atlas=ActorArt.TEXTURE
		portrait.region=ActorArt.PORTRAIT_REGIONS[i]
		hero_button.icon=portrait
		hero_button.expand_icon=true
		hero_button.add_theme_constant_override("icon_max_width",42)
		meter(Rect2(99+i*455,662,170,4),float(h.hp)/maxf(1,float(h.max_hp)),Color("a7c48e"))
		var loss: int = threat.losses[i]
		if loss > 0:
			var forecast = ColorRect.new()
			forecast.position = Vector2(99+i*455+170*float(h.hp-loss)/h.max_hp,662)
			forecast.size = Vector2(170*float(loss)/h.max_hp,4)
			forecast.color = Color("f18d71")
			forecast.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ui.add_child(forecast)
		meter(Rect2(280+i*455,662,177,4),float(h.mp)/maxf(1,float(h.max_mp)),Color("79b6bf"))
	var hero: Dictionary = model.heroes[selected_hero]
	var skills: Array = hero.get("skills",[])
	for i in range(skills.size()):
		var skill: Dictionary = skills[i]
		var keys: Array = ["Q", "W", "E", "R"]
		var prediction: Dictionary = model.preview_action(selected_hero,i,selected_part)
		var summary: String = prediction.get("summary", "NO TARGET")
		if prediction.get("guard",false) and not prediction.get("wards",[]).is_empty():
			summary = "WARD RITE / +%d HP" % prediction.get("heal",0)
		var b = button("%s  %s\n%s · %d MP\n%s" % [keys[i], skill.get("name",""), skill.get("type","").to_upper(), skill.get("cost",0),summary], Rect2(40+i*250, 689, 235, 88), perform.bind(i), false, not prediction.get("valid",false))
		b.add_theme_font_size_override("font_size",16)
		b.tooltip_text = skill.get("description","") + ("\nForecast: %d titan HP, including any sever rupture. Part damage is shown on the button." % prediction.get("titan_damage",0) if not prediction.get("guard",false) else "\nDefend halves normal attacks and cancels a wardable rite targeting this hero. The live omen updates after Defend.")
		var icon_path: String="res://assets/ui/"+skill.get("type","slash")+".png"
		if ResourceLoader.exists(icon_path):
			b.icon=load(icon_path)
			b.expand_icon=true
			b.add_theme_constant_override("icon_max_width",22)
	button("SPACE / END ROUND\n" + ("OMEN CANCELLED" if threat.status == "cancelled" else "RESOLVE OMEN"), Rect2(1060, 689, 340, 88), request_end_round, true)
	var lines: Array = model.log.slice(maxi(0,model.log.size()-3))
	paragraph("\n".join(lines), Vector2(42, 797), 1320, 16, Color("adc0bd"))
	if not message.is_empty():
		label_at(message, Vector2(420, 170), 16, GOLD,620)

func omen_shade(status: String) -> Color:
	if status in ["cancelled","warded","missed"]: return TEAL
	return GOLD if status == "staggered" else Color("efa080")

func show_omen(threat: Dictionary) -> void:
	var attacks: Array=threat.get("attacks",[])
	var rhythm: Dictionary=threat.get("rhythm",{})
	var heading: String=str(rhythm.get("name",threat.status)).to_upper()
	label_at("OMEN / " + heading,Vector2(40,189),16,omen_shade(threat.status),295)
	if attacks.size()<=1:
		paragraph(model.intent.get("name","Waiting"),Vector2(40,217),300,24,PALE)
		paragraph(threat.source + " / " + str(threat.status).to_upper(),Vector2(40,257),287,15,TEAL)
		paragraph(threat.description,Vector2(40,301),287,18,omen_shade(threat.status))
		var hint: String = "Sever this source to cancel its attack." if threat.status=="staggered" else ("The party is safe this round." if threat.status in ["cancelled","warded","missed"] else "Break this source to halve its attack.")
		if not rhythm.is_empty(): hint=str(rhythm.description)
		paragraph(hint,Vector2(40,410),287,15,Color("b0c1bc"))
		return
	for i in range(attacks.size()):
		var attack: Dictionary=attacks[i]
		var y: int=226+i*144
		label_at("%d / %s" % [i+1,attack.name],Vector2(40,y),20,PALE,290)
		label_at(str(attack.source)+" / "+str(attack.status).to_upper(),Vector2(40,y+28),14,omen_shade(attack.status),290)
		var loss_text: Array[String]=[]
		for h in attack.targets:
			var detail: String="%s -%d HP" % [model.heroes[h].name,attack.losses[h]]
			if attack.focus_losses[h]>0: detail+=" / -%d MP" % attack.focus_losses[h]
			loss_text.append(detail)
		var result: String="\n".join(loss_text)
		if attack.status=="cancelled": result="SEVERED / NO ATTACK"
		elif attack.status=="warded": result="0 HP / 0 FOCUS (DEFEND)"
		elif attack.status=="missed": result="NO LIVING TARGET"
		paragraph(result,Vector2(40,y+51),286,16,omen_shade(attack.status))
		if attack.wardable:
			var counter: String="%s: DEFEND CANCELS THIS RITE" % model.heroes[attack.targets[0]].name.to_upper()
			paragraph(counter,Vector2(40,y+87),286,14,TEAL)
	label_at("NEXT / "+str(rhythm.get("next","Read the next omen")),Vector2(40,495),14,GOLD,295)

func select_hero(index: int) -> void:
	if finisher_active(): return
	selected_hero = index
	message = ""
	refresh()

func select_part(index: int) -> void:
	if finisher_active(): return
	selected_part = index
	message = ""
	refresh()

func restore_battle_selection() -> void:
	if model.phase != "battle": return
	for i in range(model.parts.size()):
		if not model.parts[i].severed:
			selected_part=i
			break
	for i in range(model.heroes.size()):
		if model.heroes[i].hp>0:
			selected_hero=i
			if not model.heroes[i].acted: break

func cycle_part(direction: int) -> void:
	if finisher_active(): return
	for offset in range(1,model.parts.size()+1):
		var candidate: int=posmod(selected_part+direction*offset,model.parts.size())
		if not model.parts[candidate].severed:
			selected_part=candidate
			break
	message=""
	refresh()

func perform(index: int) -> void:
	if finisher_active(): return
	var before_hp: int=int(model.boss.get("hp",0))
	var before_gold: int=int(model.run.get("gold",0))
	var before_ash: int=int(model.run.get("essence",0))
	var was_battle: bool=model.phase=="battle"
	var prior_cuts: Array=[]
	for part in model.parts: prior_cuts.append(bool(part.severed))
	var actor: int=selected_hero
	var target: int=selected_part
	if model.act(selected_hero, index, selected_part):
		fx_actor=actor
		fx_part=target
		fx_kind=model.heroes[actor].skills[index].type
		fx_damage=before_hp-int(model.boss.get("hp",0))
		fx_time=0.85
		if actors.size()==3:
			actors[actor].play_state("idle" if index==3 else "attack",true)
		hit_flash = 0.6
		tone(160 + index * 90, 0.12)
		message = ""
		if was_battle and model.phase=="reward":
			finisher_cuts=prior_cuts
			finisher_remaining=FINISHER_DURATION
			finisher_action="%s / %s" % [model.heroes[actor].name.to_upper(),model.heroes[actor].skills[index].name.to_upper()]
			finisher_awards="+%d GOLD / +%d UNBANKED ASH" % [int(model.run.gold)-before_gold,int(model.run.essence)-before_ash]
			help_open=false
			build_open=false
			confirmation=""
		if model.parts[selected_part].get("severed",false):
			for j in range(model.parts.size()):
				if not model.parts[j].get("severed",false):
					selected_part=j
					break
		for i in range(model.heroes.size()):
			if not model.heroes[i].get("acted",false) and model.heroes[i].get("hp",0)>0:
				selected_hero = i
				break
	else:
		message = model.last_error
	refresh()

func finish_round() -> void:
	if finisher_active(): return
	if model.phase != "battle": return
	confirmation = ""
	var forecast: Dictionary = model.preview_intent()
	enemy_source = int(model.intent.get("part",0))
	enemy_wards=[false,false,false]
	for attack in forecast.attacks:
		if attack.status=="warded":
			for h in attack.targets: enemy_wards[h]=true
	enemy_flash=1.1
	var before: Array[int]=[]
	for hero in model.heroes:before.append(hero.hp)
	model.end_round()
	for i in range(mini(actors.size(),model.heroes.size())):
		enemy_losses[i] = int(forecast.losses[i])
		if model.heroes[i].hp<=0:actors[i].play_state("death",true)
		elif enemy_losses[i]>0:actors[i].play_state("hurt",true)
	tone(320 if forecast.status in ["cancelled","warded","missed"] else 70,0.2)
	selected_hero = 0
	for i in range(model.heroes.size()):
		if model.heroes[i].get("hp",0)>0:
			selected_hero = i
			break
	refresh()

func draw_enemy_feedback() -> void:
	if finisher_active(): draw_finisher_feedback()
	if enemy_flash <= 0.0 or menu or model.phase != "battle": return
	var alpha: float = clampf(enemy_flash*2.0,0,1)
	var rise: float = (1.1-enemy_flash)*40.0
	for i in range(3):
		if enemy_wards[i]:
			combat_feedback.draw_string(font,party_feet[i]+Vector2(-26,-117-rise),"WARD",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color(0.48,0.84,0.77,alpha))
		if enemy_losses[i] <= 0: continue
		var point: Vector2 = party_feet[i]+Vector2(0,-55)
		var color: Color = Color(1.0,0.48,0.34,alpha)
		if enemy_source == 0:
			combat_feedback.draw_arc(party_feet[i]+Vector2(0,-4),24+rise*0.7,PI,TAU,20,color,3)
		elif enemy_source == 1:
			combat_feedback.draw_line(point+Vector2(25,-24),point+Vector2(-18,18),color,5)
		else:
			combat_feedback.draw_arc(point,28+rise*0.3,0,TAU,24,Color(0.74,0.60,1.0,alpha),3)
		combat_feedback.draw_string(font,point+Vector2(-17,-45-rise),"-%d" % enemy_losses[i],HORIZONTAL_ALIGNMENT_LEFT,-1,27,color)

func show_map() -> void:
	panel_at(Rect2(45,110,1350,190))
	label_at("THE PILGRIMAGE / %s" % ["CINDER FOREST","DROWNED RELIQUARY","PALE THRONE"][clampi(int(model.run.get("node",0))/3,0,2)],Vector2(65,124),16,TEAL,1250)
	label_at(model.title.to_upper(), Vector2(65, 153), 36, PALE,1250)
	paragraph("Crossing %d of 9. Rest when wounded, gather relics, and choose what kind of memory you leave behind." % (int(model.run.get("node",0))+1), Vector2(65, 211), 1060, 20)
	label_at("YOUR ROAD",Vector2(65,326),16,GOLD,300)
	label_at("CHECK: PASSED   /   GOLD: HERE   /   CROWN: SOVEREIGN",Vector2(665,326),14,TEAL,680)
	for i in range(9):
		label_at("%02d" % (i+1),Vector2(91+i*145,463),16,GOLD if i==int(model.run.get("node",0)) else Color("a4b5b3"),60)
	for i in range(model.choices.size()):
		var c: Dictionary = model.choices[i]
		button(c.get("name","Road") + "\n\n" + c.get("description",""), Rect2(65+i*440, 540, 410, 157), travel.bind(i), i==0)
	party_summary(740)
	if model.log.size()>0:
		paragraph(model.log[-1],Vector2(65,866),1300,14,GOLD)

func travel(index: int) -> void:
	if finisher_active(): return
	model.travel(index)
	selected_part = 0
	selected_hero = 0
	restore_battle_selection()
	message = ""
	refresh()

func show_choices(options: Array, title_text: String, description: String, reward: bool) -> void:
	panel_at(Rect2(45,120,830,320))
	label_at("A MOMENT ON THE ROAD / "+model.phase.to_upper(),Vector2(68,140),16,TEAL,750)
	paragraph(title_text.to_upper(), Vector2(65, 183), 770, 36, GOLD)
	paragraph(description, Vector2(68, 285), 720, 23)
	label_at("CHOOSE YOUR NEXT ACT",Vector2(65,482),16,TEAL,750)
	for i in range(options.size()):
		var c: Dictionary = options[i]
		var action: Callable = choose_reward.bind(i) if reward else choose_event.bind(i)
		button(c.get("name","Choice") + "\n\n" + c.get("description",""), Rect2(65+i*440, 520, 410, 176), action, i==0)
	party_summary(740)
	if not message.is_empty():
		paragraph(message,Vector2(65,446),1280,18,GOLD)

func choose_reward(index: int) -> void:
	if finisher_active(): return
	model.choose_reward(index)
	tone(440,0.2)
	refresh()

func choose_event(index: int) -> void:
	if finisher_active(): return
	if not model.choose_event(index):
		message=model.last_error
	else:
		message=""
	refresh()

func party_summary(y: int) -> void:
	for i in range(model.heroes.size()):
		var h: Dictionary = model.heroes[i]
		var x: int=65+i*440
		panel_at(Rect2(x,y,410,78))
		var portrait=TextureRect.new()
		var atlas=AtlasTexture.new()
		atlas.atlas=ActorArt.TEXTURE
		atlas.region=ActorArt.PORTRAIT_REGIONS[i]
		portrait.texture=atlas
		portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.position=Vector2(x+12,y+14)
		portrait.size=Vector2(52,48)
		portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
		ui.add_child(portrait)
		label_at("%s  %d/%d HP" % [h.get("name",""),h.get("hp",0),h.get("max_hp",0)],Vector2(x+78,y+9),20,TEAL,316)
		label_at("FOCUS %d/%d" % [h.get("mp",0),h.get("max_mp",0)],Vector2(x+78,y+37),14,PALE,300)
		meter(Rect2(x+78,y+64,174,4),float(h.hp)/maxf(1,float(h.max_hp)),Color("a7c48e"))
		meter(Rect2(x+265,y+64,124,4),float(h.mp)/maxf(1,float(h.max_mp)),Color("79b6bf"))
	var names: Array[String]=[]
	for relic in model.run.get("relics",[]):
		names.append(relic.get("name","Relic"))
	paragraph("RELICS / " + (", ".join(names) if not names.is_empty() else "None yet"), Vector2(65,y+90),1000,15,Color("c5cebc"))
	var build_button = button("B / VIEW BUILD",Rect2(1120,y+86,235,36),func(): build_open=true; refresh())
	build_button.add_theme_font_size_override("font_size",14)

func panel_at(rect: Rect2) -> void:
	var panel=Panel.new()
	panel.position=rect.position
	panel.size=rect.size
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",pixel_frame("normal"))
	ui.add_child(panel)

func show_ending() -> void:
	var won: bool = model.phase == "victory"
	panel_at(Rect2(45,165,820,500))
	label_at("THE CROWN IS SILENT" if won else "THE ASH REMEMBERS", Vector2(65, 210), 50, GOLD)
	paragraph("The wanderers leave the throne empty. Beyond the mist, another road begins." if won else "Your journey ends here. Its lessons remain. Spend your ash on a lasting legacy, then return stronger.", Vector2(70,310),650,25)
	label_at("Titans overcome: %d   •   Karma: %+d" % [model.run.get("bosses_defeated",0),model.run.get("karma",0)],Vector2(70,445),22,TEAL)
	label_at("ASH RECOVERED  +%d  /  VAULT  %d" % [model.run.get("essence",0),model.meta.get("essence",0)],Vector2(70,487),20,GOLD,740)
	button("RETURN TO THE EMBER",Rect2(70,550,350,68),func(): menu=true; refresh(),true)

func show_help() -> void:
	var blocker = ColorRect.new()
	blocker.color = Color(0,0,0,0.6)
	blocker.size = Vector2(1440,900)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(blocker)
	var panel = Panel.new()
	panel.position = Vector2(245,100)
	panel.size = Vector2(950,700)
	panel.add_theme_stylebox_override("panel",style(Color("101c24"),GOLD))
	ui.add_child(panel)
	label_at("THE ART OF UNMAKING",Vector2(285,135),32,GOLD)
	paragraph("1. Select a hero, then one of the titan's three body parts.\n2. Match a skill's type to the part's weakness to break its shield.\n3. Keep attacking the broken part. Depleting its HP severs it and removes its move.\n4. Each living hero acts once per round. End Round resolves every visible omen.\n5. Defend halves normal damage and cancels a wardable rite marked on that hero.\n6. Between battles, choose relics, rests and moral encounters. Death earns a new beginning; ash upgrades persist.\n\nMouse: click heroes, parts, skills and choices\nKeyboard: 1–3 hero • ↑/↓ target • Q/W/E attack • R guard\nSpace end round • B build / relics • V studio • H guide • M sound • Esc menu\n\nThere are no timers. Skill buttons predict damage and break/sever.\nThe omen updates after break, sever and guard. B shows relic effects.\nYour journey and legacy save after every choice. Resume from the title screen.",Vector2(285,200),850,21)
	button("CLOSE GUIDE",Rect2(855,716,285,50),func(): help_open=false; refresh(),true)

func show_build() -> void:
	var blocker = ColorRect.new()
	blocker.color = Color(0,0,0,0.78)
	blocker.size = Vector2(1440,900)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(blocker)
	panel_at(Rect2(255,110,930,700))
	label_at("MEMORIES OF THIS JOURNEY",Vector2(290,139),30,GOLD,840)
	paragraph("ASH / %d banked · %d earned this journey\nEarned ash is banked on victory or defeat. Starting a new cycle abandons it.\nTEMPERED WEAPONS / +%d damage to every attack" % [model.meta.get("essence",0),model.run.get("essence",0),model.run.get("damage_bonus",0)],Vector2(292,193),830,18,PALE)
	var relics: Array=model.run.get("relics",[])
	if relics.is_empty():
		paragraph("No relics yet. Win battles or visit a shrine to shape this build.",Vector2(292,319),830,22,TEAL)
	for i in range(relics.size()):
		var relic: Dictionary=relics[i]
		label_at(relic.get("name","Relic"),Vector2(292,311+i*70),22,TEAL,830)
		label_at(relic.get("description",""),Vector2(292,341+i*70),17,PALE,830)
	label_at("Attack relics are included in damage forecasts. Hollow Bell heals after enemy attacks.",Vector2(292,685),16,Color("a9b9b4"),830)
	button("B / ESC / RETURN",Rect2(820,734,322,48),func(): build_open=false; refresh(),true)

func tone(frequency: float, duration: float) -> void:
	if muted:
		return
	var sample = AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 22050
	var bytes = PackedByteArray()
	var count: int = int(22050*duration)
	bytes.resize(count*2)
	for i in range(count):
		var amp: float = sin(float(i)*TAU*frequency/22050.0)*0.14*pow(1.0-float(i)/count,2)
		bytes.encode_s16(i*2,int(amp*32767))
	sample.data=bytes
	audio.stream=sample
	audio.play()

func _draw() -> void:
	draw_rect(Rect2(0,0,1440,900), INK)
	# Original layered silhouette landscape, generated directly by Godot.
	for layer in range(5):
		var points = PackedVector2Array([Vector2(0,700)])
		for i in range(25):
			var x: float = i*60
			var y: float = 280+layer*66+sin(i*1.1+layer*2)*45+sin(i*0.41)*70
			points.append(Vector2(x,y))
		points.append(Vector2(1440,900)); points.append(Vector2(0,900))
		draw_colored_polygon(points,Color(0.06+layer*0.015,0.10+layer*0.016,0.13+layer*0.015))
	draw_circle(Vector2(920,250),110,Color("283f43"))
	draw_circle(Vector2(950,222),108,Color("15252e"))
	for i in range(37):
		var x: float = fmod(i*139.7+clock_time*(4+i%5),1440)
		var y: float = fmod(i*97.3-clock_time*8+1800,900)
		draw_circle(Vector2(x,y),1.5,Color(0.8,0.68,0.43,0.2+0.15*sin(clock_time+i)))
	if environments.size()==3:
		var biome: int=clampi(int(model.run.get("node",0))/3,0,2)
		draw_texture_rect(firelit_arena if not menu and (model.phase=="battle" or finisher_active()) else environments[biome],Rect2(0,0,1440,900),false)
		if menu:
			draw_rect(Rect2(0,80,680,820),Color(0.035,0.06,0.075,0.65))
		# soft grounded arena shadow
		for i in range(6):
			draw_rect(Rect2(0,560+i*9,1440,12),Color(0.03,0.065,0.08,0.07+i*0.03))
	if not menu and model.phase!="battle" and not finisher_active():
		draw_rect(Rect2(0,87,1440,813),Color(0.02,0.055,0.065,0.38))
	if menu:
		draw_titan(Vector2(1020,598),1.15)
	elif finisher_active():
		box(Rect2(35,111,1370,116),Color(0.025,0.045,0.07,0.90),Color("596b68"))
		draw_titan(Vector2(865,525),0.90)
		for feet in party_feet: draw_ellipse_shadow(feet)
		draw_combat_fx()
		box(Rect2(35,638,1370,232),Color(0.03,0.07,0.1,0.94),Color("596b68"))
	elif model.phase == "battle":
		box(Rect2(25,100,1000,64),Color(0.025,0.045,0.07,0.88))
		box(Rect2(25,548,610,25),Color(0.025,0.045,0.07,0.88))
		draw_titan(Vector2(865,525),0.90)
		for i in range(3):
			draw_ellipse_shadow(party_feet[i])
			if i==selected_hero:
				draw_set_transform(party_feet[i],0,Vector2(1,0.3))
				draw_arc(Vector2.ZERO,32,0,TAU,40,GOLD,2)
				draw_set_transform(Vector2.ZERO)
		draw_combat_fx()
		box(Rect2(25,578,1390,303),Color(0.03,0.07,0.1,0.94),Color("39484c"))
		box(Rect2(25,175,320,353),Color(0.03,0.07,0.1,0.88))
		var hp: float = float(model.boss.get("hp",1))/maxf(1,float(model.boss.get("max_hp",1)))
		draw_rect(Rect2(530,135,490,6),Color("3b4545"))
		draw_rect(Rect2(530,135,490*hp,6),GOLD)
	elif model.phase == "map":
		box(Rect2(45,312,1350,197),Color(0.025,0.06,0.075,0.90),Color("596b68"))
		var node: int=int(model.run.get("node",0))
		for i in range(9):
			var x: float=110+i*145
			var y: float=416
			if i<8:
				for dash in range(7): draw_rect(Rect2(x+28+dash*15,y-2,8,4),GOLD if i<node else Color("596b68"))
			var current: bool=i==node
			var shade: Color=GOLD if current else (TEAL if i<node else Color("596b68"))
			draw_rect(Rect2(x-25,y-25,50,50),shade)
			draw_rect(Rect2(x-21,y-21,42,42),INK)
			if i<node:
				draw_line(Vector2(x-9,y),Vector2(x-2,y+8),TEAL,4)
				draw_line(Vector2(x-2,y+8),Vector2(x+12,y-10),TEAL,4)
			elif i%3==2:
				draw_colored_polygon(PackedVector2Array([Vector2(x-13,y-9),Vector2(x-6,y-2),Vector2(x,y-13),Vector2(x+6,y-2),Vector2(x+13,y-9),Vector2(x+10,y+11),Vector2(x-10,y+11)]),shade)
			else: draw_rect(Rect2(x-6,y-6,12,12),shade)
	else:
		var vignette_key: String=model.phase
		if vignette_key in vignettes:
			draw_texture_rect(vignettes[vignette_key],Rect2(900,104,512,384),false)
		elif model.phase == "defeat":
			draw_titan(Vector2(1080,510),0.7)
		elif model.phase == "victory":
			for feet in victory_feet:
				draw_ellipse_shadow(feet)
	box(Rect2(0,0,1440,87),Color(0.035,0.065,0.09,0.95))
	draw_line(Vector2(35,86),Vector2(1405,86),Color("45504c"),1)

func draw_titan_legacy(origin: Vector2, scale_factor: float) -> void:
	var bob: float = sin(clock_time*1.4)*3
	var base: Vector2 = origin + Vector2(0,bob)
	var stone: Color = Color("58676a").lightened(hit_flash*0.4)
	var dark: Color = Color("273c46")
	if not menu and model.phase=="battle":
		var tier: int=model.boss.get("tier",1)
		if tier==2:
			stone=Color("716176").lightened(hit_flash*0.4)
			dark=Color("342e45")
		elif tier==3:
			stone=Color("8d826b").lightened(hit_flash*0.4)
			dark=Color("463d31")
	var cut: Array = [false,false,false]
	if not menu and model.phase=="battle":
		for i in range(mini(3,model.parts.size())):
			cut[i]=model.parts[i].get("severed",false)
	# Deliberately geometric sculptural colossus, no external art.
	if not cut[0]:
		poly(base,scale_factor,[Vector2(-82,-131),Vector2(-8,-113),Vector2(-25,5),Vector2(-116,5)],dark)
		poly(base,scale_factor,[Vector2(12,-112),Vector2(80,-135),Vector2(116,5),Vector2(25,5)],stone)
		poly(base,scale_factor,[Vector2(44,-104),Vector2(65,-111),Vector2(81,-10),Vector2(48,-10)],dark)
	if not cut[1]:
		poly(base,scale_factor,[Vector2(-100,-289),Vector2(-48,-321),Vector2(71,-300),Vector2(114,-242),Vector2(70,-121),Vector2(-57,-112),Vector2(-104,-210)],stone)
		poly(base,scale_factor,[Vector2(-76,-279),Vector2(-140,-260),Vector2(-176,-139),Vector2(-129,-112),Vector2(-95,-210)],dark)
		poly(base,scale_factor,[Vector2(81,-283),Vector2(143,-248),Vector2(172,-115),Vector2(122,-100),Vector2(104,-207)],stone)
		poly(base,scale_factor,[Vector2(-25,-290),Vector2(26,-271),Vector2(39,-210),Vector2(0,-179),Vector2(-43,-215)],dark)
		draw_circle(base+Vector2(0,-236)*scale_factor,16*scale_factor,TEAL)
		draw_circle(base+Vector2(0,-236)*scale_factor,8*scale_factor,PALE)
	if not cut[2]:
		poly(base,scale_factor,[Vector2(-50,-384),Vector2(36,-391),Vector2(65,-342),Vector2(29,-301),Vector2(-42,-309),Vector2(-68,-353)],stone)
		poly(base,scale_factor,[Vector2(-51,-369),Vector2(37,-368),Vector2(25,-342),Vector2(-38,-343)],dark)
		draw_line(base+Vector2(-32,-354)*scale_factor,base+Vector2(24,-354)*scale_factor,GOLD,5*scale_factor)
		for i in range(5):
			var x: float=-47+i*23
			poly(base,scale_factor,[Vector2(x,-382),Vector2(x-5,-427-abs(i-2)*7),Vector2(x+16,-391)],GOLD)
	for i in range(6):
		var x: float=-60+i*24
		draw_line(base+Vector2(x,-265)*scale_factor,base+Vector2(x+10,-247)*scale_factor,Color("84918c"),1)
	draw_arc(base+Vector2(0,-238)*scale_factor,190*scale_factor,0.1,2.9,50,Color(0.7,0.62,0.41,0.24),1)

func poly(base: Vector2, factor: float, vertices: Array, color: Color) -> void:
	var points = PackedVector2Array()
	for v in vertices:
		points.append(base+v*factor)
	draw_colored_polygon(points,color)

func draw_hero_legacy(pos: Vector2,index: int) -> void:
	var colors: Array=[Color("bb7857"),Color("7db8b8"),Color("a69cc6")]
	var c: Color=colors[index]
	var alive: bool=model.heroes.is_empty() or model.heroes[index].get("hp",0)>0
	if not alive:
		c=Color("394448")
	draw_ellipse_shadow(pos)
	poly(pos,1.0,[Vector2(-17,-53),Vector2(12,-53),Vector2(23,-6),Vector2(-29,-6)],c)
	draw_circle(pos+Vector2(-2,-64),11,Color("cabba2"))
	draw_line(pos+Vector2(-8,-7),pos+Vector2(-10,6),Color("9faaa3"),6)
	draw_line(pos+Vector2(9,-7),pos+Vector2(12,6),Color("9faaa3"),6)
	draw_line(pos+Vector2(15,-39),pos+Vector2(30,-85 if index==1 else -57),GOLD,4)
	if index==selected_hero:
		draw_arc(pos+Vector2(-2,-29),49,0,TAU,36,GOLD,1.5)

func draw_ellipse_shadow(pos: Vector2) -> void:
	draw_set_transform(pos,0,Vector2(1,0.25))
	draw_circle(Vector2.ZERO,34,Color(0,0,0,0.3))
	draw_set_transform(Vector2.ZERO)

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null

func draw_titan(origin: Vector2, scale_factor: float) -> void:
	var variant: int=0
	var cut: Array=[false,false,false]
	var target: int=-1
	if not menu and (model.phase in ["battle","defeat"] or finisher_active()):
		variant=clampi(int(model.boss.get("tier",1))-1,0,2)
		if model.boss.get("name","")=="The Bellkeeper": variant=1
		for i in range(mini(3,model.parts.size())):
			cut[i]=model.parts[i].get("severed",false)
		target=selected_part
	var dissolve: float=0.0
	if finisher_active():
		cut=finisher_cuts.duplicate()
		target=-1
		dissolve=clampf((1.0-finisher_remaining/FINISHER_DURATION-0.30)/0.70,0.0,1.0)
	# The generated actor is a separate scene layer, keeping all UI above it.
	generated_monster.configure(variant,origin,scale_factor,cut,clock_time,hit_flash,target,dissolve)
	draw_set_transform(origin,0,Vector2(1,0.22))
	draw_circle(Vector2.ZERO,125*scale_factor,Color(0,0,0,0.28*(1.0-dissolve)))
	draw_set_transform(Vector2.ZERO)

func draw_hero(pos: Vector2,index: int) -> void:
	if fx_time>0.0 and fx_actor==index and fx_kind!="guard":
		pos.x+=sin((1.0-fx_time/0.85)*PI)*22
	var alive: bool=model.heroes.is_empty() or model.heroes[index].get("hp",0)>0
	draw_ellipse_shadow(pos)
	var bob: float=sin(clock_time*2.0+index)*1.3 if alive else 0.0
	var tint: Color=Color.WHITE if alive else Color(0.3,0.35,0.4,0.6)
	draw_texture_rect(hero_sprites[index],Rect2(pos+Vector2(-30,-87+bob),Vector2(60,90)),false,tint)
	if index==selected_hero:
		draw_set_transform(pos+Vector2(0,5),0,Vector2(1,0.3))
		draw_arc(Vector2.ZERO,36,0,TAU,40,GOLD,2)
		draw_set_transform(Vector2.ZERO)

func draw_combat_fx() -> void:
	if fx_time<=0.0:
		return
	var progress: float=1.0-fx_time/0.85
	var start: Vector2=party_feet[fx_actor]+Vector2(18,-54)
	var offsets: Array=[Vector2(0,-52),Vector2(0,-190),Vector2(0,-309)]
	var target: Vector2=Vector2(865,525)+offsets[fx_part]*0.90
	var legs_cut: bool=bool(finisher_cuts[0]) if finisher_active() else (model.parts.size()>0 and model.parts[0].get("severed",false))
	if legs_cut:
		target.y+=64.0*0.90
	var color: Color=TEAL if fx_kind=="arcane" else GOLD
	if fx_kind=="guard":
		draw_arc(start+Vector2(-18,10),45,0,TAU,32,Color(0.48,0.78,0.72,fx_time),3)
		return
	if progress<0.45:
		var projectile: Vector2=start.lerp(target,progress/0.45)
		draw_line(projectile-Vector2(24,4),projectile,color,3)
		draw_circle(projectile,5 if fx_kind=="arcane" else 2,color)
	else:
		for i in range(14):
			var direction: Vector2=Vector2(cos(i*2.4),sin(i*2.4))
			var distance: float=(progress-0.45)*100
			draw_line(target+direction*distance,target+direction*(distance+10),Color(color,fx_time),2)
		draw_string(font,target+Vector2(-12,-20-progress*34),str(fx_damage),HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color(1,0.86,0.56,fx_time*1.2))

func pixel_frame(variant: String) -> StyleBoxTexture:
	var frame=StyleBoxTexture.new()
	frame.texture=load("res://assets/ui/panel_"+variant+".png")
	frame.texture_margin_left=8
	frame.texture_margin_right=8
	frame.texture_margin_top=8
	frame.texture_margin_bottom=8
	frame.content_margin_left=16
	frame.content_margin_right=16
	frame.content_margin_top=10
	frame.content_margin_bottom=10
	return frame

func meter(rect: Rect2, ratio: float, color: Color) -> void:
	var back=ColorRect.new()
	back.position=rect.position
	back.size=rect.size
	back.color=Color("080f15")
	back.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(back)
	var fill=ColorRect.new()
	fill.position=rect.position
	fill.size=Vector2(rect.size.x*clampf(ratio,0,1),rect.size.y)
	fill.color=color
	fill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(fill)
