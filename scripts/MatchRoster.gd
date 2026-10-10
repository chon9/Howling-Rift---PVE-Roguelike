class_name MatchRoster
extends RefCounted
static var previous_enemies: Array = []
static func enemy_team(allies: Array) -> Array:
 var fresh=ChampionData.CHAMPIONS.keys().filter(func(key):return not allies.has(key) and not previous_enemies.has(key))
 fresh.shuffle()
 var fallback=ChampionData.CHAMPIONS.keys().filter(func(key):return not allies.has(key) and not fresh.has(key))
 fallback.shuffle();fresh.append_array(fallback)
 previous_enemies=fresh.slice(0,3)
 return previous_enemies.duplicate()
