extends Node3D

const LANES: Array[float] = [-2.0, 0.0, 2.0]
const PHRASE := "GALOPPO"
const TRACK_WIDTH := 9.0
const CHUNK_LENGTH := 28.0
const RENDER_AHEAD := 220.0
const CLEANUP_BEHIND := 45.0
const SAFE_DISTANCE := 80.0

enum Skill {
	NONE,
	FIRE,
	FLY,
}

var characters: Array = [
	{"name": "Ranger", "shirt": Color(0.28, 0.50, 0.86)},
	{"name": "Dust", "shirt": Color(0.45, 0.61, 0.26)},
	{"name": "Storm", "shirt": Color(0.55, 0.34, 0.70)},
]

var selected_character := 0

var running := false
var dead := false
var distance := 0.0
var coins := 0
var lives := 3
var max_lives := 5
var player_z := 0.0

var base_speed := 10.0
var speed := 10.0

var lane_index := 1
var lane_from := 1
var lane_to := 1
var lane_t := 1.0
var lane_duration := 0.22

var phrase_index := 0
var next_chunk_z := 0.0
var next_letter_distance := 20.0
var next_fire_distance := 130.0
var next_fly_distance := 170.0

var current_skill: Skill = Skill.NONE
var fire_timer := 0.0
var fly_timer := 0.0
var hit_invuln := 0.0
var camera_shake := 0.0

var on_foot := false
var need_horse_pickup := false

var best_score := 0

var camera: Camera3D
var runner_root: Node3D
var horse_root: Node3D
var cowboy_root: Node3D
var fx_root: Node3D
var track_root: Node3D
var obstacle_root: Node3D
var collectible_root: Node3D
var env_root: Node3D

var chunks: Array = []
var obstacles: Array = []
var collectibles: Array = []
var side_decor: Array = []

var ui_layer: CanvasLayer
var hud: HBoxContainer
var distance_value: Label
var coins_value: Label
var lives_value: Label
var skill_value: Label
var phrase_label: Label
var tip_label: Label
var select_panel: PanelContainer
var gameover_panel: PanelContainer
var score_label: Label
var best_label: Label
var moon: MeshInstance3D

func _ready() -> void:
	best_score = 0
	if FileAccess.file_exists("user://save.dat"):
		var f := FileAccess.open("user://save.dat", FileAccess.READ)
		if f:
			best_score = f.get_32()
	_build_world()
	_build_player()
	_build_ui()
	_update_character_style()
	_show_select(true)
	_show_gameover(false)
	set_process(true)

func _build_world() -> void:
	env_root = Node3D.new()
	add_child(env_root)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.09, 0.13)
	env.fog_enabled = true
	env.fog_light_color = Color(0.25, 0.34, 0.34)
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.05
	world_env.environment = env
	env_root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.2
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.shadow_enabled = true
	env_root.add_child(sun)

	var hemi := DirectionalLight3D.new()
	hemi.light_energy = 0.35
	hemi.light_color = Color(0.57, 0.73, 0.89)
	hemi.rotation_degrees = Vector3(-20, -120, 0)
	env_root.add_child(hemi)

	var rim := OmniLight3D.new()
	rim.light_energy = 0.28
	rim.omni_range = 26.0
	rim.light_color = Color(0.64, 0.8, 1.0)
	rim.position = Vector3(-8, 6, -22)
	env_root.add_child(rim)

	moon = MeshInstance3D.new()
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 1.7
	moon.mesh = moon_mesh
	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_color = Color(0.82, 0.89, 0.95)
	moon_mat.emission_enabled = true
	moon_mat.emission = Color(0.42, 0.53, 0.65)
	moon_mat.emission_energy_multiplier = 1.2
	moon.material_override = moon_mat
	moon.position = Vector3(-26, 24, -120)
	env_root.add_child(moon)

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 58
	camera.position = Vector3(0, 5.6, 9.2)
	add_child(camera)

	track_root = Node3D.new()
	add_child(track_root)
	obstacle_root = Node3D.new()
	add_child(obstacle_root)
	collectible_root = Node3D.new()
	add_child(collectible_root)
	fx_root = Node3D.new()
	add_child(fx_root)

func _build_player() -> void:
	runner_root = Node3D.new()
	add_child(runner_root)

	horse_root = Node3D.new()
	runner_root.add_child(horse_root)
	cowboy_root = Node3D.new()
	runner_root.add_child(cowboy_root)

	_build_horse_mesh()
	_build_cowboy_mesh()
	_mount_pose()

func _build_horse_mesh() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.48, 0.33, 0.24)
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.18, 0.13, 0.1)

	var body := _box_mesh(Vector3(1.35, 0.52, 0.52), body_mat)
	body.position = Vector3(0, 0.8, 0)
	horse_root.add_child(body)

	var neck := _box_mesh(Vector3(0.22, 0.44, 0.24), body_mat)
	neck.position = Vector3(0.53, 1.04, 0)
	neck.rotation.z = -0.38
	horse_root.add_child(neck)

	var head := _box_mesh(Vector3(0.36, 0.24, 0.22), body_mat)
	head.position = Vector3(0.72, 1.14, 0)
	horse_root.add_child(head)

	var mane := _box_mesh(Vector3(0.12, 0.28, 0.24), dark_mat)
	mane.position = Vector3(0.52, 1.18, 0)
	mane.rotation.z = -0.38
	horse_root.add_child(mane)

	var tail := _box_mesh(Vector3(0.12, 0.34, 0.12), dark_mat)
	tail.name = "Tail"
	tail.position = Vector3(-0.66, 0.92, 0)
	tail.rotation.z = 0.5
	horse_root.add_child(tail)

	for i in 4:
		var leg := _box_mesh(Vector3(0.12, 0.52, 0.12), body_mat)
		leg.name = "Leg%d" % i
		var x := 0.36 if i > 1 else -0.36
		var z := 0.17 if i % 2 == 1 else -0.17
		leg.position = Vector3(x, 0.34, z)
		horse_root.add_child(leg)

func _build_cowboy_mesh() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.83, 0.64, 0.48)
	var shirt := StandardMaterial3D.new()
	shirt.albedo_color = Color(0.28, 0.5, 0.86)
	shirt.resource_name = "shirt"
	var pant := StandardMaterial3D.new()
	pant.albedo_color = Color(0.19, 0.24, 0.36)
	var hat := StandardMaterial3D.new()
	hat.albedo_color = Color(0.2, 0.13, 0.09)

	var torso := _box_mesh(Vector3(0.36, 0.46, 0.24), shirt)
	torso.position = Vector3(0, 1.28, 0)
	cowboy_root.add_child(torso)

	var head := _box_mesh(Vector3(0.24, 0.24, 0.24), skin)
	head.position = Vector3(0, 1.64, 0)
	cowboy_root.add_child(head)

	var hat_top := MeshInstance3D.new()
	hat_top.mesh = CylinderMesh.new()
	(hat_top.mesh as CylinderMesh).top_radius = 0.11
	(hat_top.mesh as CylinderMesh).bottom_radius = 0.13
	(hat_top.mesh as CylinderMesh).height = 0.15
	hat_top.material_override = hat
	hat_top.position = Vector3(0, 1.83, 0)
	cowboy_root.add_child(hat_top)

	for i in 2:
		var leg := _box_mesh(Vector3(0.1, 0.42, 0.1), pant)
		leg.name = "CowLeg%d" % i
		leg.position = Vector3(-0.11 if i == 0 else 0.11, 0.94, 0)
		cowboy_root.add_child(leg)

	for i in 2:
		var arm := _box_mesh(Vector3(0.09, 0.32, 0.09), shirt)
		arm.name = "CowArm%d" % i
		arm.position = Vector3(-0.24 if i == 0 else 0.24, 1.27, 0.03)
		cowboy_root.add_child(arm)

func _update_character_style() -> void:
	for c in cowboy_root.get_children():
		if c is MeshInstance3D and c.material_override is StandardMaterial3D:
			var m := c.material_override as StandardMaterial3D
			if m.resource_name == "shirt":
				m.albedo_color = characters[selected_character]["shirt"]

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root)

	hud = HBoxContainer.new()
	hud.anchor_left = 0.5
	hud.anchor_right = 0.5
	hud.offset_left = -320
	hud.offset_right = 320
	hud.offset_top = 14
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 8)
	root.add_child(hud)

	distance_value = _hud_item(hud, "Distanza", "0")
	coins_value = _hud_item(hud, "Monete", "0")
	lives_value = _hud_item(hud, "Vite", "3")
	skill_value = _hud_item(hud, "Skill", "-")

	phrase_label = Label.new()
	phrase_label.anchor_left = 0.5
	phrase_label.anchor_right = 0.5
	phrase_label.offset_left = -220
	phrase_label.offset_right = 220
	phrase_label.offset_top = 70
	phrase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phrase_label.text = "Frase: _ _ _ _ _ _ _"
	root.add_child(phrase_label)

	tip_label = Label.new()
	tip_label.anchor_left = 0.5
	tip_label.anchor_right = 0.5
	tip_label.offset_left = -320
	tip_label.offset_right = 320
	tip_label.anchor_bottom = 1.0
	tip_label.anchor_top = 1.0
	tip_label.offset_bottom = -18
	tip_label.offset_top = -46
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.text = "Tap sinistra/destra. Completa la frase per +vite"
	root.add_child(tip_label)

	select_panel = PanelContainer.new()
	select_panel.anchor_left = 0.5
	select_panel.anchor_top = 0.5
	select_panel.anchor_right = 0.5
	select_panel.anchor_bottom = 0.5
	select_panel.offset_left = -230
	select_panel.offset_right = 230
	select_panel.offset_top = -170
	select_panel.offset_bottom = 170
	root.add_child(select_panel)

	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_theme_constant_override("separation", 8)
	select_panel.add_child(sv)
	var st := Label.new()
	st.text = "Cowboy Rush"
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(st)
	var sb := Label.new()
	sb.text = "Scegli personaggio"
	sb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(sb)

	var chars := HBoxContainer.new()
	chars.alignment = BoxContainer.ALIGNMENT_CENTER
	chars.add_theme_constant_override("separation", 8)
	sv.add_child(chars)

	for i in characters.size():
		var b := Button.new()
		b.text = str(characters[i]["name"])
		b.pressed.connect(_on_character_selected.bind(i))
		chars.add_child(b)

	var start_btn := Button.new()
	start_btn.text = "Inizia Corsa"
	start_btn.pressed.connect(_start_run)
	sv.add_child(start_btn)

	gameover_panel = PanelContainer.new()
	gameover_panel.anchor_left = 0.5
	gameover_panel.anchor_top = 0.5
	gameover_panel.anchor_right = 0.5
	gameover_panel.anchor_bottom = 0.5
	gameover_panel.offset_left = -220
	gameover_panel.offset_right = 220
	gameover_panel.offset_top = -140
	gameover_panel.offset_bottom = 140
	root.add_child(gameover_panel)

	var gv := VBoxContainer.new()
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	gv.add_theme_constant_override("separation", 8)
	gameover_panel.add_child(gv)
	var gt := Label.new()
	gt.text = "Game Over"
	gt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(gt)
	score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(score_label)
	best_label = Label.new()
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(best_label)
	var restart_btn := Button.new()
	restart_btn.text = "Ricomincia"
	restart_btn.pressed.connect(_start_run)
	gv.add_child(restart_btn)

func _hud_item(parent: Node, title: String, val: String) -> Label:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(90, 38)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var v := Label.new()
	v.text = val
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(v)
	parent.add_child(box)
	return v

func _show_select(show: bool) -> void:
	select_panel.visible = show
	hud.visible = not show
	phrase_label.visible = not show
	if show:
		tip_label.text = "Scegli cowboy e premi Inizia"

func _show_gameover(show: bool) -> void:
	gameover_panel.visible = show

func _start_run() -> void:
	_clear_world()
	running = true
	dead = false
	distance = 0.0
	coins = 0
	lives = 3
	player_z = 0.0
	base_speed = 10.0
	speed = 10.0
	lane_index = 1
	lane_from = 1
	lane_to = 1
	lane_t = 1.0
	next_chunk_z = 0.0
	next_letter_distance = 22.0
	next_fire_distance = 130.0
	next_fly_distance = 170.0
	phrase_index = 0
	current_skill = Skill.NONE
	fire_timer = 0.0
	fly_timer = 0.0
	hit_invuln = 0.0
	camera_shake = 0.0
	on_foot = false
	need_horse_pickup = false

	runner_root.position = Vector3.ZERO
	runner_root.rotation = Vector3.ZERO
	_mount_pose()
	_update_character_style()

	distance_value.text = "0"
	coins_value.text = "0"
	lives_value.text = "3"
	skill_value.text = "-"
	phrase_label.text = _phrase_text()
	tip_label.text = "Tap sinistra/destra. Completa la frase per +vite"

	_show_select(false)
	_show_gameover(false)

func _clear_world() -> void:
	for c in chunks:
		if c.has("node"):
			(c["node"] as Node3D).queue_free()
	chunks.clear()
	for arr in [obstacles, collectibles, side_decor]:
		for n in arr:
			(n as Node3D).queue_free()
		arr.clear()

func _process(delta: float) -> void:
	if running:
		_tick_run(delta)
	_update_animation(delta)
	_update_camera(delta)

func _tick_run(delta: float) -> void:
	base_speed = min(24.0, base_speed + delta * 0.22)
	if fire_timer > 0.0:
		fire_timer = max(0.0, fire_timer - delta)
	if fly_timer > 0.0:
		fly_timer = max(0.0, fly_timer - delta)
	if hit_invuln > 0.0:
		hit_invuln = max(0.0, hit_invuln - delta)
	if camera_shake > 0.0:
		camera_shake = max(0.0, camera_shake - delta * 1.8)
	if fire_timer <= 0.0 and current_skill == Skill.FIRE:
		current_skill = Skill.NONE
	if fly_timer <= 0.0 and current_skill == Skill.FLY:
		current_skill = Skill.NONE

	var skill_boost := 0.0
	if current_skill == Skill.FIRE:
		skill_boost = 6.0
	elif current_skill == Skill.FLY:
		skill_boost = 4.0
	var foot_penalty := -2.2 if on_foot else 0.0
	speed = base_speed + skill_boost + foot_penalty

	player_z -= speed * delta
	distance += speed * delta
	_move_lane(delta)
	runner_root.position.z = player_z

	_ensure_track()
	_cleanup_world()
	_rotate_pickups(delta)
	_check_collisions()
	_update_ui()

func _move_lane(delta: float) -> void:
	if lane_to == lane_from:
		lane_t = 1.0
	else:
		lane_t = min(1.0, lane_t + delta / lane_duration)
	var eased := 1.0 - pow(1.0 - lane_t, 3.0)
	runner_root.position.x = lerp(LANES[lane_from], LANES[lane_to], eased)
	if lane_t >= 1.0:
		lane_index = lane_to
		lane_from = lane_to

func _ensure_track() -> void:
	while next_chunk_z > player_z - RENDER_AHEAD:
		_spawn_chunk(next_chunk_z)
		_spawn_pattern(next_chunk_z)
		next_chunk_z -= CHUNK_LENGTH

func _spawn_chunk(z_start: float) -> void:
	var g := Node3D.new()
	track_root.add_child(g)
	chunks.append({"z": z_start, "node": g})

	var road := _box_mesh(Vector3(TRACK_WIDTH, 0.22, CHUNK_LENGTH), pathMat())
	road.position = Vector3(0, -0.12, z_start - CHUNK_LENGTH * 0.5)
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(road)

	for i in 10:
		var marker_l := _box_mesh(Vector3(0.11, 0.02, 2.2), grooveMat())
		marker_l.position = Vector3(-0.95, -0.01, z_start - 1.4 - i * 2.8)
		marker_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(marker_l)
		var marker_r := _box_mesh(Vector3(0.11, 0.02, 2.2), grooveMat())
		marker_r.position = Vector3(0.95, -0.01, z_start - 1.4 - i * 2.8)
		marker_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(marker_r)

	var shoulder_l := _box_mesh(Vector3(8.0, 0.12, CHUNK_LENGTH), shoulderMat())
	shoulder_l.position = Vector3(-(TRACK_WIDTH * 0.5 + 4.0), -0.17, z_start - CHUNK_LENGTH * 0.5)
	g.add_child(shoulder_l)
	var shoulder_r := shoulder_l.duplicate()
	(shoulder_r as MeshInstance3D).position.x = TRACK_WIDTH * 0.5 + 4.0
	g.add_child(shoulder_r)

	for i in 10:
		var z := z_start - randf() * CHUNK_LENGTH
		_create_tree(-(TRACK_WIDTH * 0.5 + 2.4 + randf() * 4.8), z)
		_create_tree(TRACK_WIDTH * 0.5 + 2.4 + randf() * 4.8, z)

func _create_tree(x: float, z: float) -> void:
	var tree := Node3D.new()
	obstacle_root.add_child(tree)
	collectibles.append(tree)
	var h := 1.2 + randf() * 2.0
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.13
	cyl.height = h
	trunk.mesh = cyl
	trunk.material_override = trunkMat()
	trunk.position = Vector3(0, h * 0.5, 0)
	tree.add_child(trunk)
	var cone := MeshInstance3D.new()
	var cm := ConeMesh.new()
	cm.bottom_radius = 0.55
	cm.height = 1.2
	cone.mesh = cm
	cone.material_override = leavesMat()
	cone.position = Vector3(0, h + 0.45, 0)
	tree.add_child(cone)
	tree.position = Vector3(x, 0, z)
	side_decor.append(tree)

func _spawn_pattern(chunk_start: float) -> void:
	var pressure := min(1.0, distance / 980.0)
	if chunk_start > -30.0:
		_spawn_coin(LANES[1], chunk_start - 12.0)
		return

	if distance < SAFE_DISTANCE:
		if randf() < 0.85:
			_spawn_coin(LANES[randi_range(0, 2)], chunk_start - 11.0)
		if distance > 28.0 and distance > next_letter_distance:
			_spawn_letter(PHRASE[phrase_index], LANES[randi_range(0, 2)], chunk_start - 12.0)
			next_letter_distance = distance + 20.0
		return

	var obstacle_count := 1 + int(randf() * (1.0 + pressure * 2.2))
	for i in obstacle_count:
		var z := chunk_start - 5.0 - float(i) * (5.8 - pressure * 1.8) - randf() * 1.8
		var lane := randi_range(0, 2)
		_spawn_obstacle(LANES[lane], z, pressure)
		if randf() < 0.82:
			_spawn_coin(LANES[randi_range(0, 2)], z - 2.2 - randf() * 1.5)

	if distance > next_letter_distance:
		_spawn_letter(PHRASE[phrase_index], LANES[randi_range(0, 2)], chunk_start - 12.0 - randf() * 5.0)
		next_letter_distance = distance + 25.0 + randf() * 18.0

	if not on_foot and fire_timer <= 0.0 and fly_timer <= 0.0 and distance > next_fire_distance and randf() < 0.05 + pressure * 0.04:
		_spawn_skill("fire", LANES[randi_range(0, 2)], chunk_start - 14.0 - randf() * 5.0)
		next_fire_distance = distance + 260.0 + randf() * 160.0

	if not on_foot and fire_timer <= 0.0 and fly_timer <= 0.0 and distance > next_fly_distance and randf() < 0.04 + pressure * 0.04:
		_spawn_skill("fly", LANES[randi_range(0, 2)], chunk_start - 15.0 - randf() * 5.0)
		next_fly_distance = distance + 300.0 + randf() * 170.0

	if need_horse_pickup and randf() < 0.45 and not _has_horse_token():
		_spawn_horse_token(LANES[randi_range(0, 2)], chunk_start - 14.0)

func _spawn_obstacle(x: float, z: float, pressure: float) -> void:
	var obj := Node3D.new()
	obj.position = Vector3(x, 0, z)
	obj.set_meta("type", "obstacle")
	var radius := 0.85
	if randf() < 0.55:
		var rock := MeshInstance3D.new()
		rock.mesh = SphereMesh.new()
		(rock.mesh as SphereMesh).radius = 0.55 + randf() * 0.2
		rock.material_override = rockMat()
		rock.position.y = 0.54
		obj.add_child(rock)
		radius = 0.8
	else:
		var log := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.24
		cm.bottom_radius = 0.29
		cm.height = 1.4 + pressure * 0.7
		log.mesh = cm
		log.material_override = logMat()
		log.rotation_degrees.z = 90
		log.position.y = 0.3
		obj.add_child(log)
		radius = 0.9
	obj.set_meta("radius", radius)
	obstacle_root.add_child(obj)
	obstacles.append(obj)

func _spawn_coin(x: float, z: float) -> void:
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.09
	tm.outer_radius = 0.27
	m.mesh = tm
	m.material_override = coinMat()
	m.position = Vector3(x, 0.95, z)
	m.set_meta("type", "coin")
	collectible_root.add_child(m)
	collectibles.append(m)

func _spawn_skill(kind: String, x: float, z: float) -> void:
	var n := Node3D.new()
	n.position = Vector3(x, 1.05, z)
	n.set_meta("type", kind)
	var core := MeshInstance3D.new()
	core.mesh = SphereMesh.new()
	(core.mesh as SphereMesh).radius = 0.25
	var mat := StandardMaterial3D.new()
	if kind == "fire":
		mat.albedo_color = Color(1.0, 0.58, 0.22)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.1)
	else:
		mat.albedo_color = Color(0.74, 0.92, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.8, 1.0)
	core.material_override = mat
	n.add_child(core)
	collectible_root.add_child(n)
	collectibles.append(n)

func _spawn_letter(letter: String, x: float, z: float) -> void:
	var label3d := Label3D.new()
	label3d.text = letter
	label3d.font_size = 72
	label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label3d.modulate = Color(0.96, 0.93, 0.62)
	label3d.position = Vector3(x, 1.2, z)
	label3d.set_meta("type", "letter")
	label3d.set_meta("letter", letter)
	collectible_root.add_child(label3d)
	collectibles.append(label3d)

func _spawn_horse_token(x: float, z: float) -> void:
	var m := MeshInstance3D.new()
	m.mesh = TorusMesh.new()
	(m.mesh as TorusMesh).inner_radius = 0.05
	(m.mesh as TorusMesh).outer_radius = 0.42
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.56, 0.82, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.28, 0.57, 0.78)
	m.material_override = mat
	m.position = Vector3(x, 1.0, z)
	m.set_meta("type", "horse")
	collectible_root.add_child(m)
	collectibles.append(m)

func _has_horse_token() -> bool:
	for c in collectibles:
		if c.has_meta("type") and c.get_meta("type") == "horse":
			return true
	return false

func _cleanup_world() -> void:
	for i in range(chunks.size() - 1, -1, -1):
		var z0: float = chunks[i]["z"]
		if z0 > player_z + CLEANUP_BEHIND:
			(chunks[i]["node"] as Node3D).queue_free()
			chunks.remove_at(i)

	for arr in [obstacles, collectibles]:
		for i in range(arr.size() - 1, -1, -1):
			var n := arr[i] as Node3D
			if n.position.z > player_z + CLEANUP_BEHIND:
				n.queue_free()
				arr.remove_at(i)

	for i in range(side_decor.size() - 1, -1, -1):
		var d := side_decor[i] as Node3D
		if d.position.z > player_z + CLEANUP_BEHIND:
			d.queue_free()
			side_decor.remove_at(i)

func _rotate_pickups(delta: float) -> void:
	for c in collectibles:
		if c.has_meta("type"):
			var t := str(c.get_meta("type"))
			if t == "coin" or t == "fire" or t == "fly" or t == "horse":
				(c as Node3D).rotate_y(delta * 2.6)
				(c as Node3D).position.y += sin(Time.get_ticks_msec() * 0.004 + c.position.z) * 0.0009

func _check_collisions() -> void:
	for i in range(obstacles.size() - 1, -1, -1):
		var o := obstacles[i] as Node3D
		var dz := abs(o.position.z - player_z)
		var dx := abs(o.position.x - runner_root.position.x)
		if dz < 0.95 and dx < float(o.get_meta("radius", 0.85)):
			if current_skill == Skill.FIRE:
				_spawn_fx(o.position, Color(1.0, 0.55, 0.24))
				o.queue_free()
				obstacles.remove_at(i)
			elif current_skill != Skill.FLY and hit_invuln <= 0.0:
				o.queue_free()
				obstacles.remove_at(i)
				_lose_life()
				break

	for i in range(collectibles.size() - 1, -1, -1):
		var c := collectibles[i] as Node3D
		var dz := abs(c.position.z - player_z)
		var dx := abs(c.position.x - runner_root.position.x)
		if dz < 0.95 and dx < 0.72:
			var t := str(c.get_meta("type", ""))
			if t == "coin":
				coins += 1
				_spawn_fx(c.position, Color(0.57, 0.9, 1.0))
			elif t == "fire":
				_activate_skill(Skill.FIRE)
			elif t == "fly":
				_activate_skill(Skill.FLY)
			elif t == "letter":
				var expected := PHRASE[phrase_index]
				if str(c.get_meta("letter", "")) == expected:
					phrase_index += 1
					if phrase_index >= PHRASE.length():
						phrase_index = 0
						if lives < max_lives:
							lives += 1
						if on_foot and lives >= 2:
							need_horse_pickup = true
			elif t == "horse":
				if on_foot and lives >= 2:
					on_foot = false
					need_horse_pickup = false
					_mount_pose()
					tip_label.text = "Hai trovato un cavallo. Torni in sella!"
			c.queue_free()
			collectibles.remove_at(i)

func _lose_life() -> void:
	lives -= 1
	if lives <= 0:
		_end_run()
		return
	if lives == 1 and not on_foot:
		on_foot = true
		need_horse_pickup = true
		fire_timer = 0.0
		fly_timer = 0.0
		current_skill = Skill.NONE
		_foot_pose()
		tip_label.text = "Ultima vita: il cavallo cade. Corri a piedi!"
	hit_invuln = 1.1
	camera_shake = 0.28

func _end_run() -> void:
	running = false
	dead = true
	var score := int(distance + float(coins) * 12.0)
	if score > best_score:
		best_score = score
		var f := FileAccess.open("user://save.dat", FileAccess.WRITE)
		if f:
			f.store_32(best_score)
	score_label.text = "Punteggio: %d" % score
	best_label.text = "Record: %d" % best_score
	_show_gameover(true)

func _update_ui() -> void:
	distance_value.text = str(int(distance))
	coins_value.text = str(coins)
	lives_value.text = str(lives)
	phrase_label.text = _phrase_text()
	if current_skill == Skill.FIRE:
		skill_value.text = "Fuoco %ds" % int(ceil(fire_timer))
	elif current_skill == Skill.FLY:
		skill_value.text = "Unicorno %ds" % int(ceil(fly_timer))
	else:
		skill_value.text = "-"

func _phrase_text() -> String:
	var done := PHRASE.substr(0, phrase_index)
	var missing := ""
	for i in range(phrase_index, PHRASE.length()):
		missing += "_"
	return "Frase: %s%s" % [done, missing]

func _update_animation(delta: float) -> void:
	if not running:
		return
	var t := Time.get_ticks_msec() * 0.001
	if on_foot:
		var s := sin(t * 12.5) * 0.52
		(_find_node("CowLeg0") as Node3D).rotation.x = s
		(_find_node("CowLeg1") as Node3D).rotation.x = -s
		(_find_node("CowArm0") as Node3D).rotation.x = -s * 0.7
		(_find_node("CowArm1") as Node3D).rotation.x = s * 0.7
	else:
		var run := sin(t * 15.5) * 0.55
		for i in 4:
			var leg := _find_node("Leg%d" % i) as Node3D
			if i == 0 or i == 3:
				leg.rotation.x = run
			else:
				leg.rotation.x = -run
		(_find_node("Tail") as Node3D).rotation.x = sin(t * 11.0) * 0.18
		(_find_node("CowLeg0") as Node3D).rotation.x = -0.2
		(_find_node("CowLeg1") as Node3D).rotation.x = -0.2

	runner_root.rotation.z = lerp(runner_root.rotation.z, -float(lane_to - 1) * 0.2, 0.1)
	var ride_bob := 0.02 if on_foot else 0.04
	runner_root.position.y += sin(t * 11.0) * ride_bob * delta * 8.0

func _update_camera(delta: float) -> void:
	var target_y := 1.0
	if current_skill == Skill.FLY:
		target_y = 3.0
	elif on_foot:
		target_y = 0.9
	runner_root.position.y = lerp(runner_root.position.y, target_y, 0.11)

	var cam_y := 5.7
	var cam_z := 9.4
	if current_skill == Skill.FLY:
		cam_y = 8.0
		cam_z = 12.2
	elif on_foot:
		cam_y = 5.0
	var target := Vector3(runner_root.position.x * 0.62, cam_y, player_z + cam_z)
	if camera_shake > 0.0:
		target += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * (0.18 * camera_shake)
	camera.position = camera.position.lerp(target, 1.0 - exp(-delta * 7.0))
	camera.look_at(Vector3(runner_root.position.x * 0.42, runner_root.position.y + 1.0, player_z - 12.0), Vector3.UP)
	moon.position.z = player_z - 120.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		_set_lane(lane_to - 1)
	elif event.is_action_pressed("move_right"):
		_set_lane(lane_to + 1)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and running:
		var mb := event as InputEventMouseButton
		if mb.position.x < get_viewport().size.x * 0.5:
			_set_lane(lane_to - 1)
		else:
			_set_lane(lane_to + 1)
	elif event is InputEventScreenTouch and event.pressed and running:
		var st := event as InputEventScreenTouch
		if st.position.x < get_viewport().size.x * 0.5:
			_set_lane(lane_to - 1)
		else:
			_set_lane(lane_to + 1)
	elif event.is_action_pressed("restart") and dead:
		_start_run()

func _set_lane(target: int) -> void:
	if not running or dead:
		return
	target = clamp(target, 0, 2)
	if target == lane_to:
		return
	lane_from = lane_index
	lane_to = target
	lane_t = 0.0
	tip_label.text = ""

func _activate_skill(skill: Skill) -> void:
	current_skill = skill
	if skill == Skill.FIRE:
		fire_timer = 10.0
		fly_timer = 0.0
		tip_label.text = "Cavallo di fuoco!"
		next_fire_distance = distance + 300.0
		next_fly_distance = max(next_fly_distance, distance + 180.0)
		_spawn_fx(runner_root.position + Vector3(0, 1.0, 0), Color(1.0, 0.55, 0.24))
	elif skill == Skill.FLY:
		fly_timer = 10.0
		fire_timer = 0.0
		tip_label.text = "Unicorno volante!"
		next_fly_distance = distance + 320.0
		next_fire_distance = max(next_fire_distance, distance + 190.0)
		_spawn_fx(runner_root.position + Vector3(0, 1.0, 0), Color(0.62, 0.86, 1.0))

func _mount_pose() -> void:
	horse_root.visible = true
	cowboy_root.position = Vector3(0.02, 0.56, 0)

func _foot_pose() -> void:
	horse_root.visible = false
	cowboy_root.position = Vector3(0, 0, 0)

func _spawn_fx(pos: Vector3, color: Color) -> void:
	var gp := GPUParticles3D.new()
	gp.amount = 24
	gp.one_shot = true
	gp.explosiveness = 1.0
	gp.lifetime = 0.42
	gp.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180
	pm.initial_velocity_min = 1.7
	pm.initial_velocity_max = 4.2
	pm.gravity = Vector3(0, -7, 0)
	pm.color = color
	gp.process_material = pm
	fx_root.add_child(gp)
	gp.emitting = true
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(gp):
		gp.queue_free()

func _box_mesh(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi

func _find_node(name: String) -> Node:
	var n := horse_root.get_node_or_null(name)
	if n:
		return n
	return cowboy_root.get_node_or_null(name)

func _on_character_selected(idx: int) -> void:
	selected_character = idx
	_update_character_style()

func pathMat() -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.26, 0.16)
	m.roughness = 0.95
	return m

func shoulderMat() -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.17, 0.24, 0.17)
	m.roughness = 0.95
	return m

func grooveMat() -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.34, 0.28, 0.2)
	m.roughness = 0.85
	return m

func trunkMat() -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.23, 0.15, 0.11)
	return m

func leavesMat() -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.19, 0.35, 0.23)
	return m

func rockMat() -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.43, 0.43, 0.4)
	m.roughness = 0.9
	return m

func logMat() -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.29, 0.2)
	m.roughness = 0.86
	return m

func coinMat() -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.58, 0.93, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.33, 0.64, 0.98)
	m.emission_energy_multiplier = 1.3
	m.roughness = 0.2
	m.metallic = 0.7
	return m
