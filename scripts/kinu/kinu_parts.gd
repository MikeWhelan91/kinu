class_name KinuParts
extends RefCounted
## The My Kinu parts catalogue. Each row is [id, slot, name, style, colour, accent, source, extra]:
## source is "starter", a rarity ("common", "rare", "epic") for the shop, "crane:<rarity>" for a
## Kinu Catcher exclusive, "level" (extra is the level) or a Kinu Book goal (extra is the amount).
## Shop prices are about 30% of an outfit of the same rarity, so a full look costs about 1.3 outfits.

const PRICES := {"common": [600, 700, 800], "rare": [1150, 1300, 1400], "epic": [1700, 1900, 2000]}

const ROWS := [
	# Body: garments over the lower body. The flavour always shows around the face.
	["comfy_tee", "body", "Comfy Tee", "tee", "f7f3ea", "d9cfc0", "starter", 0],
	["sky_tee", "body", "Sky Tee", "tee", "7fc4f5", "5a9fd4", "common", 0],
	["sailor_stripes", "body", "Sailor Stripes", "stripes", "f7f3ea", "304257", "common", 1],
	["cosy_scarf", "body", "Cosy Scarf", "scarf", "c93f49", "f5c14e", "common", 2],
	["berry_bow_tie", "body", "Berry Bow Tie", "bowtie", "d94e6b", "b8364f", "common", 1],
	["cafe_apron", "body", "Café Apron", "apron", "c98f5a", "fff4df", "rare", 0],
	["mint_hoodie", "body", "Mint Hoodie", "hoodie", "8fdc8a", "6cbf67", "rare", 1],
	["denim_dungarees", "body", "Denim Dungarees", "dungarees", "4f8cc9", "f5c14e", "rare", 2],
	["festival_yukata", "body", "Festival Yukata", "kimono", "2f4f8f", "e8547a", "epic", 1],
	["ballet_tutu", "body", "Ballet Tutu", "tutu", "ffb7cf", "ff8fb0", "crane:rare", 0],
	["swim_ring", "body", "Swim Ring", "swim_ring", "ff8fa3", "fff4df", "crane:legendary", 0],
	["club_jersey", "body", "Club Jersey", "stripes", "2f9e6e", "f7f3ea", "runs", 10],
	["work_overalls", "body", "Work Overalls", "dungarees", "e0a23a", "8a5a2b", "total", 1000],
	["shoyu_bib", "body", "Shoyu Bib", "apron", "f7f3ea", "c47a2c", "glazed", 25],
	["knit_sweater", "body", "Knit Sweater", "sweater", "e87f5a", "fff4df", "level", 15],
	["star_cape_scarf", "body", "Starry Scarf", "scarf", "3b3f8f", "ffe36e", "level", 30],
	["golden_sash", "body", "Golden Sash", "kimono", "f5c14e", "c93f49", "level", 50],
	# Hats: sit on top of the Kinu.
	["little_beanie", "hat", "Little Beanie", "beanie", "e8547a", "f7f3ea", "starter", 0],
	["sunny_cap", "hat", "Sunny Cap", "cap", "ffd34f", "f7f3ea", "common", 0],
	["painter_beret", "hat", "Painter Beret", "beret", "c93f49", "2b1a17", "common", 1],
	["party_hat", "hat", "Party Hat", "party", "7fc4f5", "ffe36e", "common", 2],
	["ribbon_bow", "hat", "Ribbon Bow", "bow", "ff8fb0", "e8547a", "common", 1],
	["bucket_hat", "hat", "Bucket Hat", "bucket", "a3c27a", "7d9a58", "rare", 0],
	["top_hat", "hat", "Top Hat", "top_hat", "2b2730", "c93f49", "rare", 1],
	["chef_hat", "hat", "Chef's Hat", "chef", "fffaf0", "e8e0d0", "rare", 2],
	["flower_crown", "hat", "Flower Crown", "flower_crown", "8fdc8a", "ff8fb0", "epic", 0],
	["straw_hat", "hat", "Straw Hat", "straw", "f2d38a", "c93f49", "epic", 2],
	["witch_hat", "hat", "Witch Hat", "witch", "6a4c9c", "ffe36e", "crane:rare", 0],
	["royal_crown", "hat", "Royal Crown", "crown", "f5c14e", "e8547a", "crane:legendary", 0],
	["halo", "hat", "Halo", "halo", "ffe36e", "fff4df", "crane:legendary", 0],
	["champion_cap", "hat", "Champion Cap", "cap", "304257", "f5c14e", "best", 45],
	["clover_cap", "hat", "Lucky Clover", "sprout", "6cc94c", "4d9a2c", "lucky", 3],
	["sun_hat", "hat", "Sun Hat", "straw", "fff4df", "7fc4f5", "days", 3],
	["bunny_band", "hat", "Bunny Headband", "bunny_band", "f7f3ea", "ffb7cf", "level", 5],
	["cat_band", "hat", "Cat Headband", "cat_band", "3a3440", "ff9fb0", "level", 25],
	["propeller_cap", "hat", "Propeller Cap", "propeller", "e8547a", "7fc4f5", "level", 45],
	# Arms: stubby arms at the sides, with whatever they wear or hold.
	["little_arms", "arms", "Little Arms", "nubs", "ffffff", "ffffff", "starter", 0],
	["cosy_mittens", "arms", "Cosy Mittens", "mittens", "e8547a", "f7f3ea", "common", 0],
	["cartoon_gloves", "arms", "Cartoon Gloves", "gloves", "fffaf0", "e0d6c4", "common", 1],
	["hello_wave", "arms", "Hello Wave", "wave", "ffffff", "ffffff", "common", 2],
	["red_balloon", "arms", "Red Balloon", "balloon", "e84a5f", "f7f3ea", "common", 1],
	["boxing_gloves", "arms", "Boxing Gloves", "boxing", "d8434f", "f7f3ea", "rare", 1],
	["cheer_pompoms", "arms", "Cheer Pom-poms", "pompoms", "ffd34f", "ff8fb0", "rare", 2],
	["little_wings", "arms", "Little Wings", "wings", "fffaf0", "e8e0d0", "epic", 1],
	["bubble_wand", "arms", "Bubble Wand", "wand", "b99cf2", "7fc4f5", "crane:rare", 0],
	["sparklers", "arms", "Sparklers", "sparkler", "ffe36e", "ff9a3c", "crane:legendary", 0],
	["steady_mitts", "arms", "Steady Mitts", "mittens", "4f8cc9", "f7f3ea", "clean", 40],
	["climber_gloves", "arms", "Climber Gloves", "gloves", "e0a23a", "8a5a2b", "height", 600],
	["victory_flag", "arms", "Victory Flag", "flag", "c93f49", "f7f3ea", "level", 20],
	["golden_wings", "arms", "Golden Wings", "wings", "f5c14e", "e0a23a", "level", 40],
	# Glasses: frames around the eyes, so every expression still reads through them.
	["round_specs", "glasses", "Round Specs", "round", "3a3440", "3a3440", "starter", 0],
	["red_frames", "glasses", "Red Frames", "square", "c93f49", "c93f49", "common", 0],
	["star_glasses", "glasses", "Star Glasses", "star", "ffd34f", "e0a23a", "common", 1],
	["heart_glasses", "glasses", "Heart Glasses", "heart", "ff8fb0", "e8547a", "common", 2],
	["thick_frames", "glasses", "Thick Frames", "thick", "2b2730", "2b2730", "common", 1],
	["cool_shades", "glasses", "Cool Shades", "shades", "2b2730", "2b2730", "rare", 1],
	["monocle", "glasses", "Monocle", "monocle", "f5c14e", "f5c14e", "rare", 2],
	["swim_goggles", "glasses", "Swim Goggles", "goggles", "7fc4f5", "304257", "epic", 0],
	["three_d_glasses", "glasses", "3D Glasses", "three_d", "f7f3ea", "e84a5f", "epic", 2],
	["cat_eye_glasses", "glasses", "Cat-eye Glasses", "cat_eye", "b99cf2", "6a4c9c", "crane:rare", 0],
	["taster_specs", "glasses", "Taster's Specs", "round", "8a5a2b", "8a5a2b", "flavours", 12],
	["planner_glasses", "glasses", "Planner Glasses", "square", "4f8cc9", "4f8cc9", "missions", 25],
	["golden_specs", "glasses", "Golden Specs", "round", "f5c14e", "f5c14e", "level", 10],
	["star_shades", "glasses", "Star Shades", "shades", "6a4c9c", "ffe36e", "level", 35],
]

const DESCRIPTIONS := {
	"body": "Worn below the face, so My Kinu's flavour still shows.",
	"hat": "Sits on top of every Kinu you drop.",
	"arms": "Little arms for every Kinu you drop.",
	"glasses": "Sits over the eyes of every Kinu you drop.",
}

static var _built: Array[KinuPart] = []

static func all() -> Array[KinuPart]:
	if _built.is_empty():
		for row in ROWS:
			_built.append(_make(row))
	return _built

static func find(id: String) -> KinuPart:
	for part in all():
		if part.id == id:
			return part
	return null

static func _make(row: Array) -> KinuPart:
	var part := KinuPart.new()
	part.id = row[0]
	part.slot = row[1]
	part.display_name = row[2]
	part.style = row[3]
	part.color = Color(row[4])
	part.accent = Color(row[5])
	part.description = DESCRIPTIONS[part.slot]
	var source: String = row[6]
	var extra: int = row[7]
	if source == "starter":
		part.starter = true
	elif source == "level":
		part.level = extra
	elif source.begins_with("crane:"):
		part.crane_only = true
		part.rarity = source.trim_prefix("crane:")
	elif PRICES.has(source):
		part.rarity = source
		part.price = PRICES[source][clampi(extra, 0, 2)]
	else:
		part.goal = source
		part.goal_amount = extra
	return part
