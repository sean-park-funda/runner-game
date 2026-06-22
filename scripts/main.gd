extends Node2D

const GROUND_Y     = 560.0
const WORLD_WIDTH  = 200_000.0

var player: CharacterBody2D
var anim_sprite: AnimatedSprite2D
var camera: Camera2D
var info_label: Label
var scale_idle: Vector2
var scale_run: Vector2

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

# ── 배경 ──────────────────────────────────────────────────
func _build_background() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = -10
	add_child(canvas)

	var sky := ColorRect.new()
	sky.color = Color(0.55, 0.82, 0.98)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(sky)

	# 구름
	for i in 8:
		var cloud := Label.new()
		cloud.text = ["☁", "⛅"][i % 2]
		cloud.add_theme_font_size_override("font_size", randi_range(60, 100))
		cloud.modulate = Color(1, 1, 1, 0.8)
		cloud.position = Vector2(i * 450 + randi_range(-80, 80), randi_range(40, 180))
		canvas.add_child(cloud)

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

	# 두 애니 모두 화면에서 동일한 높이(600px)로 보이도록 각각 스케일 계산
	var target_height := 600.0
	scale_idle = Vector2(target_height / idle_fh, target_height / idle_fh)
	scale_run  = Vector2(target_height / run_fh,  target_height / run_fh)
	anim_sprite.scale = scale_idle
	anim_sprite.play("idle")

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

	# 스프라이트 방향
	if dir < 0:
		anim_sprite.flip_h = true
		camera.offset.x = -80
	elif dir > 0:
		anim_sprite.flip_h = false
		camera.offset.x = 80

	# 애니메이션 전환: 움직일 때 run, 정지 시 idle (각각 맞는 스케일 적용)
	if abs(player.velocity.x) > 10.0:
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
