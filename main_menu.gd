extends Control


const GAME_SCENE_PATH = "res://main.tscn" 

func _ready() -> void:
	# Klavye/Gamepad desteği için ilk butonun seçili gelmesini sağlar
	$VBoxContainer/Button.grab_focus()

func _on_hizli_oyun_pressed() -> void:
	print("Hızlı Oyun başlatılıyor...")
	# Sahne değiştirme komutu
	var error = get_tree().change_scene_to_file(GAME_SCENE_PATH)
	
	if error != OK:
		print("HATA: Sahne dosyası bulunamadı! GAME_SCENE_PATH değişkenini kontrol et.")

func _on_oda_ara_pressed() -> void:
	# Gelecekte ekleyeceğin Multiplayer mantığı için placeholder
	print("Oda Ara sistemi henüz aktif değil.")

func _on_oda_aç_pressed() -> void:
	# Gelecekte ekleyeceğin Multiplayer mantığı için placeholder
	print("Oda Aç sistemi henüz aktif değil.")

func _on_cikis_pressed() -> void:
	print("Oyundan çıkılıyor. Görüşmek üzere!")
	get_tree().quit()
