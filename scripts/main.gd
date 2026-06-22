extends Node2D

const GROUND_Y     = 560.0
const WORLD_WIDTH  = 200_000.0

var player: CharacterBody2D
var anim_sprite: AnimatedSprite2D
var camera: Camera2D
var info_label: Label
var scale_idle: Vector2
var scale_run: Vector2

# 패럴렉스용 노드 레퍼런스
var bg_far_node: Node2D    # 원거리 (구름) — 느리게 이동
var bg_mid_node: Node2D    # 중거리 (나무/언덕) — 중간 속도
var _prev_cam_x: float = 0.0  # 이전 프레임 카메라 실제 X
var _cam_tween: Tween         # 카메라 offset 부드럽게 전환

# ── 물리 상수 (에디터에서 바꾸고 싶으면 @export 추가) ──
const GRAVITY       = 1400.0
const SPEED         = 340.0
const SPRINT_SPEED  = 600.0
const JUMP_VELOCITY = -680.0
const RUN_FRAMES    = 7      # run.png 프레임 수
const IDLE_FRAMES   = 13     # idle.png 프레임 수
const ANIM_FPS      = 12.0   # 재생 속도 (높을수록 빠름)

func _ready() -> void:
	_build_background()
	_build_ground()
	_build_player()
	_build_ui()
	_prev_cam_x = player.position.x  # 첫 프레임 점프 방지

func _process(_delta: float) -> void:
	if not player or not camera: return
	# 카메라 실제 화면 중심 X 기준 — smoothing + offset 변화 모두 반영됨
	var cx := camera.get_screen_center_position().x
	var dx := cx - _prev_cam_x
	_prev_cam_x = cx

	# 구름(원거리): 화면에서 15% 속도 → 노드는 85% 같이 이동
	if bg_far_node:
		bg_far_node.position.x += dx * 0.85
	# 나무(중거리): 화면에서 45% 속도 → 노드는 55% 같이 이동
	if bg_mid_node:
		bg_mid_node.position.x += dx * 0.55

# ── 배경 ──────────────────────────────────────────────────
func _build_background() -> void:
	# 하늘 — CanvasLayer로 화면 고정 (항상 꽉 채움)
	var canvas := CanvasLayer.new()
	canvas.layer = -10
	add_child(canvas)
	var sky := ColorRect.new()
	sky.color = Color(0.55, 0.82, 0.98)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(sky)

	# 원거리: 구름 (world 공간, 패럴렉스 0.2x)
	bg_far_node = Node2D.new()
	add_child(bg_far_node)
	for i in 20:
		var cloud := Label.new()
		cloud.text = ["☁", "⛅", "☁"][i % 3]
		cloud.add_theme_font_size_override("font_size", randi_range(60, 110))
		cloud.modulate = Color(1, 1, 1, randf_range(0.6, 0.9))
		cloud.position = Vector2(i * 900 - 3000 + randi_range(-200, 200), randi_range(30, 160))
		bg_far_node.add_child(cloud)

	# 중거리: 나무/건물 (world 공간, 패럴렉스 0.5x)
	bg_mid_node = Node2D.new()
	add_child(bg_mid_node)
	var tree_emojis := ["🌲", "🌳", "🏠", "🌲", "🌳", "🏢", "🌲"]
	for i in 30:
		var tree := Label.new()
		tree.text = tree_emojis[i % tree_emojis.size()]
		tree.add_theme_font_size_override("font_size", randi_range(55, 90))
		tree.position = Vector2(i * 600 - 2000 + randi_range(-150, 150), GROUND_Y - randi_range(80, 130))
		bg_mid_node.add_child(tree)

# ── 지면 ──────────────────────────────────────────────────
func _build_ground() -> void:
	# 시각: 초록 땅
	var grass := ColorRect.new()
	grass.color = Color(0.28, 0.62, 0.18)
	grass.size = Vector2(WORLD_WIDTH, 300)
	grass.position = Vector2(-WORLD_WIDTH / 2, GROUND_Y)
	add_child(grass)

	var dirt := ColorRect.new()
	dirt.color = Color(0.55, 0.36, 0.18)
	dirt.size = Vector2(WORLD_WIDTH, 280)
	dirt.position = Vector2(-WORLD_WIDTH / 2, GROUND_Y + 20)
	add_child(dirt)

	# 충돌체
	var body := StaticBody2D.new()
	add_child(body)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WORLD_WIDTH, 40)
	col.shape = rect
	col.position = Vector2(0, GROUND_Y + 20)
	body.add_child(col)

# ── 플레이어 ───────────────────────────────────────────────
func _build_player() -> void:
	player = CharacterBody2D.new()
	player.position = Vector2(200, GROUND_Y - 60)
	add_child(player)

	# 충돌 캡슐
	var col := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.height = 100
	cap.radius = 28
	col.shape = cap
	col.position = Vector2(0, -50)
	player.add_child(col)

	# AnimatedSprite2D + 스프라이트 시트 로딩
	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.position = Vector2(0, -60)
	player.add_child(anim_sprite)
	_load_sprite_sheet()

	# 카메라
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.offset = Vector2(80, -40)   # 진행 방향 앞쪽을 더 보여줌
	player.add_child(camera)

func _load_sprite_sheet() -> void:
	var frames := SpriteFrames.new()

	# ── run 애니메이션 ──────────────────────────────────────
	var run_tex: Texture2D = load("res://assets/sprites/run.png")
	var run_img := run_tex.get_image()
	var run_fw := run_img.get_width() / RUN_FRAMES
	var run_fh := run_img.get_height()
	frames.add_animation("run")
	frames.set_animation_speed("run", ANIM_FPS)
	frames.set_animation_loop("run", true)
	for i in RUN_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = run_tex
		atlas.region = Rect2(i * run_fw, 0, run_fw, run_fh)
		frames.add_frame("run", atlas)

	# ── idle 애니메이션 ─────────────────────────────────────
	var idle_tex: Texture2D = load("res://assets/sprites/idle.png")
	var idle_img := idle_tex.get_image()
	var idle_fw := idle_img.get_width() / IDLE_FRAMES
	var idle_fh := idle_img.get_height()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", ANIM_FPS)
	frames.set_animation_loop("idle", true)
	for i in IDLE_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = idle_tex
		atlas.region = Rect2(i * idle_fw, 0, idle_fw, idle_fh)
		frames.add_frame("idle", atlas)

	anim_sprite.sprite_frames = frames

	# run 기준 스케일로 통일 (run 프레임 높이 기준, idle도 동일 배율 적용)
	var target_height := 600.0
	scale_run  = Vector2(target_height / run_fh, target_height / run_fh)
	scale_idle = scale_run  # 같은 배율 → 프레임 내 캐릭터 크기가 자연스럽게 맞춰짐
	anim_sprite.scale = scale_idle
	anim_sprite.play("idle")

func _tween_camera_offset(target_x: float) -> void:
	if camera.offset.x == target_x: return
	if _cam_tween: _cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.tween_property(camera, "offset:x", target_x, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── UI ────────────────────────────────────────────────────
func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	info_label = Label.new()
	info_label.position = Vector2(20, 16)
	info_label.add_theme_font_size_override("font_size", 22)
	info_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	canvas.add_child(info_label)

	var hint := Label.new()
	hint.text = "← → 이동   ↑ / Space 점프   Shift 스프린트"
	hint.position = Vector2(20, 690)
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	canvas.add_child(hint)

# ── 물리 루프 ─────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not player: return

	# 중력
	if not player.is_on_floor():
		player.velocity.y += GRAVITY * delta
	else:
		player.velocity.y = 0.0

	# 점프
	if player.is_on_floor() and (
		Input.is_action_just_pressed("ui_up") or
		Input.is_action_just_pressed("ui_accept")
	):
		player.velocity.y = JUMP_VELOCITY

	# 좌우 이동
	var dir := Input.get_axis("ui_left", "ui_right")
	var spd := SPRINT_SPEED if Input.is_action_pressed("ui_focus_next") else SPEED
	player.velocity.x = dir * spd

	player.move_and_slide()

	# 스프라이트 방향 + 카메라 offset 부드럽게 전환
	if dir < 0:
		anim_sprite.flip_h = true
		_tween_camera_offset(-80)
	elif dir > 0:
		anim_sprite.flip_h = false
		_tween_camera_offset(80)

	# 애니메이션 전환: 입력값(dir)으로 판단 — velocity는 물리 처리 후 튈 수 있음
	if dir != 0:
		if anim_sprite.animation != "run":
			anim_sprite.play("run")
			anim_sprite.scale = scale_run
		var spd_ratio: float = abs(player.velocity.x) / SPEED
		anim_sprite.speed_scale = max(0.6, spd_ratio)
	else:
		if anim_sprite.animation != "idle":
			anim_sprite.play("idle")
			anim_sprite.scale = scale_idle
		anim_sprite.speed_scale = 1.0

	# UI 업데이트
	if info_label:
		info_label.text = (
			"위치 X: %d   속도: %d px/s   %s" % [
				int(player.position.x),
				int(abs(player.velocity.x)),
				"[공중]" if not player.is_on_floor() else ""
			]
		)
