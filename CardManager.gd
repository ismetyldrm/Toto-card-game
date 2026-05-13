extends Node2D

const COLLISON_MASK_CARD = 1
const COLLISON_MASK_CARD_SLOT = 2

var current_turn = 0 # 0: Oyuncu, 1: Bot1, 2: Bot2, 3: Bot3
var is_bot_playing = false

var player_bids = [0, 0, 0, 0] # Her raunt başında alınan tahminler
var tricks_won = [0, 0, 0, 0]  # O raunt içinde kazanılan el sayısı
var lead_suit = ""             # Masaya atılan ilk kartın rengi
var current_trump_suit: String = "" # Raunt boyunca değişmeyecek gerçek koz

var card_being_dragged
var screen_size
var is_hovering_on_card
var player_hand_referance

var current_round = 1
const MAX_CARDS_PER_ROUND = 13
const TOTAL_ROUNDS = 19

var koz_kart_nesnesi = null
const KOZ_POSITION = Vector2(300,1600)
@onready var scoreboard_manager = $"../CanvasLayer2/MarginContainer/VBoxContainer/ScoreBoardPanel"
@onready var result_label = $"../CanvasLayer/ResultLabel"
@onready var score_status_label = $"../CanvasLayer/MarginContainer/ScoreStatusLabel"
@onready var bidding_panel = $"../BiddingPanel" 
@onready var buttons_container = $"../BiddingPanel/VBoxContainer/HBoxContainer"
@onready var bidding_label = $"../BiddingPanel/VBoxContainer/Label"
@onready var spin_boxes = [
	get_node("../BiddingPanel/VBoxContainer/HBoxContainer/VBoxContainer1/Player1Spin"),
	get_node("../BiddingPanel/VBoxContainer/HBoxContainer/VBoxContainer2/Player2Spin"),
	get_node("../BiddingPanel/VBoxContainer/HBoxContainer/VBoxContainer3/Player3Spin"),
	get_node("../BiddingPanel/VBoxContainer/HBoxContainer/VBoxContainer4/Player4Spin"),
]
@onready var confirm_button = $"../BiddingPanel/VBoxContainer/ConfirmButton"

var player_bids_before = [0,0,0,0]
var bids_received = 0         # Kaç kişi tahmin yaptı?
var current_bidder = 0        # Şu an kim tahmin yapıyor?
var is_bidding_phase = false  # İhale süreci aktif mi?

# CardManager.gd dosyasının başı
@onready var player_slot = get_node("../CardSlot")

@onready var center_slots = [
	get_node("../CardSlot"),
	get_node("../Opponent1CardSlot"),
	get_node("../Opponent2CardSlot"),
	get_node("../Opponent3CardSlot")
]

func _ready() -> void:
	screen_size = get_viewport_rect().size
	player_hand_referance = $"../PlayerHand"
	start_new_round()

func start_new_round():
	is_bidding_phase = true
	# 1. TEMİZLİK
	if is_instance_valid(koz_kart_nesnesi): 
		koz_kart_nesnesi.queue_free() 
	koz_kart_nesnesi = null 
	current_trump_suit = "" 

	# 2. DESTE VE KOORDİNAT HAZIRLIĞI
	var deck_node = get_node("../Deck")
	deck_node.create_deck() 
	var deck_start_pos = deck_node.global_position 
	
	# 3. RAUNT AYARLARINI ÇEK
	var settings = get_round_settings()
	var card_count = settings.cards
	
	# 4. KART DAĞITIMI
	for p_index in range(4):
		var current_drawn_cards = []
		for i in range(card_count):
			var card = deck_node.draw_card()
			if card:
				current_drawn_cards.append(card)
		
		if p_index == 0:
			player_hand_referance.deal_new_hand(current_drawn_cards, deck_start_pos)
		else:
			var opponent_path = "../OpponentHand" + str(p_index)
			if has_node(opponent_path):
				get_node(opponent_path).deal_hand(current_drawn_cards, deck_start_pos)
	
	# 5. KOZ BELİRLEME MANTIĞI
	if settings.is_sanzoti:
		current_trump_suit = "None"
		print("--- RAUNT BAŞLADI: SANZOTİ ---")
	elif settings.trump != "Random":
		current_trump_suit = settings.trump
		var koz_ismi = deck_node.draw_card()
		if koz_ismi: create_koz_card(koz_ismi, deck_start_pos)
	else:
		var koz_ismi = deck_node.draw_card() 
		if koz_ismi: 
			var parts = koz_ismi.split("_")
			current_trump_suit = parts[0].capitalize() 
			create_koz_card(koz_ismi, deck_start_pos)

	
	current_turn = (3 + (current_round - 1) * 3) % 4
	is_bot_playing = false 
	
	await get_tree().create_timer(1.5).timeout 
	start_bidding_phase()


func get_card_from_slot(index):
	var slot = center_slots[index]
	# CardManager'ın çocukları arasında, pozisyonu bu slotla aynı olan kartı bulur
	for child in get_children():
		if child is Node2D and child.has_method("setup_appearance"):
			if child.global_position.distance_to(slot.global_position) < 40:
				return child
	return null
	
func get_round_settings():
	# Varsayılan ayarlar
	var settings = {"cards": 1, "trump": "Random", "is_sanzoti": false}
	
	if current_round <= 12: # 13'e kadar çıkabiliriz (52/4)
		settings.cards = current_round
		settings.trump = "Random" # Desteden çekilecek
	elif current_round <= 16:
		settings.cards = 13
		var trumps = ["Clubs", "Spades", "Hearts", "Diamonds"]
		# 14, 15, 16, 17. rauntlar için sabit kozlar
		settings.trump = trumps[current_round - 13] 
	else:
		settings.cards = 13
		settings.is_sanzoti = true # 18, 19, 20. rauntlar Sanzoti
		settings.trump = "None"

	return settings
	

func determine_winner():
	var settings = get_round_settings()
	var trump_suit = current_trump_suit
	var is_sanzoti = (current_trump_suit == "None")
	
	var best_card = null
	var winner_index = -1
	
	print("--- HAKEM KARAR ANI ---")
	print("Koz: ", trump_suit, " | Yerdeki Renk: ", lead_suit, " | Sanzoti mi?: ", is_sanzoti)

	for i in range(4):
		var card = get_card_from_slot(i)
		if card == null: 
			print("Slot ", i, " boş! Kart bulunamadı.")
			continue
		
		print("Slot ", i, " kontrol ediliyor: ", card.suit, " ", card.value)

		if best_card == null:
			best_card = card
			winner_index = i
			continue

		# --- MANTIK KONTROLÜ (GDD KURALLARI) ---
		var current_is_trump = (not is_sanzoti and card.suit == trump_suit)
		var best_is_trump = (not is_sanzoti and best_card.suit == trump_suit)

		# 1. DURUM: Yeni kart KOZ ve yerdeki lider KOZ değilse -> KOZ her zaman kazanır
		if current_is_trump and not best_is_trump:
			print("Yeni kart KOZ! Liderliği aldı.")
			best_card = card
			winner_index = i
		
		# 2. DURUM: İkisi de KOZ ise -> Büyük olan kazanır
		elif current_is_trump and best_is_trump:
			if card.value > best_card.value:
				print("Daha büyük bir KOZ geldi!")
				best_card = card
				winner_index = i
		
		# 3. DURUM: Koz yoksa ve yeni kart YERDEKİ RENK ise
		elif not best_is_trump and card.suit == lead_suit:
			# Eğer lider kart yerdeki renkten değilse VEYA yeni kartın değeri daha büyükse
			if best_card.suit != lead_suit or card.value > best_card.value:
				print("Aynı renkten daha büyük kart!")
				best_card = card
				winner_index = i

	if winner_index != -1:
		tricks_won[winner_index] += 1
		print("KAZANAN BELİRLENDİ: Oyuncu ", winner_index)
		return winner_index
	
	return 0 # Hata olursa oyuncuya ver
	
func calculate_scores():
	# 1. GÖRSEL BİLDİRİM (CardManager'da kalmalı)
	if tricks_won[0] == player_bids_before[0]:
		result_label.text = "ÇIKTIN!"
		result_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		result_label.text = "BATTIN!"
		result_label.add_theme_color_override("font_color", Color.RED)
	
	result_label.scale = Vector2(0, 0)
	result_label.pivot_offset = result_label.size / 2
	result_label.show()

	var tween = get_tree().create_tween()
	tween.tween_property(result_label, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_BOUNCE)
	
	# 2. PUANLAMA VE TABLOYA EKLEME (İşi uzmanına devrediyoruz)
	# Önceki kodundaki "for i in range(4)" döngüsünün yerini bu tek satır alıyor:
	if scoreboard_manager:
		scoreboard_manager.add_new_round_results(tricks_won, player_bids_before)
	
	# 3. ZAMANLAMA VE SIFIRLAMA (CardManager'da kalmalı)
	await get_tree().create_timer(1.5).timeout
	result_label.hide()
	
	tricks_won = [0, 0, 0, 0]
	

	

func check_hand_status():
	var full_slots = 0
	for slot in center_slots:
		if slot.card_in_slot:
			full_slots += 1
	
	# KURAL 1: Eğer ortada 4 kart varsa temizle
	if full_slots == 4:
		# Oyuncunun ne atıldığını görmesi için kısa bir bekleme
		await get_tree().create_timer(1.2).timeout 
		clear_table_cards()

func clear_table_cards():
	var winner_index = determine_winner()
	
	print("Bu eli kazanan oyuncu: ", winner_index)
	
	if winner_index == 0:
		update_score_display()
	current_turn = winner_index
	lead_suit = "" # Masadaki rengi sıfırla
	
	# --- HEDEF BELİRLEME (GÜNCELLENDİ) ---
	# Kartların 'ok gibi' gitmesi için hedefi ekranın dışına veya kenarına alıyoruz.
	var target_pos = Vector2.ZERO
	if winner_index == 0:
		# Oyuncuya (Ekranın en altı, dışarısı)
		target_pos = Vector2(screen_size.x / 2, screen_size.y + 500)
	elif winner_index == 1:
		# Bot 1 (Ekranın en solu, dışarısı)
		target_pos = Vector2(-500, screen_size.y / 2)
	elif winner_index == 2:
		# Bot 2 (Ekranın en üstü, dışarısı)
		target_pos = Vector2(screen_size.x / 2, -500)
	elif winner_index == 3:
		# Bot 3 (Ekranın en sağı, dışarısı)
		target_pos = Vector2(screen_size.x + 500, screen_size.y / 2)

	# Masadaki kartları topla
	var cards_to_clear = []
	for child in get_children():
		if child is Node2D and child != koz_kart_nesnesi and child.has_method("setup_appearance"):
			if not player_hand_referance.player_hand.has(child):
				cards_to_clear.append(child)

	# --- 'OK GİBİ' (MIKNATIS) ANİMASYONU ---
	var tween = get_tree().create_tween().set_parallel(true)
	
	for c in cards_to_clear:
		# 1. Aşırı Hızlı Hareket (0.2 saniye, TRANS_EXPO ile 'Vınn' etkisi)
		tween.tween_property(c, "global_position", target_pos, 0.3)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		
		# 2. Şekillerini Koruyacak Şekilde Ufak Küçülme (Ok ucu gibi)
		tween.tween_property(c, "scale", Vector2(0.4, 0.4), 0.2)
		
		# 3. Şeffaflaşmayı kaldırdık veya çok kısa tuttuk, böylece 'uçarken' net görünürler.
		# tween.tween_property(c, "modulate:a", 0.0, 0.2) # İstersen bunu açabilirsin.

	# Animasyonun bitmesini bekle
	await tween.finished
	
	# Kartları hafızadan sil (Ekran dışına çıktılar)
	for c in cards_to_clear:
		c.queue_free()
	
	for slot in center_slots:
		slot.card_in_slot = false
	
	# Tur/Raunt Sonu Kontrolü
	if player_hand_referance.player_hand.size() == 0:
		calculate_scores()
		await get_tree().create_timer(2.0).timeout
		next_round()
	elif current_turn != 0:
		await get_tree().create_timer(0.8).timeout
		start_bot_turn() # Kazanan bot ise yeni eli hemen o başlatsın
		
		
# GÜNCELLENMİŞ: Koz kartı artık desteden hedefine uçar
func create_koz_card(card_name, start_pos):
	var card_scene = preload("res://Scenes/Card.tscn")
	var new_koz = card_scene.instantiate()
	new_koz.card_id = card_name
	
	new_koz.name = card_name
	add_child(new_koz)
	new_koz.setup_appearance()
	koz_kart_nesnesi = new_koz
	new_koz.is_draggable = false
	
	if new_koz.has_node("Area2D/CollisionShape2D"):
		new_koz.get_node("Area2D/CollisionShape2D").disabled = true
	
	# --- ANİMASYON MANTIĞI ---
	# Önce desteye ışınla
	new_koz.global_position = start_pos
	new_koz.scale = Vector2(0.1, 0.1) # Küçük başlasın
	
	# Tween ile hedefe gönder
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(new_koz, "position", KOZ_POSITION, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(new_koz, "scale", Vector2(1.1, 1.1), 0.6)
	tween.tween_property(new_koz, "rotation_degrees", 360, 0.6) # Havalı dursun diye bir tur döner

	
	
func finish_round():
	current_round += 1
	start_new_round()
	
	
func connect_card_signals(card):
	card.connect("hovered", on_hovered_over_card)
	card.connect("hovered_off", on_hovered_off_card)
	
	
func on_hovered_over_card(card):
	if !is_hovering_on_card:
		is_hovering_on_card = true
		highlight_card(card, true)
		
func on_hovered_off_card(card):
	if !card_being_dragged:
		highlight_card(card, false)
		#check if hovered off card straight on to another card 
		var new_card_hovered = raycast_check_for_card()
		if new_card_hovered:
			highlight_card(new_card_hovered, true)
		else:
			is_hovering_on_card = false
	
	
func highlight_card(card, hovered):
	if hovered:
		card.scale = Vector2(1.05,1.05)
		card.z_index = 2
	else:
		card.scale = Vector2(1,1)
		card.z_index = 1
		
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = Vector2(clamp(mouse_pos.x,0,screen_size.x),clamp(mouse_pos.y,0,screen_size.y))


func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		pass

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Mouse tuşuna BASILDIĞI an (Click Down)
			var card = raycast_check_for_card()
			if card:
				start_drag(card)
		else:
			# Mouse tuşu BIRAKILDIĞI an (Click Up/Release)
			if card_being_dragged:
				finish_drag()
			
			
# CardManager.gd içindeki start_drag fonksiyonu
func start_drag(card):
	if current_turn != 0:
		return
	# Eğer kartın sürüklenebilir özelliği kapalıysa fonksiyonu burada bitir
	if not card.is_draggable:
		return
		
	card_being_dragged = card
	card.scale = Vector2(1, 1)

func next_round():
	current_round += 1
	lead_suit = ""
	tricks_won = [0, 0, 0, 0]
	start_new_round()
	
	
func finish_drag():
	if is_bidding_phase:
		player_hand_referance.update_hand_positions()
		return
	card_being_dragged.scale = Vector2(1.0, 1.0) 
	var card_slot_found = raycast_check_for_card_slot()
	if is_bidding_phase:
		return
	
	# 1. TEMEL KONTROL: Slot bulundu mu ve boş mu?
	if card_slot_found and card_slot_found.name == "CardSlot" and not card_slot_found.card_in_slot:
		
		# 2. RENK TAKİBİ (SUIT FOLLOWING)
		# Eğer yerdeki renk daha önce belirlendiyse (yani lead_suit boş değilse)
		if lead_suit != "":
			# Elimizde yerdeki renkten varsa VE biz başka renk atmaya çalışıyorsak:
			var elinde_lead_var = player_hand_referance.has_suit(lead_suit)
			
			if elinde_lead_var:
				# KURAL 1: Elinde yerdeki renkten varsa onu takip etmek zorunludur
				if card_being_dragged.suit != lead_suit:
					print("HATA: Yerdeki rengi (" + lead_suit + ") takip etmelisin!")
					player_hand_referance.add_card_to_hand(card_being_dragged)
					card_being_dragged = null
					return 
			elif current_trump_suit != "None" and player_hand_referance.has_suit(current_trump_suit):
				# KURAL 2: Yerdeki renk yok ama kozun varsa, başka renk atamazsın (Zorunlu Koz)
				if card_being_dragged.suit != current_trump_suit:
					print("HATA: Kozun varken sinek/kupa kaçamazsın! Koz çakmak zorundasın.")
					player_hand_referance.add_card_to_hand(card_being_dragged)
					card_being_dragged = null
					return
		
		# 3. KARTIN YERLEŞTİRİLMESİ
		player_hand_referance.remove_card_from_hand(card_being_dragged)
		
		# Tween ile veya direkt yerleştirme (global_position kullanmak daha garantidir)
		card_being_dragged.global_position = card_slot_found.global_position
		card_being_dragged.get_node("Area2D/CollisionShape2D").disabled = true
		card_slot_found.card_in_slot = true
		
		# 4. RENK KİLİTLEME: Eğer bu eli başlatan ilk kartsa rengi belirle
		if lead_suit == "":
			lead_suit = card_being_dragged.suit
			print("Yerdeki Renk KİLİTLENDİ (Oyuncu): ", lead_suit)
		
		# 5. SIRAYI GEÇ
		next_turn()
		
	else:
		# Slot bulunamadıysa veya yanlışsa ele geri döner
		player_hand_referance.add_card_to_hand(card_being_dragged)
		
	card_being_dragged = null
	
func is_first_card_on_table() -> bool:
	var count = 0
	for slot in center_slots:
		if slot.card_in_slot:
			count += 1
	# Eğer sadece 1 kart varsa (şu an atılan kart), o zaman bu ilk karttır.
	return count == 1
	
	
	
func next_turn():
	var full_slots = 0
	for slot in center_slots:
		if slot.card_in_slot:
			full_slots += 1 
			
	if full_slots == 4:
		# 4 kart dolduğunda clear_table_cards içindeki mantık devreye girer
		await check_hand_status() 
		return
		
	else:
		# Henüz 4 kart olmadıysa sıra bir sonrakine geçer
		current_turn = (current_turn + 3) % 4 
	
	# Sıra oyuncuda değilse botu başlat
	if current_turn != 0:
		start_bot_turn() 
		
func start_bot_turn():
	if is_bidding_phase or is_bot_playing:
		return
	is_bot_playing = true
	
	# Botun "düşünme" süresi (Daha doğal bir his için)
	await get_tree().create_timer(1.0).timeout 
	
	
	var slot_node = center_slots[current_turn]
	
	# El düğümünü bot indeksine göre alıyoruz. 
	var opponent_node = get_node_or_null("../OpponentHand" + str(current_turn))
	
	# Güvenlik Kontrolü: Düğümler sahnede yoksa hata vermesini ve oyunu durdurmasını engelleriz.
	if slot_node == null or (current_turn != 0 and opponent_node == null):
		push_error("HATA: Bot " + str(current_turn) + " için düğümler bulunamadı!")
		is_bot_playing = false
		next_turn()
		return

	# Zeki kart seçimi
	var card_to_play = select_card_for_bot(opponent_node)
	
	if card_to_play:
		# Reparenting (Kartı elden çıkarıp masaya (Manager'a) ekleme)
		var current_global_pos = card_to_play.global_position
		card_to_play.get_parent().remove_child(card_to_play)
		add_child(card_to_play)
		card_to_play.global_position = current_global_pos
		
		card_to_play.is_face_up = true
		card_to_play.setup_appearance()
		
		# --- RENK KİLİTLEME (LEAD SUIT) ---
		if lead_suit == "":
			lead_suit = card_to_play.suit
			print("Yerdeki Renk KİLİTLENDİ (Bot ", current_turn, "): ", lead_suit)
		
		# Slotun dolu olduğunu işaretle
		slot_node.card_in_slot = true
		
		# --- GÖRSEL AKICILIK: Animasyonu BEKLEME ---
		var tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(card_to_play, "global_position", slot_node.global_position, 0.4)\
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(card_to_play, "rotation_degrees", 0, 0.4)
		
		# KRİTİK: Animasyon bitmeden sırayı geçmiyoruz ki oyuncu ne olduğunu görsün.
		await tween.finished
		
		opponent_node.update_hand_positions()
		
		is_bot_playing = false
		next_turn() 
	else:
		# Botun atacak kartı yoksa (hata veya pas durumu)
		is_bot_playing = false
		next_turn()
		
# CardManager.gd

func select_card_for_bot(hand_node):
	var hand = hand_node.cards_in_hand
	if hand.size() == 0: return null
	
	# 1. KURAL: Eğer masaya İLK kartı bot atıyorsa (Lead) [cite: 121, 122]
	if is_first_card_on_table():
		# Strateji: Elindeki en büyük kartı veya rastgele birini seçebilir
		# Şimdilik rastgele birini seçip elinden çıkaralım
		var random_index = randi() % hand.size()
		var chosen_card = hand[random_index]
		hand.remove_at(random_index)
		return chosen_card

	# 2. KURAL: Renk Takibi (Suit Following) [cite: 258, 290]
	var matching_suit_cards = []
	for card in hand:
		if card.suit == lead_suit:
			matching_suit_cards.append(card)
	
	if matching_suit_cards.size() > 0:
		# Elinde yerdeki renkten varsa onu atmak ZORUNDA [cite: 259]
		var chosen = matching_suit_cards.pick_random()
		hand.erase(chosen)
		return chosen

	# 3. KURAL: Koz Çakma (Eğer Sanzoti değilse) [cite: 256, 261, 282]
	var settings = get_round_settings()
	if not settings.is_sanzoti:
		var trump_cards = []
		for card in hand:
			if card.suit == settings.trump:
				trump_cards.append(card)
		
		if trump_cards.size() > 0:
			# Elinde yerdeki renkten yoksa koz çakabilir [cite: 259]
			var chosen = trump_cards.pick_random()
			hand.erase(chosen)
			return chosen

	# 4. KURAL: Elinde ne renk ne koz varsa rastgele bir kart fırlat
	var random_index = randi() % hand.size()
	var chosen_card = hand[random_index]
	hand.remove_at(random_index)
	return chosen_card
		
		
func raycast_check_for_card_slot():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISON_MASK_CARD_SLOT
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null

func raycast_check_for_card():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISON_MASK_CARD
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return get_card_with_highest_z_index(result)
	return null
	
	
func get_card_with_highest_z_index(result):
	# İlk kartı en yüksek z_index'e sahipmiş gibi kabul ederek başlıyoruz
	var highest_z_card = result[0].collider.get_parent()
	var highest_z_index = highest_z_card.z_index
	
	# Listenin geri kalanını kontrol ediyoruz
	for i in range(1, result.size()):
		var current_card = result[i].collider.get_parent()
		if current_card.z_index > highest_z_index:
			highest_z_card = current_card
			highest_z_index = current_card.z_index
			
	
	return highest_z_card
	
func start_bidding_phase():
	is_bidding_phase = true
	bids_received = 0
	player_bids_before = [0, 0, 0, 0]
	
	# İhale, raundu başlatacak olan kişiden (current_turn) başlar
	current_bidder = current_turn 
	
	print("--- İHALE BAŞLADI ---")
	process_next_bid()

func process_next_bid():
	if bids_received == 4:
		# Herkes bittiğinde 1 saniye bekle ki oyuncu sonuçları görsün
		await get_tree().create_timer(1.0).timeout 
		finish_bidding_phase()
		return
		
	if current_bidder == 0:
		confirm_button.disabled = false # Oyuncunun basmasına izin ver
		show_bidding_ui() # UI zaten açık ama değerleri güncellemek için
	else:
		confirm_button.disabled = true # Botlar tahmin yaparken oyuncu basamasın
		bot_make_bid(current_bidder)

func show_bidding_ui():
	bidding_panel.show()
	# HATA ÇÖZÜMÜ: max_cards değişkenini burada tanımlıyoruz
	var max_cards = get_round_settings().cards
	
	for i in range(4):
		spin_boxes[i].max_value = max_cards
		# 3. indeks (VBoxContainer4 - Siz) dışındakileri kilitliyoruz
		spin_boxes[i].editable = (i == 3)
		
		# Eğer ilk defa açılıyorsa sıfırla
		if bids_received == 0: 
			spin_boxes[i].value = 0
			
func get_ui_index(bidder_id):
	if bidder_id == 0: return 3
	return bidder_id - 1        
	
func _on_bid_button_pressed(amount):
	bidding_panel.hide()
	player_bids_before[0] = amount
	advance_bidding()

func bot_make_bid(bot_index):
	await get_tree().create_timer(0.8).timeout # Bot "düşünüyor" hissi
	
	# 1. Botun el düğümüne ulaşalım
	var opponent_node = get_node_or_null("../OpponentHand" + str(bot_index))
	if opponent_node == null:
		advance_bidding()
		return

	var hand = opponent_node.cards_in_hand
	var bid = 0
	
	# --- AKILLI TAHMİN ANALİZİ ---
	for card in hand:
		var alabilir_mi = false
		
		# KURAL 1: Elindeki kart KOZ ise ve değeri 5'ten büyükse
		if card.suit == current_trump_suit and card.value > 5:
			alabilir_mi = true
		
		# KURAL 2: Kartın rengi ne olursa olsun VALE (11) veya daha büyükse
		# (Not: Vale=11, Kız=12, Papaz=13, As=14 kabul edilir)
		if card.value >= 11:
			alabilir_mi = true
			
		# Eğer kart bu iki kuraldan birine uyuyorsa tahmin sayısını artır
		if alabilir_mi:
			bid += 1
	
	# 2. Tahmini veritabanına kaydet
	player_bids_before[bot_index] = bid
	
	# 3. CANLI GÖSTERİM: Tablodaki ilgili kutucuğu güncelle
	# (Daha önce yaptığımız 0->3 indeks dönüştürücü fonksiyonunu kullanıyoruz)
	var ui_idx = get_ui_index(bot_index)
	spin_boxes[ui_idx].value = bid
	
	print("Bot ", bot_index, " elini analiz etti. Tahmini: ", bid)
	advance_bidding()

func advance_bidding():
	bids_received += 1
	# Saat yönünün tersi ilerleme (0 -> 1 -> 2 -> 3)
	current_bidder = (current_bidder + 1) % 4 
	process_next_bid()

func finish_bidding_phase():
	is_bidding_phase = false
	bidding_panel.hide()
	print("İHALE TAMAMLANDI: ", player_bids_before)
	
	if current_turn != 0:
		start_bot_turn()
	else:
		print("Sıra sende, kartını seç!")
	update_score_display()


func _on_confirm_button_pressed():
	# UI'daki 3. kutu (Siz) oyuncunun değeridir
	player_bids_before[0] = int(spin_boxes[3].value)
	
	# Özet metni de istersen güncelleyebilirsin (Görseldeki alt yazı)
	update_summary_label()
	
	advance_bidding()
	
func update_summary_label():
	# Görseldeki "Tahminler: Player1=..." kısmını günceller
	var text = "Tahminler: P1=%d | P2=%d | P3=%d | Siz=%d" % [
		spin_boxes[0].value, spin_boxes[1].value, 
		spin_boxes[2].value, spin_boxes[3].value
	]
	# summary_label referansın varsa buraya bas
func update_score_display():
	# player_bids[0] -> Senin tahminin
	# tricks_won[0]  -> Senin o raunt kazandığın el sayısı
	var text = "Hedef: %d\nAlınan: %d" % [player_bids_before[0], tricks_won[0]]
	score_status_label.text = text
	
	if tricks_won[0] == player_bids[0]:
		score_status_label.add_theme_color_override("font_color", Color.WHITE) # Hedef tuttu
	elif tricks_won[0] > player_bids[0]:
		score_status_label.add_theme_color_override("font_color", Color.WHITE)    # Hedef aşıldı
	else:
		score_status_label.add_theme_color_override("font_color", Color.WHITE)


func _on_score_board_toggle_pressed() -> void:
	if scoreboard_manager:
		# Görünürlüğü tersine çevir (Açıksa kapat, kapalıysa aç)
		scoreboard_manager.visible = !scoreboard_manager.visible
		print("Tablo durumu: ", scoreboard_manager.visible)
	else:
		print("Hata: scoreboard_manager düğümü bulunamadı!")
