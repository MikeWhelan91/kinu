extends Node
var selected := -1
func _ready() -> void:
	var front := ShopFront.new()
	add_child(front)
	front.set_process(false)
	for i in 4:
		NestMenuScreen._curtain_button(front,str(i),["shop","wardrobe","book","settings"][i],func() -> void: selected = i,i)
	await get_tree().process_frame
	var checks := 0
	for time in [0.0,1.5,3.0]:
		front._frame_time = time
		front._layout_navigation()
		for i in 4:
			var polygon := front._panel_polygon(front._panel_pose(i,time))
			for uv in [Vector2(.1,.15),Vector2(.9,.15),Vector2(.5,.5),Vector2(.1,.95),Vector2(.9,.95)]:
				var left := polygon[0].lerp(polygon[3],uv.y)
				var right := polygon[1].lerp(polygon[2],uv.y)
				var point := left.lerp(right,uv.x)
				selected = -1
				for pressed in [true,false]:
					var event := InputEventMouseButton.new()
					event.position = point
					event.button_index = MOUSE_BUTTON_LEFT
					event.pressed = pressed
					get_viewport().push_input(event,true)
				assert(selected == i,"Whole curtain must open its own page")
				checks += 1
	print("CURTAIN TAP CHECKS=",checks," FAILURES=0")
	get_tree().quit()
