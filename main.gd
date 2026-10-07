extends Node2D

const Model = preload("res://model.gd")
const HeroAnimation = preload("res://animated_hero.gd")
const GOLD = Color("d6b77d")
const TEAL = Color("78c9be")
const INK = Color("0e171e")
const PALE = Color("e4e5db")
var model = Model.new()
var forest: Texture2D = preload("res://assets/cinder_forest.png")
var titan_sprites: Array = []
var hero_sprites: Array = []
var actors: Array[Node2D]=[]
var environments: Array[Texture2D]=[]
var party_feet: Array[Vector2]=[Vector2(420,480),Vector2(520,510),Vector2(620,540)]
var ui: Control
var selected_hero: int = 0
var selected_part: int = 0
var clock_time: float = 0.0
var menu: bool = true
var help_open: bool = false
var muted: bool = false
var message: String = ""
var hit_flash: float = 0.0
var fx_time: float=0.0
var fx_actor: int=0
var fx_part: int=0
var fx_kind: String="slash"
var fx_damage: int=0
var enemy_flash: float=0.0
var audio: AudioStreamPlayer
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	RenderingServer.set_default_clear_color(INK)
	if ResourceLoader.exists("res://assets/fonts/PixelifySans.ttf"):
		font=load("res://assets/fonts/PixelifySans.ttf")
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for tier in range(1,4):
		var layers: Array=[]
		for part in range(3):
			layers.append(load("res://assets/titan_%d_%d.png" % [tier,part]))
		titan_sprites.append(layers)
	for i in range(3):
		hero_sprites.append(load("res://assets/hero_%d.png" % i))
	model.load_meta()
	model.load_resume()
	for i in range(3):
		var actor: Node2D=HeroAnimation.new()
		actor.hero_index=i
		actor.facing="right"
		actor.position=party_feet[i]
		actor.scale=Vector2(1.25,1.25)
		add_child(actor)
		actors.append(actor)
	for path in ["cinder_forest","drowned_reliquary","pale_throne"]:
		var file: String="res://assets/environments/"+path+".png"
		environments.append(load(file) as Texture2D if ResourceLoader.exists(file) else forest)
	ui = Control.new()
	add_child(ui)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	refresh()

func _process(delta: float) -> void:
	clock_time += delta
	hit_flash = maxf(0.0, hit_flash - delta * 2.0)
	fx_time=maxf(0.0,fx_time-delta)
	enemy_flash=maxf(0.0,enemy_flash-delta*2)
	for i in range(actors.size()):
		var actor: Node2D=actors[i]
		actor.visible=not menu and model.phase=="battle"
		actor.position=party_feet[i]
		if actor.visible and model.heroes.size()==3:
			if model.heroes[i].hp<=0 and actor.state!="death": actor.play_state("death",true)
			elif model.heroes[i].hp>0 and actor.state=="death": actor.play_state("idle",true)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_V:
		get_tree().change_scene_to_file("res://character_studio.tscn")
	elif key == KEY_H:
		help_open = not help_open
		refresh()
	elif key == KEY_M:
		muted = not muted
		refresh()
	elif key == KEY_ESCAPE:
		if help_open:
			help_open = false
		else:
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
			selected_part = (selected_part + 2) % 3
			refresh()
		elif key == KEY_DOWN:
			selected_part = (selected_part + 1) % 3
			refresh()
		elif key == KEY_SPACE:
			finish_round()

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

func button(text: String, rect: Rect2, action: Callable, active: bool = false, disabled: bool = false) -> Button:
	var b = Button.new()
	b.text = wrap_button(text, rect.size.x - 34)
	b.position = rect.position
	b.size = rect.size
	b.disabled = disabled
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_font_override("font",font)
	b.add_theme_color_override("font_color", GOLD if active else PALE)
	b.add_theme_stylebox_override("normal", pixel_frame("gold" if active else "normal"))
	b.add_theme_stylebox_override("hover", pixel_frame("hover"))
	b.add_theme_stylebox_override("pressed", pixel_frame("gold"))
	b.add_theme_stylebox_override("disabled", pixel_frame("disabled"))
	b.pressed.connect(action)
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

func show_menu() -> void:
	label_at("THE GODS LEFT THEIR CROWNS.", Vector2(70, 192), 18, TEAL)
	label_at("We learned\nto break them.", Vector2(65, 233), 62, PALE)
	paragraph("Three wanderers. Nine crossings. One hollow throne.\nRead the omen. Break a defense. Sever the source of its power.", Vector2(72, 405), 620, 21)
	button("BEGIN A NEW CYCLE", Rect2(72, 525, 330, 62), begin_run, true)
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
	model.new_run(int(Time.get_unix_time_from_system()) % 1000000)
	menu = false
	selected_hero = 0
	selected_part = 0
	message = ""
	refresh()

func upgrade(key: String) -> void:
	var success: bool = model.buy_upgrade(key)
	message = "Legacy strengthened." if success else model.last_error
	refresh()

func show_battle() -> void:
	label_at("%02d  /  %s" % [int(model.run.get("node",0))+1, model.boss.get("name", "The Uncrowned")], Vector2(40, 104), 28, PALE)
	label_at("ROUND %d  /  %d ACTIONS LEFT" % [model.round_number, model.actions_remaining()], Vector2(40, 145), 15, TEAL)
	label_at("TITAN  %d / %d" % [model.boss.get("hp",0), model.boss.get("max_hp",0)], Vector2(530, 103), 15, GOLD)
	paragraph("OMEN  /  " + model.intent.get("name", "Waiting"), Vector2(40, 195), 330, 23, GOLD)
	paragraph(model.intent.get("description", ""), Vector2(40, 239), 300, 18)
	label_at("1  CHOOSE HERO    2  TARGET A PART    3  USE A SKILL", Vector2(40, 553), 14, TEAL)
	for i in range(model.parts.size()):
		var p: Dictionary = model.parts[i]
		var status: String = "SEVERED" if p.get("severed",false) else ("BROKEN" if p.get("broken",false) else "SHIELD %d" % p.get("shield",0))
		var t: String = "%s · %s\n%s  |  HP %d/%d\nWeak: %s" % [str(p.get("level","")), p.get("name",""), status, p.get("hp",0), p.get("max_hp",0), str(p.get("weakness",""))]
		var b = button(t, Rect2(1080, 183+i*119, 320, 104), select_part.bind(i), i == selected_part, p.get("severed",false))
		b.add_theme_font_size_override("font_size", 17)
	for i in range(model.heroes.size()):
		var h: Dictionary = model.heroes[i]
		var t: String = "%d  %s  /  %s\nHP %d/%d   MP %d/%d  %s" % [i+1, h.get("name",""), h.get("role",""), h.get("hp",0), h.get("max_hp",0), h.get("mp",0), h.get("max_mp",0), "ACTED" if h.get("acted",false) else "READY"]
		var hero_button=button(t, Rect2(40+i*455, 592, 440, 84), select_hero.bind(i), i == selected_hero, h.get("hp",0)<=0)
		var portrait=AtlasTexture.new()
		portrait.atlas=load("res://assets/heroes/"+["mara","ivo","sable"][i]+".png")
		portrait.region=Rect2(22,4,52,48)
		hero_button.icon=portrait
		hero_button.expand_icon=true
		hero_button.add_theme_constant_override("icon_max_width",42)
		meter(Rect2(99+i*455,662,170,4),float(h.hp)/maxf(1,float(h.max_hp)),Color("a7c48e"))
		meter(Rect2(280+i*455,662,177,4),float(h.mp)/maxf(1,float(h.max_mp)),Color("79b6bf"))
	var hero: Dictionary = model.heroes[selected_hero]
	var skills: Array = hero.get("skills",[])
	for i in range(skills.size()):
		var skill: Dictionary = skills[i]
		var keys: Array = ["Q", "W", "E", "R"]
		var b = button("%s  %s\n%s  ·  %d MP" % [keys[i], skill.get("name",""), skill.get("type","").to_upper(), skill.get("cost",0)], Rect2(40+i*250, 697, 235, 68), perform.bind(i), false, hero.get("acted",false) or hero.get("hp",0)<=0 or hero.get("mp",0)<skill.get("cost",0))
		b.tooltip_text = skill.get("description","")
		var icon_path: String="res://assets/ui/"+skill.get("type","slash")+".png"
		if ResourceLoader.exists(icon_path):
			b.icon=load(icon_path)
			b.expand_icon=true
			b.add_theme_constant_override("icon_max_width",22)
	button("SPACE\nEND ROUND", Rect2(1060, 697, 340, 68), finish_round, true)
	var lines: Array = model.log.slice(maxi(0,model.log.size()-3))
	paragraph("\n".join(lines), Vector2(42, 790), 1320, 16, Color("adc0bd"))
	if not message.is_empty():
		label_at(message, Vector2(40, 505), 17, GOLD)

func select_hero(index: int) -> void:
	selected_hero = index
	message = ""
	refresh()

func select_part(index: int) -> void:
	selected_part = index
	message = ""
	refresh()

func perform(index: int) -> void:
	var before_hp: int=int(model.boss.get("hp",0))
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
	enemy_flash=0.7
	var before: Array[int]=[]
	for hero in model.heroes:before.append(hero.hp)
	model.end_round()
	for i in range(mini(actors.size(),model.heroes.size())):
		if model.heroes[i].hp<=0:actors[i].play_state("death",true)
		elif model.heroes[i].hp<before[i]:actors[i].play_state("hurt",true)
	tone(70,0.2)
	selected_hero = 0
	for i in range(model.heroes.size()):
		if model.heroes[i].get("hp",0)>0:
			selected_hero = i
			break
	refresh()

func show_map() -> void:
	label_at(model.title.to_upper(), Vector2(60, 115), 39, PALE)
	label_at("Crossing %d of 9  /  Choose your next encounter" % (int(model.run.get("node",0))+1), Vector2(63, 168), 20, TEAL)
	paragraph("A crown is not broken in a single blow. Rest when wounded, gather relics, and choose what kind of memory you leave behind.", Vector2(65, 227), 600, 22)
	for i in range(model.choices.size()):
		var c: Dictionary = model.choices[i]
		button(c.get("name","Road") + "\n\n" + c.get("description",""), Rect2(65+i*440, 540, 410, 157), travel.bind(i), i==0)
	party_summary(740)
	if model.log.size()>0:
		paragraph(model.log[-1],Vector2(65,850),1300,15,GOLD)

func travel(index: int) -> void:
	model.travel(index)
	selected_part = 0
	selected_hero = 0
	message = ""
	refresh()

func show_choices(options: Array, title_text: String, description: String, reward: bool) -> void:
	label_at(title_text.to_upper(), Vector2(65, 140), 37, GOLD)
	paragraph(description, Vector2(68, 210), 720, 23)
	for i in range(options.size()):
		var c: Dictionary = options[i]
		var action: Callable = choose_reward.bind(i) if reward else choose_event.bind(i)
		button(c.get("name","Choice") + "\n\n" + c.get("description",""), Rect2(65+i*440, 520, 410, 176), action, i==0)
	party_summary(750)
	if not message.is_empty():
		label_at(message,Vector2(65,458),19,GOLD)

func choose_reward(index: int) -> void:
	model.choose_reward(index)
	tone(440,0.2)
	refresh()

func choose_event(index: int) -> void:
	if not model.choose_event(index):
		message=model.last_error
	else:
		message=""
	refresh()

func party_summary(y: int) -> void:
	for i in range(model.heroes.size()):
		var h: Dictionary = model.heroes[i]
		label_at("%s   %d / %d HP" % [h.get("name",""),h.get("hp",0),h.get("max_hp",0)], Vector2(65+i*440,y),22,TEAL)
	var names: Array[String]=[]
	for relic in model.run.get("relics",[]):
		names.append(relic.get("name","Relic"))
	label_at("Relics: " + (", ".join(names) if not names.is_empty() else "None yet"), Vector2(65,y+48),16,Color("91a6a7"))

func show_ending() -> void:
	var won: bool = model.phase == "victory"
	label_at("THE CROWN IS SILENT" if won else "THE ASH REMEMBERS", Vector2(65, 210), 50, GOLD)
	paragraph("The wanderers leave the throne empty. Beyond the mist, another road begins." if won else "Your journey ends here. Its lessons remain. Spend your ash on a lasting legacy, then return stronger.", Vector2(70,310),650,25)
	label_at("Titans overcome: %d   •   Karma: %+d" % [model.run.get("bosses_defeated",0),model.run.get("karma",0)],Vector2(70,445),22,TEAL)
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
	paragraph("1. Select a hero, then one of the titan's three body parts.\n2. Match a skill's type to the part's weakness to break its shield.\n3. Keep attacking the broken part. Depleting its HP severs it and removes its move.\n4. Each living hero acts once per round. End Round resolves the visible omen.\n5. Guard to reduce damage and conserve strength. MP recovers each round.\n6. Between battles, choose relics, rests and moral encounters. Death earns a new beginning; ash upgrades persist.\n\nMouse: click heroes, parts, skills and choices\nKeyboard: 1–3 hero • ↑/↓ target • Q/W/E attack • R guard\nSpace end round • V character studio • H guide • M sound • Esc menu\n\nThere are no timers. Hover a skill for its detailed effect.\nYour journey and legacy save after every choice. Resume from the title screen.",Vector2(285,200),850,21)
	button("CLOSE GUIDE",Rect2(855,716,285,50),func(): help_open=false; refresh(),true)

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
	if menu or model.phase=="battle":
		var biome: int=clampi(int(model.run.get("node",0))/3,0,2)
		draw_texture_rect(environments[biome] if environments.size()==3 else forest,Rect2(0,0,1440,900),false)
		if menu:
			draw_rect(Rect2(0,80,680,820),Color(0.035,0.06,0.075,0.65))
		# soft grounded arena shadow
		for i in range(6):
			draw_rect(Rect2(0,560+i*9,1440,12),Color(0.03,0.065,0.08,0.07+i*0.03))
	if menu:
		draw_titan(Vector2(1020,598),1.15)
	elif model.phase == "battle":
		draw_titan(Vector2(865,525),0.90)
		for i in range(3):
			draw_ellipse_shadow(party_feet[i])
			if i==selected_hero:
				draw_set_transform(party_feet[i],0,Vector2(1,0.3))
				draw_arc(Vector2.ZERO,32,0,TAU,40,GOLD,2)
				draw_set_transform(Vector2.ZERO)
		draw_combat_fx()
		box(Rect2(25,578,1390,303),Color(0.03,0.07,0.1,0.94),Color("39484c"))
		box(Rect2(25,175,320,306),Color(0.03,0.07,0.1,0.8))
		var hp: float = float(model.boss.get("hp",1))/maxf(1,float(model.boss.get("max_hp",1)))
		draw_rect(Rect2(530,135,490,6),Color("3b4545"))
		draw_rect(Rect2(530,135,490*hp,6),GOLD)
	elif model.phase == "map":
		for i in range(9):
			var x: float=110+i*145
			var y: float=405+sin(i*0.95)*35
			if i<8:
				draw_line(Vector2(x,y),Vector2(x+145,405+sin((i+1)*0.95)*35),Color("596b68"),2)
			var current: bool = i==int(model.run.get("node",0))
			draw_circle(Vector2(x,y),20 if current else 12,GOLD if current else Color("536b6d"))
			draw_circle(Vector2(x,y),9 if current else 5,INK)
	else:
		draw_titan(Vector2(1080,510),0.7)
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
	var tier: int = 1
	var cut: Array=[false,false,false]
	if not menu and model.phase=="battle":
		tier=int(model.boss.get("tier",1))
		for i in range(mini(3,model.parts.size())):
			cut[i]=model.parts[i].get("severed",false)
	if cut[0]:
		origin.y+=80*scale_factor
	var pos: Vector2=origin+Vector2(-170,-440)*scale_factor
	var dimension: Vector2=Vector2(340,440)*scale_factor
	draw_set_transform(origin,0,Vector2(1,0.22))
	draw_circle(Vector2.ZERO,125*scale_factor,Color(0,0,0,0.28))
	draw_set_transform(Vector2.ZERO)
	for part in range(3):
		if not cut[part]:
			var bob: float=sin(clock_time*1.4)*2 if part>0 else 0.0
			draw_texture_rect(titan_sprites[tier-1][part],Rect2(pos+Vector2(0,bob),dimension),false,Color(1+hit_flash,1+hit_flash,1+hit_flash))
	if not menu and model.phase=="battle" and selected_part<3 and not cut[selected_part]:
		var offsets: Array=[Vector2(0,-65),Vector2(0,-242),Vector2(0,-371)]
		var target: Vector2=origin+offsets[selected_part]*scale_factor
		draw_arc(target,27*scale_factor,clock_time,clock_time+4.9,24,GOLD,2)

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
	var offsets: Array=[Vector2(0,-65),Vector2(0,-242),Vector2(0,-371)]
	var target: Vector2=Vector2(865,525)+offsets[fx_part]*0.90
	if model.parts.size()>0 and model.parts[0].get("severed",false):
		target.y+=72.0
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
