extends CanvasLayer

@onready var avg_label = $Background/CenterContainer/MainVBox/AvgLabel
@onready var results_container = $Background/CenterContainer/MainVBox/ResultsContainer
@onready var new_game_btn = $Background/CenterContainer/MainVBox/ButtonsContainer/NewGameBtn

func _ready():
	hide()

func setup_results(scores: Array, isimler: Array, is_multiplayer: bool):
	for child in results_container.get_children():
		child.queue_free()
		
	# 2. Ortalama Puanı Hesapla
	var total_sum = 0
	for s in scores:
		total_sum += s
	
	var average = float(total_sum) / 4.0
	avg_label.text = "Ortalama Puan: " + str(average)
	avg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avg_label.add_theme_color_override("font_color", Color.BLACK)
	avg_label.add_theme_font_size_override("font_size", 36)
	
	# 3. Oyuncu Sonuçlarını Dinamik Oluştur
	for i in range(4):
		var p_score = scores[i]
		var is_winner = p_score >= average
		var result_text = "ÇIKTI" if is_winner else "BATTI"
		
		var p_label = Label.new()
		p_label.text = "%s : %d Puan -> %s" % [isimler[i], p_score, result_text]
		p_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		p_label.add_theme_font_size_override("font_size", 36)
		
		if is_winner:
			p_label.add_theme_color_override("font_color", Color.BLACK)
		else:
			p_label.add_theme_color_override("font_color", Color.BLACK)
			
		results_container.add_child(p_label)
		
	if is_multiplayer:
		new_game_btn.hide()
	else:
			new_game_btn.show()
		
	show()
	
func _on_main_menu_btn_pressed():
	if NetworkManager.game_mode == NetworkManager.GameMode.MULTIPLAYER:
		multiplayer.multiplayer_peer = null 
	
	# Kendi ana menü sahnenin yolunu buraya yaz:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn") 

func _on_new_game_btn_pressed():
	get_tree().reload_current_scene()
