class_name KinuParts
extends RefCounted
## The My Kinu parts catalogue. Each row is [id, slot, name, style, colour, accent, source, extra]:
## source is "starter", a rarity ("common", "rare", "epic") for the shop, "crane:<rarity>" for a
## Kinu Catcher exclusive, "level" (extra is the level) or a Kinu Book goal (extra is the amount).
## Shop prices are about 30% of an outfit of the same rarity, so a full look costs about 1.3 outfits.

const PRICES := {"common": [600, 700, 800], "rare": [1150, 1300, 1400], "epic": [1700, 1900, 2000]}

const ROWS := [
	# Body: garments over the lower body. The flavour always shows around the face.
	["comfy_tee", "body", "Comfy Tee", "tee", "c4a9e8", "7656a8", "starter", 0],
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
	# New silhouettes and fabric stories: soft layers, café wear and festival colours.
	["rainy_day_coat", "body", "Rainy Day Coat", "raincoat", "f7c648", "f7f3ea", "runs", 20],
	["strawberry_cardigan", "body", "Strawberry Cardigan", "varsity", "f38b9f", "fff4df", "total", 2500],
	["matcha_patchwork", "body", "Matcha Patchwork", "patchwork", "87b66e", "f1df9b", "clean", 80],
	["midnight_haori", "body", "Midnight Haori", "kimono", "343f71", "b7a0e8", "days", 5],
	["cloud_pajamas", "body", "Cloud Pajamas", "stripes", "9bc5ed", "fff4df", "missions", 40],
	["honey_waistcoat", "body", "Honey Waistcoat", "vest", "cf9045", "fff0c1", "glazed", 75],
	["picnic_overalls", "body", "Picnic Overalls", "dungarees", "dc675f", "fff4df", "best", 55],
	["citrus_windbreaker", "body", "Citrus Windbreaker", "raincoat", "f5a43a", "f7e961", "common", 1],
	["lilac_quilt", "body", "Lilac Quilt", "patchwork", "b59bdc", "f5c7dc", "rare", 0],
	["tea_shop_vest", "body", "Tea Shop Vest", "vest", "5b937d", "f7e3b4", "rare", 1],
	["aurora_raincoat", "body", "Aurora Raincoat", "raincoat", "4f8ea5", "dc8bc8", "epic", 0],
	["moonlit_cape", "body", "Moonlit Cape", "scarf", "444578", "e9d46b", "crane:rare", 0],
	["festival_confetti", "body", "Festival Confetti", "patchwork", "ee8d69", "77c7b0", "crane:legendary", 0],
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
	["mushroom_cap", "hat", "Mushroom Cap", "mushroom", "d95b58", "fff4df", "flavours", 16],
	["rainbow_headphones", "hat", "Rainbow Headphones", "headphones", "b18de0", "f5c14e", "missions", 60],
	["fox_ears", "hat", "Fox Ears", "cat_band", "d68b4e", "fff4df", "lucky", 8],
	["night_market_beret", "hat", "Night Market Beret", "beret", "3f4b77", "e4b2ce", "days", 7],
	["peach_blossom_crown", "hat", "Peach Blossom Crown", "flower_crown", "99bf78", "f8a3b6", "total", 4000],
	["stargazer_cap", "hat", "Stargazer Cap", "cap", "42477b", "eecb71", "best", 65],
	["tofu_mushroom", "hat", "Tofu Mushroom", "mushroom", "f4dec0", "cd916f", "common", 1],
	["mint_headphones", "hat", "Mint Headphones", "headphones", "81c4ac", "fff4df", "rare", 0],
	["sunset_bucket", "hat", "Sunset Bucket", "bucket", "df8365", "f5ce77", "epic", 0],
	["plum_mushroom", "hat", "Plum Mushroom", "mushroom", "a76c9c", "f4d8ec", "crane:rare", 0],
	["comet_headphones", "hat", "Comet Headphones", "headphones", "47538d", "f7d46b", "crane:legendary", 0],
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
	["paper_lantern", "arms", "Paper Lantern", "lantern", "e96962", "fff1d3", "runs", 30],
	["peach_lollipop", "arms", "Peach Lollipop", "lollipop", "f394aa", "fff4df", "total", 3000],
	["parade_maracas", "arms", "Parade Maracas", "maracas", "edb450", "e26965", "lucky", 10],
	["baker_mitts", "arms", "Baker Mitts", "mittens", "e6bd83", "fff4df", "glazed", 100],
	["rainbow_flags", "arms", "Rainbow Flags", "flag", "7cb8dd", "f4ca64", "missions", 75],
	["plum_wings", "arms", "Plum Wings", "wings", "a979c7", "f5c0e6", "height", 900],
	["mint_pompoms", "arms", "Mint Pom-poms", "pompoms", "8fd2ac", "fff4df", "common", 0],
	["sky_balloon", "arms", "Sky Balloon", "balloon", "82bee8", "f7f3ea", "common", 1],
	["lemon_lollipop", "arms", "Lemon Lollipop", "lollipop", "f4d960", "fff4df", "common", 2],
	["lucky_lantern", "arms", "Lucky Lantern", "lantern", "82c072", "e8da76", "rare", 0],
	["cocoa_maracas", "arms", "Cocoa Maracas", "maracas", "a16f5a", "f6e0a7", "rare", 1],
	["violet_boxing", "arms", "Violet Boxing Gloves", "boxing", "a16cc8", "f7e9bd", "rare", 2],
	["sunburst_wings", "arms", "Sunburst Wings", "wings", "efa75a", "f9dc78", "epic", 1],
	["moon_lantern", "arms", "Moon Lantern", "lantern", "4f6190", "ffe5a0", "crane:rare", 0],
	["firefly_maracas", "arms", "Firefly Maracas", "maracas", "738d73", "e8d774", "crane:rare", 0],
	["heart_lollipop", "arms", "Heart Lollipop", "lollipop", "ef7c9a", "fff1cf", "crane:legendary", 0],
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
	["taster_specs", "glasses", "Taster's Specs", "browline", "6b3f1d", "e0b36a", "flavours", 12],
	["planner_glasses", "glasses", "Planner Glasses", "square", "4f8cc9", "4f8cc9", "missions", 25],
	["golden_specs", "glasses", "Golden Specs", "round", "f5c14e", "f5c14e", "level", 10],
	["star_shades", "glasses", "Star Shades", "shades", "6a4c9c", "ffe36e", "level", 35],
	["pixel_specs", "glasses", "Pixel Specs", "pixel", "384d73", "9ad2ea", "runs", 40],
	["honey_butterfly", "glasses", "Honey Butterfly", "butterfly", "dba656", "fff0b9", "total", 5000],
	["festival_visor", "glasses", "Festival Visor", "visor", "e48c83", "fff4df", "clean", 100],
	["plum_cat_eyes", "glasses", "Plum Cat Eyes", "cat_eye", "9c6b9c", "f4b4cb", "flavours", 20],
	["starlight_specs", "glasses", "Starlight Specs", "star", "e6be5d", "fff2ac", "missions", 90],
	["sea_glass_goggles", "glasses", "Sea Glass Goggles", "goggles", "8ac9c5", "e3f4e3", "days", 10],
	["cocoa_rounds", "glasses", "Cocoa Rounds", "round", "8e685a", "f4d6ac", "common", 0],
	["mint_pixel", "glasses", "Mint Pixel", "pixel", "62a995", "c7e9cc", "common", 1],
	["rose_butterfly", "glasses", "Rose Butterfly", "butterfly", "cf789f", "f6cee0", "common", 2],
	["amber_visor", "glasses", "Amber Visor", "visor", "cf9b56", "ffe6a8", "rare", 0],
	["lilac_lenses", "glasses", "Lilac Lenses", "shades", "775a99", "dcb9e7", "rare", 1],
	["sky_butterfly", "glasses", "Sky Butterfly", "butterfly", "77a9d7", "d4eaf4", "rare", 2],
	["sunrise_visor", "glasses", "Sunrise Visor", "visor", "e78570", "f3c97a", "epic", 1],
	["midnight_pixel", "glasses", "Midnight Pixel", "pixel", "333e65", "afb2de", "crane:rare", 0],
	["aurora_butterfly", "glasses", "Aurora Butterfly", "butterfly", "67b6b0", "d8b3dd", "crane:rare", 0],
	["golden_visor", "glasses", "Golden Visor", "visor", "d9b45e", "fff1b7", "crane:legendary", 0],
]

const DESCRIPTIONS := {
	"comfy_tee": "A soft lilac tee with a little pocket for treasures.",
	"sky_tee": "A breezy blue tee the colour of a clear afternoon.",
	"sailor_stripes": "Cream and navy stripes for a day by the water.",
	"cosy_scarf": "A warm red scarf finished with sunny yellow fringe.",
	"berry_bow_tie": "A berry pink bow for Kinu's fanciest occasions.",
	"cafe_apron": "A café apron with a roomy pocket for order slips.",
	"mint_hoodie": "A mint green hoodie with a snug hood and soft cuffs.",
	"denim_dungarees": "Blue dungarees with bright buttons and sturdy straps.",
	"festival_yukata": "A deep blue yukata tied with a vivid pink sash.",
	"ballet_tutu": "A fluffy pink tutu made for tiny curtain calls.",
	"swim_ring": "A candy pink swim ring ready for a pool day.",
	"club_jersey": "A green striped jersey for Kinu's biggest fans.",
	"work_overalls": "Sturdy golden overalls with pockets for a busy day.",
	"shoyu_bib": "A cream bib for the inevitable splash of shoyu.",
	"knit_sweater": "A cosy coral knit with a row of cream stitches.",
	"star_cape_scarf": "A midnight scarf with a flash of starlight gold.",
	"golden_sash": "A shining sash tied for a grand celebration.",
	"rainy_day_coat": "A bright yellow coat for puddles and grey skies.",
	"strawberry_cardigan": "A rosy cardigan with sweet cream trim.",
	"matcha_patchwork": "Soft green patches sewn together for one more adventure.",
	"midnight_haori": "A dark haori with a quiet lavender lining.",
	"cloud_pajamas": "Sky blue pajamas striped like a sleepy cloud.",
	"honey_waistcoat": "A warm honey waistcoat dressed up with cream trim.",
	"picnic_overalls": "Berry red overalls made for grass stained picnics.",
	"citrus_windbreaker": "An orange windbreaker with a zing of lemon yellow.",
	"lilac_quilt": "A lilac patchwork layer stitched for chilly mornings.",
	"tea_shop_vest": "A neat green vest for the busiest tea counter.",
	"aurora_raincoat": "A blue raincoat edged with a rosy evening glow.",
	"moonlit_cape": "A navy cape scarf trimmed with moonlight gold.",
	"festival_confetti": "A patchwork party outfit in confetti colours.",
	"little_beanie": "A little red beanie with a soft cream brim.",
	"sunny_cap": "A yellow cap for chasing the afternoon sun.",
	"painter_beret": "A jaunty red beret for Kinu's next masterpiece.",
	"party_hat": "A sky blue cone topped with a golden pompom.",
	"ribbon_bow": "A pink ribbon tied into a cheerful little bow.",
	"bucket_hat": "A leafy green bucket hat with a shady brim.",
	"top_hat": "A tall black hat with a smart red band.",
	"chef_hat": "A puffy white chef's hat ready for the kitchen.",
	"flower_crown": "A crown of fresh blossoms in spring colours.",
	"straw_hat": "A woven straw hat with a berry red ribbon.",
	"witch_hat": "A violet witch's hat with a glint of gold.",
	"royal_crown": "A golden crown set with bright little jewels.",
	"halo": "A warm golden halo floating just overhead.",
	"champion_cap": "A navy cap saved for a hard won victory.",
	"clover_cap": "A lucky clover sprouting from Kinu's head.",
	"sun_hat": "A cream sun hat with a cool blue band.",
	"bunny_band": "Two soft bunny ears ready for a little hop.",
	"cat_band": "Pointy black cat ears with pink inner fluff.",
	"propeller_cap": "A bright red cap with a playful spinning propeller.",
	"mushroom_cap": "A red mushroom cap dotted with white spots.",
	"rainbow_headphones": "Comfy headphones in every colour of the rainbow.",
	"fox_ears": "Warm orange fox ears tipped with cream.",
	"night_market_beret": "A twilight beret for wandering lantern lit stalls.",
	"peach_blossom_crown": "A little garland of peach blossoms and leaves.",
	"stargazer_cap": "A midnight cap for counting faraway stars.",
	"tofu_mushroom": "A creamy mushroom cap as soft as tofu.",
	"mint_headphones": "Mint green headphones for a mellow melody.",
	"sunset_bucket": "A coral bucket hat warmed by sunset colours.",
	"plum_mushroom": "A purple mushroom cap with a sweet plum glow.",
	"comet_headphones": "Dark blue headphones streaked with comet gold.",
	"little_arms": "Two tiny arms for waving at the world.",
	"cosy_mittens": "Pink mittens to keep little hands warm.",
	"cartoon_gloves": "Big cream gloves made for extra expressive waves.",
	"hello_wave": "One little arm always ready to say hello.",
	"red_balloon": "A bright red balloon bobbing above one hand.",
	"boxing_gloves": "Red padded gloves for a friendly sparring match.",
	"cheer_pompoms": "Golden pom-poms that shake with every cheer.",
	"little_wings": "Small cream wings with soft feathered tips.",
	"bubble_wand": "A purple wand for blowing rainbow bubbles.",
	"sparklers": "Tiny sparklers fizzing with golden light.",
	"steady_mitts": "Blue mitts with a sure and gentle grip.",
	"climber_gloves": "Tough tan gloves for reaching the next ledge.",
	"victory_flag": "A red flag to wave at the top of the pile.",
	"golden_wings": "Shimmering wings fit for a champion Kinu.",
	"paper_lantern": "A warm paper lantern for the walk home.",
	"peach_lollipop": "A peach sweet on a stick for a small treat.",
	"parade_maracas": "A pair of maracas for a noisy little parade.",
	"baker_mitts": "Flour coloured mitts fresh from the oven.",
	"rainbow_flags": "Two bright flags for a colourful procession.",
	"plum_wings": "Soft purple wings with a graceful sweep.",
	"mint_pompoms": "Mint green pom-poms for a fresh new cheer.",
	"sky_balloon": "A blue balloon floating like a pocket of sky.",
	"lemon_lollipop": "A sunny lemon sweet with a little tang.",
	"lucky_lantern": "A green lantern glowing with good fortune.",
	"cocoa_maracas": "Cocoa brown maracas with a gentle rattle.",
	"violet_boxing": "Violet boxing gloves with soft cream cuffs.",
	"sunburst_wings": "Orange wings lit up like a morning sunburst.",
	"moon_lantern": "A deep blue lantern with a warm moon glow.",
	"firefly_maracas": "Little green maracas speckled with firefly light.",
	"heart_lollipop": "A pink heart sweet to share with a friend.",
	"round_specs": "Simple round frames for a curious Kinu.",
	"red_frames": "Cheerful red frames with tidy square corners.",
	"star_glasses": "Golden star frames that steal the spotlight.",
	"heart_glasses": "Pink heart frames for seeing the lovely side.",
	"thick_frames": "Bold black frames with a bookish charm.",
	"cool_shades": "Dark shades for a very cool afternoon.",
	"monocle": "One golden lens for a distinguished look.",
	"swim_goggles": "Blue goggles ready for a big splash.",
	"three_d_glasses": "Red and blue lenses for a pop out picture.",
	"cat_eye_glasses": "Upswept violet frames with feline flair.",
	"taster_specs": "Round brown specs for the careful taste tester.",
	"planner_glasses": "Square blue frames for plotting the next move.",
	"golden_specs": "Polished gold frames with a soft shine.",
	"star_shades": "Purple shades scattered with little stars.",
	"pixel_specs": "Chunky navy frames straight from a pixel game.",
	"honey_butterfly": "Butterfly frames with a warm honey glow.",
	"festival_visor": "A bright visor for a day of festival lights.",
	"plum_cat_eyes": "Plum coloured cat eyes with a playful flick.",
	"starlight_specs": "Delicate frames that catch the starlight.",
	"sea_glass_goggles": "Pale sea glass goggles for clear blue water.",
	"cocoa_rounds": "Cocoa brown circles with cosy charm.",
	"mint_pixel": "Mint green pixel frames with crisp corners.",
	"rose_butterfly": "Rose pink butterfly frames ready to flutter.",
	"amber_visor": "An amber visor glowing like late sunshine.",
	"lilac_lenses": "Lilac tinted lenses for a dreamy view.",
	"sky_butterfly": "Blue butterfly frames light as a cloud.",
	"sunrise_visor": "A coral visor lit by the first sunrise.",
	"midnight_pixel": "Midnight blue pixel frames with a quiet gleam.",
	"aurora_butterfly": "Teal butterfly frames washed in aurora colour.",
	"golden_visor": "A golden visor with a brilliant finish.",
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
	part.description = DESCRIPTIONS.get(part.id, "")
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
