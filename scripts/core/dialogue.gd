class_name Dialogue
extends RefCounted
## Frases al azar de héroes, enemigos y personajes. Sin lógica de juego: solo color.
## Cada entrada: id de quien habla -> contexto -> frases. "any" sirve para cualquier enemigo.

const LINES := {
	&"warrior": {
		&"enter": ["Shields up. Stay behind me.", "I'll hold the line.", "Another room, another fight."],
		&"boss": ["That's the big one. Steady.", "We end this here."],
		&"crit": ["Down you go!", "Felt that one?"],
		&"low_hp": ["I can still stand...", "Cleric, a little help!"],
		&"victory": ["Clear. Catch your breath.", "Nothing gets past this shield."],
	},
	&"cleric": {
		&"enter": ["The light goes with us.", "Mind the shadows.", "Stay close to the torch."],
		&"boss": ["Such darkness... stay together!", "May the light hold."],
		&"crit": ["Smite!", "By the flame!"],
		&"low_hp": ["I need a moment...", "My prayers are fading."],
		&"victory": ["Everyone in one piece?", "Bless this little victory."],
	},
	&"assassin": {
		&"enter": ["I'll take the ones in the back.", "Quiet now.", "Smells like gold. Or rot."],
		&"boss": ["Big ones bleed too.", "Find the weak spot. Strike."],
		&"crit": ["Right between the ribs.", "Too slow."],
		&"low_hp": ["That stings...", "Not my best day."],
		&"victory": ["Easy coin.", "Check their pockets."],
	},
	&"lich": {&"boss": ["Your torch is nearly out, little mortals.", "Join my endless court."]},
	&"tide_wraith": {&"boss": ["The water remembers every drowned soul.", "Sink with me."]},
	&"iron_colossus": {&"boss": ["INTRUDERS. MELT.", "THE FORGE BURNS FOREVER."]},
	&"any": {&"enter": ["Fresh meat!", "Turn back!", "Hssss...", "More for the pit!"]},
	&"keeper": {
		&"camp": [
			"Retreating isn't losing. You keep everything you carry.",
			"Out of light? Supplies can still save the run.",
			"Elites hit hard, but they drop shards.",
			"Spend your shards in the Constellation, friend.",
			"The deeper you go, the angrier they get.",
			"Rest when you need it. Pride never healed anyone.",
		],
	},
	&"spirit": {
		&"shrine": ["Take my flame, travelers.", "Light for the lost.", "Burn bright, little ones."],
	},
}


## Una frase al azar, o "" si ese personaje no tiene nada para ese momento.
static func line(speaker: StringName, context: StringName) -> String:
	var table: Dictionary = LINES.get(speaker, LINES[&"any"])
	var options: Array = table.get(context, [])
	if options.is_empty():
		return ""
	return options[randi() % options.size()]
