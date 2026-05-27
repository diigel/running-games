extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/VBoxContainer/FinalScoreLabel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton


func _ready() -> void:
	game_over_panel.hide()
	restart_button.pressed.connect(_on_restart_pressed)


func update_score(value: int) -> void:
	score_label.text = "Score: %d" % value


func show_game_over(final_score: int) -> void:
	final_score_label.text = "Score: %d" % final_score
	game_over_panel.show()
	restart_button.grab_focus()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
