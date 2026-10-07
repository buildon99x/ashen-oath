extends SceneTree
const Model = preload("res://model.gd")
func _initialize() -> void:
	var wins: int=0
	var losses: int=0
	for seed_value in range(1001,1051):
		var m = Model.new()
		m.persist_meta=false
		m.meta={"essence":0,"upgrades":{"vitality":0,"force":0,"focus":0},"runs":0,"wins":0}
		m.new_run(seed_value)
		var steps: int=0
		while m.phase not in ["victory","defeat"] and steps<300:
			steps+=1
			match m.phase:
				"map":
					var pick: int=0
					for i in range(m.choices.size()):
						if m.choices[i].kind in ["camp","relic"]: pick=i
					m.travel(pick)
				"battle":
					for h in range(3):
						if m.phase!="battle": break
						if m.heroes[h].hp<=0 or m.heroes[h].acted: continue
						var target: int=0
						for p in range(3):
							if not m.parts[p].severed:
								target=p
								break
						var skill: int=0
						if m.parts[target].broken and m.heroes[h].mp>=3: skill=2
						elif m.heroes[h].mp>=m.heroes[h].skills[1].cost: skill=1
						assert(m.act(h,skill,target))
					if m.phase=="battle": m.end_round()
				"reward": m.choose_reward(0)
				_: 
					var accepted: bool=m.choose_event(0)
					if not accepted: accepted=m.choose_event(1)
					assert(accepted)
		assert(m.phase in ["victory","defeat"],"Campaign must terminate")
		if m.phase=="victory": wins+=1
		else: losses+=1
		for hero in m.heroes:
			assert(hero.hp>=0 and hero.hp<=hero.max_hp)
			assert(hero.mp>=0 and hero.mp<=hero.max_mp)
	print("CAMPAIGN STRESS PASSED: 50 seeds, ",wins," wins, ",losses," defeats; no hangs or invalid HP/MP. Scripted rules play, not human screen play.")
	quit(0)
