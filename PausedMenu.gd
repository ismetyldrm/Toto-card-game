extends Control



var _is_paused:bool = false:
	set = set_paused
	
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_is_paused = !_is_paused
	
	
func set_paused(value: bool) -> void:
	_is_paused = value
	get_tree().paused = _is_paused
	visible = _is_paused
	
	var bidding_panel = get_node_or_null("BiddingPanel") 
	
	if bidding_panel:
		if _is_paused:
			bidding_panel.hide() 
		else:
			bidding_panel.show()
	
func _on_resume_button_pressed() -> void:
	_is_paused = false

func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_settings_button_pressed() -> void:
	print("Ayarlar menüsü henüz hazır değil")
	
