extends Control

const GAME_SCENE_PATH = "res://main.tscn" 

const ODA_AC_POPUP_SCENE = preload("res://material/OdaAc.tscn")
const ODA_BUL_POPUP_SCENE = preload("res://Scenes/OdaBul.tscn")

var active_oda_ac_popup = null
var active_oda_bul_popup = null

func _ready() -> void:
	$VBoxContainer/Button.grab_focus()

func _on_hizli_oyun_pressed() -> void:
	print("Hızlı Oyun başlatılıyor...")
	NetworkManager.game_mode = NetworkManager.GameMode.SINGLEPLAYER
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		print("HATA: Sahne dosyası bulunamadı! GAME_SCENE_PATH değişkenini kontrol et.")
		
func _on_oda_ara_pressed() -> void:
	print("Oda Ara penceresi açılıyor...")
	_clear_popups()
	
	# Oda Bul sahnesini canlandırıp (instantiate) ekrana ekliyoruz
	active_oda_bul_popup = ODA_BUL_POPUP_SCENE.instantiate()
	add_child(active_oda_bul_popup)
	active_oda_bul_popup.show()

# main_menu.gd dosyanın içindeki ilgili kısım:


func _on_oda_aç_pressed() -> void:
	print("Oda Aç penceresi açılıyor...")
	
	if is_instance_valid(active_oda_ac_popup):
		active_oda_ac_popup.queue_free()
	
	active_oda_ac_popup = ODA_AC_POPUP_SCENE.instantiate()
	add_child(active_oda_ac_popup)
	
	active_oda_ac_popup.set_anchors_preset(Control.PRESET_CENTER)

func _on_cikis_pressed() -> void:
	print("Oyundan çıkılıyor. Görüşmek üzere!")
	get_tree().quit()

# Pencerelerin üst üste binmesini engelleyen temizlik fonksiyonu
func _clear_popups():
	if is_instance_valid(active_oda_ac_popup):
		active_oda_ac_popup.queue_free()
	if is_instance_valid(active_oda_bul_popup):
		active_oda_bul_popup.queue_free()
