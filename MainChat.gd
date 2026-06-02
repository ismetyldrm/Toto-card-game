@tool
extends Control

const message_scene = preload("res://Scenes/Message_Scene.tscn")

@export var current_account: Account

@export var chat_size: float:
	set(value):
		if value > 0:
			print("check size: ", value)
			$MarginContainer.scale = Vector2(value, value)
			chat_size = value
			
@export var message_limit: int = 100

func send_message(account, message):
	var scroll_container = $MarginContainer/VBoxContainer/ScrollContainer
	var chat_box = scroll_container.get_node("ChatBox")
	var scrollbar = scroll_container.get_v_scroll_bar() # Scrollbar'ı direkt yakala
	
	if account && !message.is_empty():
		if chat_box.get_child_count() + 1 > message_limit:
			chat_box.get_child(0).queue_free()
		
		$MarginContainer/VBoxContainer/SendMessage.text = "" 
		
	var message_copy = message_scene.instantiate()
	message_copy.set_data(account, message)
	chat_box.add_child(message_copy) # Mesajı ekledik 
	
	await scrollbar.changed 
	
	
	scroll_container.scroll_vertical = scrollbar.max_value
# Enter'a basınca: mesajı ağa yayınla
func _on_line_edit_text_submitted(new_text: String) -> void:
	var send_field = $MarginContainer/VBoxContainer/SendMessage
	if new_text.strip_edges() == "":
		send_field.text = ""
		return

	var gonderen = "Oyuncu"
	if "local_player_name" in NetworkManager:
		gonderen = NetworkManager.local_player_name

	send_field.text = ""   # girişi sadece gönderende temizle

	if multiplayer.has_multiplayer_peer() and NetworkManager.game_mode == NetworkManager.GameMode.MULTIPLAYER:
		rpc("_mp_mesaj_al", gonderen, new_text)   # call_local → bende de görünür
	else:
		_mesaj_goster(gonderen, new_text)         # tek kişilik / yerel


func _on_chat_size_text_submitted(new_text: String) -> void:
	chat_size = float(new_text)
	
@rpc("any_peer", "call_local", "reliable")
func _mp_mesaj_al(gonderen_isim: String, mesaj: String):
	_mesaj_goster(gonderen_isim, mesaj)
	
# Sadece GÖSTERİM yapar (girişi temizlemez — alıcıların yazdığı silinmesin)
func _mesaj_goster(gonderen_isim: String, mesaj: String):
	var scroll_container = $MarginContainer/VBoxContainer/ScrollContainer
	var chat_box = scroll_container.get_node("ChatBox")
	var scrollbar = scroll_container.get_v_scroll_bar()
	
	if mesaj.is_empty():
		return
	if chat_box.get_child_count() + 1 > message_limit:
		chat_box.get_child(0).queue_free()

	var message_copy = message_scene.instantiate()
	var acc = Account.new()
	acc.username = gonderen_isim          # ←—— Account'taki isim alanı buysa
	message_copy.set_data(acc, mesaj)
	chat_box.add_child(message_copy)

	await scrollbar.changed
	scroll_container.scroll_vertical = scrollbar.max_value
