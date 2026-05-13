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
	
	# --- KURŞUN GEÇİRMEZ KAYDIRMA MANTIĞI ---
	# await process_frame yerine, scrollbar'ın boyutu güncellenene kadar bekliyoruz
	await scrollbar.changed 
	
	# Boyut güncellendiği an en aşağıya çek
	scroll_container.scroll_vertical = scrollbar.max_value
func _on_line_edit_text_submitted(new_text: String) -> void:
	send_message(current_account,new_text)


func _on_chat_size_text_submitted(new_text: String) -> void:
	chat_size = float(new_text)
