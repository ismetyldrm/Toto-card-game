extends Node2D

const CARD_SCENE_PATH = "res://Scenes/Card.tscn"
const CARD_WIDTH = 200
const HAND_Y_POSITION = 1600 

var player_hand = []
# Nil hatasını önlemek için ekran ortasını burada hesaplıyoruz
@onready var center_screen_x = get_viewport_rect().size.x / 2
@onready var deal_sound = $DealSound


func _ready() -> void:
	pass



func deal_new_hand(cards_input: Array, start_global_pos: Vector2):
	for card in player_hand:
		if is_instance_valid(card):
			card.name = "deleted"
			card.queue_free()
	player_hand.clear()
	
	var card_scene = preload(CARD_SCENE_PATH)
	
	for item in cards_input:
		if item == null: continue
		
		var new_card: Node2D
		
		if item is Node2D:
			new_card = item
		else:
			new_card = card_scene.instantiate()
			new_card.card_id = item
			new_card.name = item
			get_node("../CardManager").add_child(new_card)
			
		new_card.setup_appearance()
		new_card.global_position = start_global_pos
		
		if new_card.has_node("ShadowImage"):
			new_card.get_node("ShadowImage").set_deferred("visible", true)
		
		if new_card not in player_hand:
			player_hand.append(new_card)
			
		
		update_hand_positions()
		if deal_sound:
			deal_sound.pitch_scale = randf_range(0.9, 1.1) 
			deal_sound.play(0.12)
		
		await get_tree().create_timer(0.1).timeout



func add_card_to_hand(card):
	if card not in player_hand:
		player_hand.insert(0, card)
		update_hand_positions()
	else:
		animate_card_to_position(card, card.starting_position)
	

func update_hand_positions():
	var num_cards = player_hand.size()
	if num_cards == 0: return
	
	var spacing = 180
	var center_count = min(num_cards, 7)
	
	
	var viewport_size = get_viewport_rect().size
	var current_center_x = 1500
	var base_y = viewport_size.y - 180 

	for i in range(num_cards):
		var card = player_hand[i]
		var target_y_offset = 0 
		
		if i >= 7:
			target_y_offset -= 80
		
		var row_index = i if i < 7 else i - 7
		
		var x_pos = current_center_x + (row_index - (center_count - 1) / 2.0) * spacing
		
		if i >= 7:
			x_pos += spacing / 2.0

		var final_y = base_y + target_y_offset
		var new_position = Vector2(x_pos, final_y) 
		
		card.starting_position = new_position
		animate_card_to_position(card, new_position)
		
		if i >= 7:
			card.z_index = 5
			card.set_meta("orijinal_z", 5)
		else:
			card.z_index = 10
			card.set_meta("orijinal_z", 10)
			
func has_suit(suit_name: String) -> bool:
	for card in player_hand:
		if card.suit == suit_name:
			return true
	return false
	
func calculate_card_position(index):
	var current_center_x = get_viewport_rect().size.x / 2
	var total_width = (player_hand.size() - 1) * CARD_WIDTH
	@warning_ignore("integer_division")
	var x_offset = current_center_x + index * CARD_WIDTH - total_width / 2
	return x_offset

func animate_card_to_position(card, new_position):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "global_position", new_position, 0.1)
	if card.has_node("ShadowImage"):
		tween.tween_property(card.get_node("ShadowImage"), "position", Vector2(0, 25), 0.2)
		
func remove_card_from_hand(card):
	if card in player_hand:
		player_hand.erase(card)
		update_hand_positions()
