extends Node2D

signal hovered
signal hovered_off

var is_draggable = true 
var starting_position
var is_face_up = true # Bu değişken OpponentHand tarafından 'false' yapılır.

var card_id: String = ""
var suit: String = ""
var value: int = 0

func _ready() -> void:
	# CardManager veya OpponentHand ile olan sinyal bağlantısı 
	if get_parent().has_method("connect_card_signals"):
		get_parent().connect_card_signals(self)
	
	# GÖRÜNÜM AYARI (Sadece bu blok yeterlidir)
	setup_appearance()
	
func setup_appearance():
	if card_id == "":
		return
	
	# 1. İsimden Seri ve Değer Ayıkla (Örn: "hearts_ace" -> suit: "Hearts", value: 14)
	var parts = card_id.split("_")
	if parts.size() == 2:
		# CardManager ile uyum için ilk harfi büyük yapıyoruz (hearts -> Hearts)
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



# Fare etkileşimleri [cite: 11]
func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
