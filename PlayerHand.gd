extends Node2D

const CARD_SCENE_PATH = "res://Scenes/Card.tscn"
const CARD_WIDTH = 200
const HAND_Y_POSITION = 1600 

var player_hand = []
# Nil hatasını önlemek için ekran ortasını burada hesaplıyoruz
@onready var center_screen_x = get_viewport_rect().size.x / 2

func _ready() -> void:
	pass



func deal_new_hand(cards_input: Array, start_global_pos: Vector2):
	# 1. Eski eli temizle
	for card in player_hand:
		if is_instance_valid(card):
			card.name = "deleted"
			card.queue_free()
	player_hand.clear()
	
	var card_scene = preload(CARD_SCENE_PATH)
	
	# 2. Gelen diziyi tek tek kontrol et
	for item in cards_input:
		if item == null: continue
		
		var new_card: Node2D
		
		# --- KRİTİK MULTIPLAYER / SINGLEPLAYER GÜVENCESİ ---
		if item is Node2D:
			# Eğer CardManager bize zaten instantiate edilmiş HAZIR KART nesnesi yolladıysa (Multiplayer):
			new_card = item
		else:
			# Eğer bize sadece kartın ismi String olarak geldiyse (Singleplayer):
			new_card = card_scene.instantiate()
			new_card.card_id = item
			new_card.name = item
			# Singleplayer'da kart CardManager'a otomatik eklenmediği için burada ekliyoruz:
			get_node("../CardManager").add_child(new_card)
			
		# 3. Görünümünü ve ortak koordinatlarını ayarla
		new_card.setup_appearance()
		new_card.global_position = start_global_pos
		
		# 4. El hafızamıza ekle
		if new_card not in player_hand:
			player_hand.insert(0, new_card)

	# Tüm kartlar dizildikten sonra pozisyonları pürüzsüzce güncelle
	update_hand_positions()

func add_card_to_hand(card):
	if card not in player_hand:
		player_hand.insert(0, card)
		update_hand_positions()
	else:
		animate_card_to_position(card, card.starting_position)
	
# PlayerHand.gd içindeki update_hand_positions fonksiyonunun revize hali

func update_hand_positions():
	var num_cards = player_hand.size()
	if num_cards == 0: return
	
	var spacing = 180
	var center_count = min(num_cards, 7)
	
	# HATA ÇÖZÜMÜ: Ekran boyutlarını doğrudan burada alıyoruz. 
	# @onready beklemediğimiz için 'Nil' hatası almayız.
	var viewport_size = get_viewport_rect().size
	var current_center_x = 1500
	var base_y = viewport_size.y - 180 

	for i in range(num_cards):
		var card = player_hand[i]
		var target_y_offset = 0 
		
		if i >= 7:
			target_y_offset -= 80
		
		# Sıra içindeki indeksi belirle (0-6 arası ilk sıra, 7+ ikinci sıra)
		var row_index = i if i < 7 else i - 7
		
		# X KONUMU: 'current_center_x' kullanarak ekran ortasına göre hizalıyoruz
		var x_pos = current_center_x + (row_index - (center_count - 1) / 2.0) * spacing
		
		if i >= 7:
			x_pos += spacing / 2.0

		var final_y = base_y + target_y_offset
		var new_position = Vector2(x_pos, final_y) 
		
		card.starting_position = new_position
		animate_card_to_position(card, new_position)
		
		if i >= 7:
			card.z_index = 5
		else:
			card.z_index = 10
			
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

func remove_card_from_hand(card):
	if card in player_hand:
		player_hand.erase(card)
		update_hand_positions()
