extends RefCounted
## Construct accepted action events from actual state differences, never damage previews.
const Anchors = preload("res://combat_fx/fx_anchors.gd")
const SKILLS: Array = [["mara_oathblade","mara_anvil_blow","mara_sundering_arc","guard"],["ivo_ash_spark","ivo_hollow_hymn","ivo_blood_lantern","guard"],["sable_needle_shot","sable_raking_hook","sable_last_mercy","guard"]]
static func hero_event(id: int, before, after, hero: int, skill: int, part: int) -> Dictionary:
	var guard: bool = str(before.heroes[hero].skills[skill].type) == "guard"
	var old: Dictionary = before.parts[part] if not guard else {}
	var now: Dictionary = after.parts[part] if not guard else {}
	var heals: Array = []
	for i in range(before.heroes.size()):
		var amount: int = int(after.heroes[i].hp)-int(before.heroes[i].hp)
		if amount > 0: heals.append({"hero":i,"amount":amount})
	return {"event_id":id,"kind":"guard" if guard else "hero","hero_index":hero,"skill_id":SKILLS[hero][skill],"damage_type":str(before.heroes[hero].skills[skill].type),"target_part":part,"from_anchor":Anchors.hero(hero),"to_anchor":Anchors.hero(hero) if guard else Anchors.monster(part,Anchors.cuts(before.parts)),"before":before,"after":after,"actual_hp_loss":0 if guard else maxi(0,int(old.hp)-int(now.hp)),"actual_boss_loss":maxi(0,int(before.boss.hp)-int(after.boss.hp)),"actual_shield_loss":0 if guard else maxi(0,int(old.shield)-int(now.shield)),"weakness":not guard and not old.broken and str(old.weakness)==str(before.heroes[hero].skills[skill].type),"breaks":not guard and not old.broken and now.broken,"severs":not guard and not old.severed and now.severed,"heals":heals,"phase_after":after.phase,"presentation_seed":id*7919+hero*131+part*17}

static func round_events(id: int, before, after, forecast: Dictionary) -> Array[Dictionary]:
	# The model itself resolves this same frozen sequential contract. Do not retarget.
	var events: Array[Dictionary] = []
	var remaining: Array = before.heroes.duplicate(true)
	for attack in forecast.attacks:
		var display_before: Array = remaining.duplicate(true)
		var wards: Array = []
		for target in attack.targets:
			if attack.status not in ["cancelled","missed"] and bool(attack.wardable) and remaining[target].hp > 0 and bool(remaining[target].guard) and int(attack.losses[target])==0: wards.append(target)
		for i in range(remaining.size()):
			remaining[i].hp -= int(attack.losses[i])
			remaining[i].mp -= int(attack.focus_losses[i])
		events.append({"event_id":id+events.size(),"kind":"enemy","hero_index":-1,"skill_id":str(attack.name),"damage_type":"enemy","target_part":int(attack.part),"from_anchor":Anchors.monster(int(attack.part),Anchors.cuts(before.parts)),"to_anchor":Vector2.ZERO,"before":before,"after":after,"actual_hp_loss":0,"actual_shield_loss":0,"weakness":false,"breaks":false,"severs":false,"heals":[],"phase_after":after.phase,"presentation_seed":(id+events.size())*7919,"attack":attack.duplicate(true),"wards":wards,"display_before_heroes":display_before,"display_heroes":remaining.duplicate(true),"rhythm":forecast.get("rhythm",{}).duplicate(true)})
	return events
