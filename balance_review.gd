extends SceneTree
## Reproducible policy comparisons. These are rules simulations, not human difficulty tests.
const Model=preload("res://model.gd")
func fresh(seed_value: int, rank: int=0):
	var m=Model.new()
	m.persist_meta=false
	m.meta={"essence":0,"upgrades":{"vitality":rank,"force":rank,"focus":rank},"runs":0,"wins":0}
	m.new_run(seed_value)
	return m
func _initialize():
	for config in ["break_finish_heal","break_finish_tribute","random_heal","random_tribute","basic_spread_heal","max_legacy_basic_tribute","max_legacy_break_tribute"]:
		var wins: int=0
		var min_hp: int=99999
		var end_hp: int=0
		var sum_essence: int=0
		var rounds: int=0
		var fights: int=0
		var max_rounds: int=0
		var final_gold: int=0
		for seed_value in range(1001,1101):
			var m=fresh(seed_value,5 if config.begins_with("max_legacy") else 0)
			var rng=RandomNumberGenerator.new()
			rng.seed=seed_value
			var steps: int=0
			while m.phase not in ["victory","defeat"] and steps<300:
				steps+=1
				match m.phase:
					"map":
						var pick: int=0
						for i in range(m.choices.size()):
							if m.choices[i].kind in ["battle","boss"]: pick=i
						m.travel(pick)
					"battle":
						for h in range(3):
							if m.phase!="battle":break
							if m.heroes[h].hp<=0:continue
							var target: int=0
							var intact: Array=[]
							for p in range(3):
								if not m.parts[p].severed:intact.append(p)
							target=intact[0]
							var skill: int=0
							if "break" in config:
								if m.parts[target].broken and m.heroes[h].mp>=3:skill=2
								elif m.heroes[h].mp>=m.heroes[h].skills[1].cost:skill=1
							elif "random" in config:
								target=intact[rng.randi_range(0,intact.size()-1)]
								var legal: Array=[]
								for s in range(4):
									if m.heroes[h].mp>=m.heroes[h].skills[s].cost:legal.append(s)
								skill=legal[rng.randi_range(0,legal.size()-1)]
							elif "spread" in config:target=intact[h%intact.size()]
							assert(m.act(h,skill,target))
						if m.phase=="battle":m.end_round()
						else:
							rounds+=m.round_number
							max_rounds=maxi(max_rounds,m.round_number)
							fights+=1
					"reward":m.choose_reward(1 if "tribute" in config else 0)
					_:
						if not m.choose_event(0):assert(m.choose_event(1))
			if m.phase=="victory":wins+=1
			var hp: int=0
			for h in m.heroes:hp+=h.hp
			min_hp=mini(min_hp,hp)
			end_hp+=hp
			sum_essence+=m.meta.essence
			final_gold+=m.run.gold
		print(config,": wins=",wins,"/100 min_end_hp=",min_hp," avg_end_hp=",float(end_hp)/100," avg_essence=",float(sum_essence)/100," avg_end_gold=",float(final_gold)/100," avg_rounds=",float(rounds)/maxi(1,fights)," max_fight_rounds=",max_rounds)
	var early=fresh(1)
	var exploitable_seeds: int=0
	for seed_value in range(1,101):
		early=fresh(seed_value)
		for c in early.choices:
			if c.kind in ["event","relic"]:
				exploitable_seeds+=1
				break
	print("EARLY_BANK_OPTIONS: ",exploitable_seeds,"/100 seeds offer noncombat essence at crossing 1")
	var m=fresh(1)
	var farm_seed: int=1
	while true:
		m.new_run(farm_seed)
		var idx: int=-1
		for i in range(m.choices.size()):
			if m.choices[i].kind=="relic":idx=i
		if idx>=0:
			m.travel(idx)
			m.choose_event(1)
			print("FARM: seed=",farm_seed," after first shrine run essence=",m.run.essence," gold=",m.run.gold)
			m.new_run(farm_seed)
			print("FARM: after abandon/restart bank=",m.meta.essence," reset gold=",m.run.gold," hero HP=",m.heroes[0].hp)
			break
		farm_seed+=1
	quit()
