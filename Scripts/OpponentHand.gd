extends Node2D

const CARD_SCENE_PATH = "res://Scenes/Card.tscn"
var cards_in_hand = []
@export_enum("horizontal", "vertical") var hand_direction = "horizontal"
@export_enum("Top", "Bottom", "Left", "Right") var hand_side = "Top"



@warning_ignore("unused_parameter")
func connect_card_signals(card):
	pass


func deal_hand(card_names: Array, start_global_pos: Vector2):
	for card in cards_in_hand:
		if is_instance_valid(card): card.queue_free()
	cards_in_hand.clear()
	
	var card_scene = preload(CARD_SCENE_PATH)
	
	# 2. Gelen diziyi tek tek dön
	for item in card_names:
		if item == null: continue
		
		var new_card: Node2D
		
		if item is Node2D:
			new_card = item
			
			if new_card.get_parent():
				new_card.get_parent().remove_child(new_card)
			add_child(new_card)
		else:
			new_card = card_scene.instantiate()
			new_card.card_id = item
			new_card.name = item
			add_child(new_card) 
		
		new_card.is_draggable = false
		new_card.is_face_up = false 
		new_card.setup_appearance()
		
		new_card.global_position = start_global_pos
		cards_in_hand.append(new_card)
		
	update_hand_positions()

func update_hand_positions():
	var num_cards = cards_in_hand.size()
	if num_cards == 0: return

	var spacing = 35       
	var angle_step = 4.0   
	var arc_radius = 10.0  

	for i in range(num_cards):
		var card = cards_in_hand[i]
		var target_pos = Vector2.ZERO
		var target_rot = 0
		
		var offset = (i - (num_cards - 1) / 2.0) * spacing
		var fan_rotation = (i - (num_cards - 1) / 2.0) * angle_step
		var fan_arc_offset = abs(i - (num_cards - 1) / 2.0) * arc_radius

		match hand_side:
			"Top":
				target_pos.x = offset
				target_pos.y = -fan_arc_offset 
				target_rot = -fan_rotation    
			"Bottom":
				target_pos.x = offset
				target_pos.y = fan_arc_offset  
				target_rot = fan_rotation
			"Right":
				target_pos.y = offset
				target_pos.x = fan_arc_offset  
				target_rot = 90 - fan_rotation
			"Left":
				target_pos.y = offset
				target_pos.x = -fan_arc_offset 
				target_rot = -90 + fan_rotation

		card.z_index = i 
		animate_opponent_card(card, target_pos, target_rot)

func animate_opponent_card(card, new_position, new_rotation):
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(card, "position", new_position, 0.2)
	tween.tween_property(card, "rotation_degrees", new_rotation, 0.2)
