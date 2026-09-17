extends Node
## Plays real runs with real physics (the same "careful bot" aiming logic tests/integration.gd
## uses) to see how many Kinu actually fit in the box as currently sized/scaled, for a few skill
## levels. Unlike tools/economy_sim.gd (which guesses pile sizes to model the economy), this
## measures the box itself: how far real stacking physics lets each bot get before 3 tumbles.
##   Godot --headless --path . res://tools/capacity_sim.tscn
##
## `noise` is aiming error added every drop, as a fraction of the box half-width/full turn:
## 0 = lands exactly where the bot means to, 1 = might as well be random.
const SKILLS := {
	"perfect":  {"noise": 0.02, "runs": 6},
	"skilled":  {"noise": 0.18, "runs": 6},
	"shaky":    {"noise": 0.4,  "runs": 6},
}
const MAX_TURNS := 220
const SEED := 11

var app: Node
var run: NestRun

func _ready() -> void:
	Save.save_path = "user://capacity_sim.json"
	Save.data = Save.defaults()
	Save.data.debug_unlocked = true
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	run = app.run
	var report: PackedStringArray = []
	report.append("BOX  inner half %.3f  wall %.3f  rim height %.3f  |  KINU scale %.2f" % [TofuBox.INNER_HALF, TofuBox.WALL, TofuBox.RIM_HEIGHT, KinuBody.SCALE])
	report.append("")
	for name in SKILLS:
		report.append(await _play_skill(name, SKILLS[name]))
	var text := "\n".join(report)
	print(text)
	var file := FileAccess.open("res://docs/capacity-results.txt", FileAccess.WRITE)
	if file:
		file.store_string(text+"\n")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capacity_sim.json"))
	get_tree().quit()

func _play_skill(name: String, settings: Dictionary) -> String:
	var placed: Array[int] = []
	var heights: Array[float] = []
	var tumbled_out: Array[bool] = []
	for cycle in int(settings.runs):
		app._start()
		run.rng.seed = SEED+cycle
		var turn := 0
		while run.state == "aim" and turn < MAX_TURNS:
			run.orbit.target_angle = turn*2.39996
			await _frames(20)
			_noisy_aim(run, turn, float(settings.noise))
			run.drop()
			await _wait_for_turn()
			turn += 1
		placed.append(run.score)
		heights.append(run.tower_height)
		tumbled_out.append(run.state == "falling" or run.tumbles >= NestRun.MAX_TUMBLES)
		print("  %s run %d: placed=%d height=%s tumbles=%d turns=%d ended=%s" % [name, cycle+1, run.score, run.height_label(), run.tumbles, turn, "tumbled out" if tumbled_out.back() else "turn cap"])
	var avg := 0.0
	var best := 0
	var best_height := 0.0
	for i in placed.size():
		avg += placed[i]
		best = maxi(best, placed[i])
		best_height = maxf(best_height, heights[i])
	avg /= maxf(1, placed.size())
	var capped := tumbled_out.count(false)
	return "%-8s avg %5.1f Kinu  best %3d  best height %s  (%d/%d runs ended by tumbling, not the turn cap)" % [name.to_upper(), avg, best, run.height_label(best_height), tumbled_out.count(true), placed.size()]

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _wait_for_turn(limit: int = 400) -> void:
	for tick in limit:
		await get_tree().physics_frame
		if run.state != "settle":
			return

## Same idea as tests/integration.gd's smart_aim: line the new piece up over the tallest scored
## Kinu, then blur that choice by `noise` to model a less careful player.
func _noisy_aim(run: NestRun, turn: int, noise: float) -> void:
	var highest := Vector3(sin(turn*2.4), 0, cos(turn*2.4))*.6
	var top: KinuBody
	for body in run.bodies:
		if body.scored and not body.fallen and body.position.y > highest.y:
			highest = body.position
			top = body
	if top:
		var forward := top.global_basis.z
		var wanted := atan2(forward.x, forward.z)-run.active_yaw
		wanted += round((run.orbit.angle-wanted)/(PI*.5))*PI*.5
		wanted += run.rng.randf_range(-noise, noise)*PI*.5
		run.orbit.stop_spin()
		run.orbit.angle = wanted
		run.orbit.target_angle = wanted
	var target := highest*Vector3(.5, 0, .5)
	target += Vector3(run.rng.randf_range(-noise, noise), 0, run.rng.randf_range(-noise, noise))*TofuBox.INNER_HALF*.5
	run.orbit.lateral = target.dot(run.orbit.right())
	run.orbit.depth = target.dot(run.orbit.toward_camera())
