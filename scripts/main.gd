extends Node2D

const GROUND_Y     = 560.0
const WORLD_WIDTH  = 200_000.0

var player: CharacterBody2D
var anim_sprite: AnimatedSprite2D
var camera: Camera2D
var info_label: Label
var scale_idle: Vector2
var scale_run: Vector2
var scale_punch: Vector2

# 패럴렉스용 노드 레퍼런스
var bg_far_node: Node2D    # 원거리 빌딩 실루엣 — 느리게
var bg_mid_node: Node2D    # 중거리 빌딩 — 중간
var bg_road_node: Node2D   # 도로 마킹 — 고속 (건물의 5배)
var _prev_cam_x: float = 0.0  # 이전 프레임 카메라 실제 X
var _cam_tween: Tween         # 카메라 offset 부드럽게 전환
var _is_running: bool = false   # 달리는 중 여부 (배경 속도 배율용)
var _kicking: bool = false      # 발차기 중 (완료까지 다른 애니 차단)
var _punching: bool = false     # 연속펀치 중 (완료까지 다른 애니 차단)
var _jump_pending: bool = false  # 크라우치 준비 중 (6프레임 후 실제 점프)
var _was_airborne: bool = false  # 착지 감지용
var _landing: bool = false       # 착지 후 recovery 모션 재생 중

# ── 물리 상수 (에디터에서 바꾸고 싶으면 @export 추가) ──
const GRAVITY       = 1400.0
const SPEED         = 340.0
const SPRINT_SPEED  = 600.0
const JUMP_VELOCITY = -350.0  # 12FPS × 6프레임 공중 = 0.5s → v = g*0.25 = 350
const RUN_FRAMES    = 7      # run.png 프레임 수
const IDLE_FRAMES   = 24     # idle.png 프레임 수 (512px HD, 24프레임)
const KICK_FRAMES   = 9      # kick.png 프레임 수
const JUMP_FRAMES   = 17     # jump.png 프레임 수 (512px HD, 17프레임)
const PUNCH_FRAMES  = 44     # punch.png 프레임 수
const ANIM_FPS      = 12.0   # 재생 속도 (높을수록 빠름)

func _ready() -> void:
	_build_background()
	_build_ground()
	_build_road_markings()  # ground 다음 — 도로 위에 렌더링
	_build_player()
	_build_ui()
	_prev_cam_x = player.position.x  # 첫 프레임 점프 방지

func _process(_delta: float) -> void:
	if not player or not camera: return
	# 카메라 실제 화면 중심 X 기준 — smoothing + offset 변화 모두 반영됨
	var cx := camera.get_screen_center_position().x
	var dx := cx - _prev_cam_x
	_prev_cam_x = cx

	# 빌딩(원거리): 화면 45% 스크롤 / 달릴때 75%
	var far_factor := 0.25 if _is_running else 0.55
	# 빌딩(중거리): 화면 70% 스크롤 / 달릴때 90%
	var mid_factor := 0.10 if _is_running else 0.30
	# 도로 마킹: 화면 95% 스크롤 (건물 대비 ~5배 빠름)
	var road_factor := -1.85  # 카메라 속도의 2.85배로 대시가 역방향 질주
	if bg_far_node:
		bg_far_node.position.x += dx * far_factor
	if bg_mid_node:
		bg_mid_node.position.x += dx * mid_factor
	if bg_road_node:
		bg_road_node.position.x += dx * road_factor

# ── 배경 ──────────────────────────────────────────────────
func _build_background() -> void:
	# 누아르 하늘 — 거의 검정
	var canvas := CanvasLayer.new()
	canvas.layer = -10
	add_child(canvas)
	var sky := ColorRect.new()
	sky.color = Color(0.30, 0.12, 0.02)  # 다크 앰버/오렌지
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(sky)

	# 원거리: 대형 빌딩 실루엣 (흰 라인)
	bg_far_node = Node2D.new()
	add_child(bg_far_node)
	for i in 30:
		var bw := randi_range(80, 220)
		var bh := randi_range(280, 520)
		var bx := i * 700 - 6000 + randi_range(-100, 100)
		var by := GROUND_Y - bh
		_add_building(bg_far_node, bx, by, bw, bh, Color(1,1,1,0.7), 3)

	# 중거리: 소형 빌딩 (더 선명한 흰 라인)
	bg_mid_node = Node2D.new()
	add_child(bg_mid_node)
	for i in 25:
		var bw := randi_range(50, 130)
		var bh := randi_range(120, 260)
		var bx := i * 500 - 4000 + randi_range(-80, 80)
		var by := GROUND_Y - bh
		_add_building(bg_mid_node, bx, by, bw, bh, Color(1,1,1,0.9), 2)

func _add_building(parent: Node2D, bx: float, by: float, bw: float, bh: float, color: Color, border: int) -> void:
	# 외곽선 (흰색)
	var outline := ColorRect.new()
	outline.color = color
	outline.size = Vector2(bw, bh)
	outline.position = Vector2(bx, by)
	parent.add_child(outline)
	# 내부 (검정)
	var inner := ColorRect.new()
	inner.color = Color(0.30, 0.12, 0.02)  # 다크 앰버/오렌지
	inner.size = Vector2(bw - border * 2, bh - border)
	inner.position = Vector2(bx + border, by + border)
	parent.add_child(inner)
	# 창문 (일부만 켜진 상태)
	var ww := 10.0
	var wh := 8.0
	var cols := int((bw - 20) / (ww + 7))
	var rows := int((bh - 20) / (wh + 10))
	for r in rows:
		for c in cols:
			if randf() < 0.35:
				var win := ColorRect.new()
				win.color = color
				win.modulate.a = randf_range(0.3, 1.0)
				win.size = Vector2(ww, wh)
				win.position = Vector2(bx + 10 + c * (ww + 7), by + 12 + r * (wh + 10))
				parent.add_child(win)

# ── 지면 ──────────────────────────────────────────────────
func _build_ground() -> void:
	# 도로 (딥 네이비 아스팔트)
	var road := ColorRect.new()
	road.color = Color(0.22, 0.09, 0.01)  # 더 어두운 번트 오렌지
	road.size = Vector2(WORLD_WIDTH, 300)
	road.position = Vector2(-WORLD_WIDTH / 2, GROUND_Y)
	add_child(road)
	# 도로 상단 경계선 (흰 라인)
	var edge_top := ColorRect.new()
	edge_top.color = Color(1, 1, 1, 0.75)
	edge_top.size = Vector2(WORLD_WIDTH, 3)
	edge_top.position = Vector2(-WORLD_WIDTH / 2, GROUND_Y)
	add_child(edge_top)
	# 도로 하단 경계선
	var edge_bot := ColorRect.new()
	edge_bot.color = Color(1, 1, 1, 0.4)
	edge_bot.size = Vector2(WORLD_WIDTH, 2)
	edge_bot.position = Vector2(-WORLD_WIDTH / 2, GROUND_Y + 120)
	add_child(edge_bot)

	# 충돌체
	var body := StaticBody2D.new()
	add_child(body)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WORLD_WIDTH, 40)
	col.shape = rect
	col.position = Vector2(0, GROUND_Y + 20)
	body.add_child(col)

# ── 도로 마킹 (ground 위에 렌더링) ──────────────────────────
func _build_road_markings() -> void:
	bg_road_node = Node2D.new()
	add_child(bg_road_node)

	# 3열 차선 — 짧은 대시+큰 간격으로 속도감 극대화
	var dash_w    := 90    # 짧은 대시 (간격이 크면 더 빠르게 느껴짐)
	var gap_w     := 130
	var lane_defs := [
		{ "y": GROUND_Y + 18,  "alpha": 1.0,  "h": 8 },  # 상단 (선명)
		{ "y": GROUND_Y + 52,  "alpha": 0.65, "h": 6 },  # 중앙
		{ "y": GROUND_Y + 88,  "alpha": 0.35, "h": 4 },  # 하단 (원근감)
	]
	var dash_count := 200
	for lane in lane_defs:
		for i in dash_count:
			var dash := ColorRect.new()
			dash.color = Color(1, 1, 1, lane["alpha"])
			dash.size = Vector2(dash_w, lane["h"])
			dash.position = Vector2(i * (dash_w + gap_w) - 12000.0, lane["y"])
			bg_road_node.add_child(dash)

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
	camera.offset = Vector2(80, -150)  # 캐릭터 위주, 땅이 화면 하단에 오도록
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

	# ── kick 애니메이션 ─────────────────────────────────────
	var kick_tex: Texture2D = load("res://assets/sprites/kick.png")
	var kick_img := kick_tex.get_image()
	var kick_fw := kick_img.get_width() / KICK_FRAMES
	var kick_fh := kick_img.get_height()
	frames.add_animation("kick")
	frames.set_animation_speed("kick", ANIM_FPS)
	frames.set_animation_loop("kick", false)  # 한 번만 재생
	for i in KICK_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = kick_tex
		atlas.region = Rect2(i * kick_fw, 0, kick_fw, kick_fh)
		frames.add_frame("kick", atlas)

	# ── jump 애니메이션 ─────────────────────────────────────
	var jump_tex: Texture2D = load("res://assets/sprites/jump.png")
	var jump_img := jump_tex.get_image()
	var jump_fw := jump_img.get_width() / JUMP_FRAMES
	var jump_fh := jump_img.get_height()
	frames.add_animation("jump")
	frames.set_animation_speed("jump", ANIM_FPS)
	frames.set_animation_loop("jump", false)  # 한 번 재생 후 마지막 프레임 유지
	for i in JUMP_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = jump_tex
		atlas.region = Rect2(i * jump_fw, 0, jump_fw, jump_fh)
		frames.add_frame("jump", atlas)

	# ── punch 애니메이션 ────────────────────────────────────
	var punch_tex: Texture2D = load("res://assets/sprites/punch.png")
	var punch_img := punch_tex.get_image()
	var punch_fw := punch_img.get_width() / PUNCH_FRAMES
	var punch_fh := punch_img.get_height()
	frames.add_animation("punch")
	frames.set_animation_speed("punch", ANIM_FPS)
	frames.set_animation_loop("punch", false)
	for i in PUNCH_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = punch_tex
		atlas.region = Rect2(i * punch_fw, 0, punch_fw, punch_fh)
		frames.add_frame("punch", atlas)

	anim_sprite.sprite_frames = frames
	anim_sprite.animation_finished.connect(_on_kick_finished)

	scale_run   = Vector2(1.25, 1.25)  # HD 512px
	scale_idle  = Vector2(1.25, 1.25)  # HD 512px
	scale_punch = Vector2(0.9, 0.9)    # 펀치 스프라이트 아트워크가 더 크게 그려짐
	anim_sprite.scale = scale_idle
	anim_sprite.play("idle")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode
		if (kc == KEY_SPACE or kc == KEY_Z) and not _kicking and not _punching:
			_kicking = true
			anim_sprite.play("kick")
			anim_sprite.scale = Vector2(2.5, 2.5)
		elif kc == KEY_X and not _kicking and not _punching:
			_punching = true
			anim_sprite.play("punch")
			anim_sprite.scale = scale_punch

func _on_kick_finished() -> void:
	if anim_sprite.animation == "kick":
		_kicking = false
		anim_sprite.play("idle")
		anim_sprite.scale = scale_idle
	elif anim_sprite.animation == "punch":
		_punching = false
		anim_sprite.play("idle")
		anim_sprite.scale = scale_idle
	elif anim_sprite.animation == "jump":
		_landing = false
		anim_sprite.play("idle")
		anim_sprite.scale = scale_idle

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
	hint.text = "← → 이동   ↑ 점프   Shift 스프린트   Space/Z 발차기   X 연속펀치"
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

	# 점프 입력 → 크라우치 애니 시작 (아직 y 이동 없음)
	if player.is_on_floor() and not _jump_pending and not _kicking and not _punching and \
		Input.is_action_just_pressed("ui_up"):
		_jump_pending = true
		anim_sprite.play("jump")
		anim_sprite.scale = scale_idle
		anim_sprite.speed_scale = 1.0

	# 6번째 프레임(0-indexed=6)에서 실제 점프 발동
	if _jump_pending and player.is_on_floor() and anim_sprite.frame >= 6:
		player.velocity.y = JUMP_VELOCITY
		_jump_pending = false

	# 좌우 이동
	var dir := Input.get_axis("ui_left", "ui_right")
	var spd := SPRINT_SPEED if Input.is_action_pressed("ui_focus_next") else SPEED
	player.velocity.x = dir * spd

	player.move_and_slide()

	# 착지 감지 → jump 애니 13번 프레임(index 12)으로 스냅 후 recovery 재생
	var is_on_floor_now := player.is_on_floor()
	if anim_sprite.animation == "jump" and not _jump_pending:
		if _was_airborne and is_on_floor_now and anim_sprite.frame < 12:
			anim_sprite.frame = 12
			_landing = true
			anim_sprite.play("jump")  # frame 12부터 끝까지 재생
	_was_airborne = not is_on_floor_now

	# 스프라이트 방향 + 카메라 offset 부드럽게 전환
	if dir < 0:
		anim_sprite.flip_h = true
		_tween_camera_offset(-80)
	elif dir > 0:
		anim_sprite.flip_h = false
		_tween_camera_offset(80)

	_is_running = dir != 0 and not _kicking and not _punching and not _jump_pending and not _landing

	# 발차기 / 펀치 / 점프 준비 / 착지 recovery 중이면 애니 전환 차단
	if not _kicking and not _punching and not _jump_pending and not _landing:
		if not player.is_on_floor():
			# 공중: 점프 애니 (준비 후 이미 재생 중이면 그대로 유지)
			if anim_sprite.animation != "jump":
				anim_sprite.play("jump")
				anim_sprite.scale = scale_idle
		elif dir != 0:
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
