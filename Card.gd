extends Node2D

signal hovered
signal hovered_off

var is_draggable = true 
var starting_position
var is_face_up = true 

var card_id: String = ""
var suit: String = ""
var value: int = 0

func _ready() -> void:
	if get_parent().has_method("connect_card_signals"):
		get_parent().connect_card_signals(self)

	setup_appearance()
	
func setup_appearance():
	if card_id == "":
		return
	
	var parts = card_id.split("_")
	if parts.size() == 2:
		self.suit = parts[0].capitalize() 
		
		var val_str = parts[1]
		if val_str == "ace": self.value = 14
		elif val_str == "king": self.value = 13
		elif val_str == "queen": self.value = 12
		elif val_str == "jack": self.value = 11
		else: self.value = val_str.to_int()
	var texture_path = ""
	if is_face_up:
		texture_path = "res://Cards/" + card_id + ".png"
	else:
		texture_path = "res://Cards/back01.png"
	
	if FileAccess.file_exists(texture_path):
		$CardImage.texture = load(texture_path)
	else:
		push_error("HATA: Kart resmi bulunamadı! Yol: " + texture_path)
	


func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
