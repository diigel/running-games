extends CharacterBody3D

# Kecepatan maju konstan ke arah Z negatif
const Z_SPEED: float = -10.0

# Posisi X ketiga jalur: Kiri, Tengah, Kanan
const LANE_POSITIONS: Array[float] = [-3.0, 0.0, 3.0]

# Kecepatan smooth saat berpindah jalur (faktor proporsional per detik)
const LANE_SWITCH_SPEED: float = 12.0

# Indeks jalur aktif: 0 = Kiri, 1 = Tengah, 2 = Kanan
var current_lane: int = 1


func _ready() -> void:
	# Tempatkan karakter di Jalur Tengah saat game mulai
	position.x = LANE_POSITIONS[current_lane]


func _physics_process(delta: float) -> void:
	# Deteksi input pindah jalur kiri (batasi agar tidak keluar dari jalur paling kiri)
	if Input.is_action_just_pressed("ui_left") and current_lane > 0:
		current_lane -= 1

	# Deteksi input pindah jalur kanan (batasi agar tidak keluar dari jalur paling kanan)
	if Input.is_action_just_pressed("ui_right") and current_lane < 2:
		current_lane += 1

	# Ambil posisi X target dari jalur yang sedang aktif
	var target_x: float = LANE_POSITIONS[current_lane]

	# Gerakkan X secara smooth menuju target jalur — semakin dekat, semakin lambat (ease-out alami)
	velocity.x = (target_x - position.x) * LANE_SWITCH_SPEED

	# Gerakan maju konstan di sumbu Z (negatif = ke depan)
	velocity.z = Z_SPEED

	# Terapkan velocity dan tangani collision via physics engine
	move_and_slide()
