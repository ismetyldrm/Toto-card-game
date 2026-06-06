extends Node2D

const COLLISON_MASK_CARD = 1
const COLLISON_MASK_CARD_SLOT = 2

var current_turn = 0 
var is_bot_playing = false
var hovered_card = null

var player_bids = [0, 0, 0, 0] # Her raunt başında alınan tahminler
var tricks_won = [0, 0, 0, 0]  # O raunt içinde kazanılan el sayısı
var lead_suit = ""             # Masaya atılan ilk kartın rengi
var current_trump_suit: String = "" # Raunt boyunca değişmeyecek gerçek koz

var card_being_dragged
var screen_size
var is_hovering_on_card
var player_hand_referance
var koltuklar = {}
var local_koltuk_no = 0
var mp_alinan = [0,0,0,0] # MP koltuk başına kazanılan el

var current_round = 1
const MAX_CARDS_PER_ROUND = 13
const TOTAL_ROUNDS = 20

var koz_kart_nesnesi = null
const KOZ_POSITION = Vector2(300,1600)
const KOZ_POSITION2 = Vector2(305,1630)
@onready var cay_sesi: AudioStreamPlayer = $"../Cay/AudioStreamPlayer"
@onready var round_label = $"../CanvasLayer/RoundLabel" 
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
@onready var bot_player_bids = [
	{"target": $"../OpponentHand1/VBoxContainer/TargetLabel", "current": $"../OpponentHand1/VBoxContainer/CurrentLabel"},
	{"target": $"../OpponentHand2/HBoxContainer/TargetLabel", "current": $"../OpponentHand2/HBoxContainer/CurrentLabel"},
	{"target": $"../OpponentHand3/VBoxContainer/TargetLabel", "current": $"../OpponentHand3/VBoxContainer/CurrentLabel"},
]
@onready var confirm_button = $"../BiddingPanel/VBoxContainer/ConfirmButton"
@onready var top_right_round_label = $"../CanvasLayer4/RoundLabel"

var player_bids_before = [0,0,0,0]
var bids_received = 0         # Kaç kişi tahmin yaptı?
var current_bidder = 0        # Şu an kim tahmin yapıyor?
var is_bidding_phase = false  # İhale süreci aktif mi
var bot_current_won_tricks = [0,0,0]
var bot_bids = [0,0,0]
var masadaki_kartlar = {}   # host: bu eldeki kartlar { koltuk: kart_id }
var sunucu_eller = {}       # host: kalan eller { koltuk: [kart_id,...] }
@export var koltuk_isim_etiketleri: Array[Label] = []

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
	

	if NetworkManager.game_mode == NetworkManager.GameMode.SINGLEPLAYER:
		start_new_round()   # ←—— MEVCUT TEK KİŞİLİK AKIŞ, HİÇ DEĞİŞMEDİ
	else:
		local_koltuk_no = NetworkManager.local_koltuk_no
		koltuklar = NetworkManager.koltuk_haritasi
		# Sahneye girdiğimi host'a bildir
		if multiplayer.is_server():
			NetworkManager.oyuncu_sahnede_hazir()   # host kendini doğrudan say
		else:
			NetworkManager.rpc_id(1, "oyuncu_sahnede_hazir")

func start_new_round():
	update_round_label()
	is_bidding_phase = true
	# 1. TEMİZLİK
	if is_instance_valid(koz_kart_nesnesi): 
		koz_kart_nesnesi.queue_free() 
	koz_kart_nesnesi = null 
	current_trump_suit = "" 

	var deck_node = get_node("../Deck")
	deck_node.create_deck() 
	var deck_start_pos = deck_node.global_position 
	
	var settings = get_round_settings()
	var card_count = settings.cards
	
	for p_index in range(4):
		var current_drawn_cards = []
		for i in range(card_count):
			var card = deck_node.draw_card()
			if card:
				current_drawn_cards.append(card)
		
		if p_index == 0:
			player_hand_referance.deal_new_hand(current_drawn_cards, deck_start_pos)
			for card_node in player_hand_referance.player_hand:
				if card_node.has_node("ShadowImage"):
					card_node.get_node("ShadowImage").visible = true
		   
		else:
			var opponent_path = "../OpponentHand" + str(p_index)
			if has_node(opponent_path):
				get_node(opponent_path).deal_hand(current_drawn_cards, deck_start_pos)
	
	# 5. KOZ BELİRLEME MANTIĞI
	if settings.is_sanzoti:
		current_trump_suit = "None"
		print("--- RAUNT BAŞLADI: SANZOTİ ---")
	elif current_round >= 13 && current_round <=16:
		current_trump_suit = settings.trump
		spawn_special_trump_indicator(current_trump_suit,deck_start_pos)
	else:
		var koz_ismi = deck_node.draw_card() 
		if koz_ismi: 
			var parts = koz_ismi.split("_")
			current_trump_suit = parts[0].capitalize() 
			create_koz_card(koz_ismi, deck_start_pos)

	
	current_turn = (3 + (current_round - 1) * 3) % 4
	is_bot_playing = false 
	
	await get_tree().create_timer(1.5).timeout 
	reset_bot_trackers()
	start_bidding_phase()
func update_round_label():
	if not top_right_round_label: return
	
	# Önce metni belirleyelim (if/elif/else yapısı ile sadece biri çalışır)
	if current_round == 13:
		top_right_round_label.text = "Raunt: Sinek / %d" % TOTAL_ROUNDS
	elif current_round == 14:
		top_right_round_label.text = "Raunt: Kupa / %d" % TOTAL_ROUNDS
	elif current_round == 15:
		top_right_round_label.text = "Raunt: Maça / %d" % TOTAL_ROUNDS
	elif current_round == 16:
		top_right_round_label.text = "Raunt: Karo / %d" % TOTAL_ROUNDS
	elif current_round >= 17:
		top_right_round_label.text = "Raunt: Sanzoti / %d" % TOTAL_ROUNDS # 17-19 için bonus
	else:
		# 1-12 arası normal sayı gösterimi
		top_right_round_label.text = "Raunt: %d / %d" % [current_round, TOTAL_ROUNDS]
	
	# Animasyon kısmı (Her zaman çalışabilir, sorun yok)
	var tween = get_tree().create_tween()
	top_right_round_label.pivot_offset = top_right_round_label.size / 2 
	tween.tween_property(top_right_round_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(top_right_round_label, "scale", Vector2(1.0, 1.0), 0.1)
		
		
		
	

func get_card_from_slot(index):
	var slot = center_slots[index]
	# CardManager'ın çocukları arasında, pozisyonu bu slotla aynı olan kartı bulur
	for child in get_children():
		if child is Node2D and child.has_method("setup_appearance"):
			if child.global_position.distance_to(slot.global_position) < 40:
				return child
	return null
	
func spawn_special_trump_indicator(suit_name, start_pos):
	# 1. Sahneyi oluştur
	var trump_scene = preload("res://Scenes/trump_card.tscn")
	var trump_instance = trump_scene.instantiate()
	add_child(trump_instance)
	koz_kart_nesnesi = trump_instance
	
	# 2. Görünürlük Ayarı
	for node_name in ["NoNumberClubs02", "NoNumberDiamonds02", "NoNumberHearts02", "NoNumberSpades02"]:
		if trump_instance.has_node(node_name):
			trump_instance.get_node(node_name).visible = false
	
	var target_node = "NoNumber" + suit_name + "02"
	if trump_instance.has_node(target_node):
		trump_instance.get_node(target_node).visible = true

	# 3. BAŞLANGIÇ DURUMU
	trump_instance.global_position = start_pos
	trump_instance.scale = Vector2(0.1, 0.1) # Pop-up etkisi için küçük başlasın
	trump_instance.rotation_degrees = 0
	
	# Destenin tam ölçeği (Senin belirlediğin değer)
	var deck_scale = Vector2(1, 1) 

	# 4. ANİMASYON (Birebir Eşitlenmiş)
	var tween = get_tree().create_tween().set_parallel(true)
	
	# Konum Animasyonu
	tween.tween_property(trump_instance, "global_position", KOZ_POSITION2, 0.6)\
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		
	# Ölçek Animasyonu (Hedef: deck_scale)
	tween.tween_property(trump_instance, "scale", deck_scale, 0.6)\
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		
	# Dönüş Animasyonu
	tween.tween_property(trump_instance, "rotation_degrees", 360, 0.6)\
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	
	
	
	
	

func get_round_settings():
	var settings = {"cards": 1, "trump": "Random", "is_sanzoti": false}
	
	if current_round <= 12: # 13'e kadar çıkabiliriz (52/4)
		settings.cards = current_round
		settings.trump = "Random" # Desteden çekilecek
	elif current_round <= 16:
		settings.cards = 13
		var trumps = ["Clubs", "Hearts", "Spades", "Diamonds"]
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
		var is_sanzoti = (current_trump_suit == "None")
		scoreboard_manager.add_new_round_results(tricks_won, player_bids_before, is_sanzoti)
	
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
		target_pos = Vector2(screen_size.x / 2, screen_size.y + 500)
	elif winner_index == 1:
		target_pos = Vector2(-500, screen_size.y / 2)
		add_trick_to_bot(winner_index)
	elif winner_index == 2:
		target_pos = Vector2(screen_size.x / 2, -500)
		add_trick_to_bot(winner_index)
	elif winner_index == 3:
		target_pos = Vector2(screen_size.x + 500, screen_size.y / 2)
		add_trick_to_bot(winner_index)

	# Masadaki kartları topla
	var cards_to_clear = []
	for child in get_children():
		if child is Node2D and child != koz_kart_nesnesi and child.has_method("setup_appearance"):
			if not player_hand_referance.player_hand.has(child):
				cards_to_clear.append(child)

	var tween = get_tree().create_tween().set_parallel(true)
	
	for c in cards_to_clear:
		# 1. Aşırı Hızlı Hareket (0.2 saniye, TRANS_EXPO ile 'Vınn' etkisi)
		tween.tween_property(c, "global_position", target_pos, 0.3)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		
		# 2. Şekillerini Koruyacak Şekilde Ufak Küçülme (Ok ucu gibi)
		tween.tween_property(c, "scale", Vector2(0.4, 0.4), 0.2)
		
		
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
	# Animasyonların birbirini beklemeden aynı anda çalışması için parallel tween oluşturuyoruz
	var tween = get_tree().create_tween().set_parallel(true)
	
	if hovered:
		# --- 1. ELASTİK BÜYÜME (Fotoğraftaki koddan alındı) ---
		# Anında büyümek yerine, TRANS_ELASTIC ile 0.4 saniyede jöle gibi titreyerek büyür
		tween.tween_property(card, "scale", Vector2(1.1, 1.1), 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		card.z_index = 99 
		hovered_card = card 
	else:
		# --- 2. ELASTİK KÜÇÜLME ---
		tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		# Orijinal derinliğine dön
		if card.has_meta("orijinal_z"):
			card.z_index = card.get_meta("orijinal_z")
		else:
			card.z_index = 1
			
		if card.has_node("ShadowImage"):
			tween.tween_property(card.get_node("ShadowImage"), "position", Vector2(0, 25), 0.15)
		
		
		if card.has_meta("start_rot"):
			tween.tween_property(card, "rotation_degrees", card.get_meta("start_rot"), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			tween.tween_property(card, "rotation_degrees", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		if hovered_card == card:
			hovered_card = null
	

func _process(delta: float) -> void:
	if card_being_dragged:
		# 1. Kartı farenin olduğu yere taşı
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x), clamp(mouse_pos.y, 0, screen_size.y))
		
		# Sürükleme sırasındaki Dinamik Esneme (Gölge) Mantığı
		if card_being_dragged.has_node("ShadowImage"):
			var shadow = card_being_dragged.get_node("ShadowImage")
			var base_shadow_pos = Vector2(0, 40) 
			var mouse_velocity = Input.get_last_mouse_velocity()
			var shadow_offset = -mouse_velocity * 0.015
			shadow_offset.x = clamp(shadow_offset.x, -40, 40)
			shadow_offset.y = clamp(shadow_offset.y, -40, 40)
			var target_pos = base_shadow_pos + shadow_offset
			shadow.position = shadow.position.lerp(target_pos, 15 * delta)
			
	else:
		if hovered_card and is_instance_valid(hovered_card):
			var local_mouse = hovered_card.get_local_mouse_position()
			
			# (Kartının genişliğine göre 100 sayısını ufaltıp büyütebilirsin)
			var tilt_x = clamp(local_mouse.x / 100.0, -1.0, 1.0)
			
			# 3. Y Ekseni Yatması: Farenin üstte mi altta mı olduğuna göre
			var tilt_y = clamp(local_mouse.y / 150.0, -1.0, 1.0)
			
			# Orijinal yelpaze açısını al ki kart garip bir açıda dönmesin
			var base_rot = 0.0
			if hovered_card.has_meta("start_rot"):
				base_rot = hovered_card.get_meta("start_rot")
				
			# Kartı farenin olduğu yöne doğru yatır (Örn: Maksimum 8 derece yatış)
			var target_rotation = base_rot + (tilt_x * 8.0)
			
			hovered_card.rotation_degrees = lerp(hovered_card.rotation_degrees, target_rotation, 15 * delta)
			
			if hovered_card.has_node("ShadowImage"):
				var shadow = hovered_card.get_node("ShadowImage")
				# Fare sağdaysa gölge sola, fare üstteyse gölge aşağıya kaçar (Fiziksel Derinlik)
				var shadow_target = Vector2(-tilt_x * 12, 25 - (tilt_y * 12))
				shadow.position = shadow.position.lerp(shadow_target, 15 * delta)


func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		toggle_opponent_cards()

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
			
func toggle_opponent_cards():
	for i in range(1,4):
		var hand_node = get_node_or_null("../OpponentHand" + str(i))
		if hand_node:
			for card in hand_node.cards_in_hand:
				card.is_face_up = !card.is_face_up
				card.setup_appearance()
# CardManager.gd içindeki start_drag fonksiyonu
func start_drag(card):
	if current_turn != local_koltuk_no:
		return
	# Eğer kartın sürüklenebilir özelliği kapalıysa fonksiyonu burada bitir
	if not card.is_draggable:
		return
		
	if card.has_node("ShadowImage"):
		# Kart havaya kalktığı için gölge daha uzağa düşüyor ve daha saydamlaşıyor
		var tween = create_tween().set_parallel(true)
		tween.tween_property(card.get_node("ShadowImage"), "modulate:a", 0.25, 0.15)

# CardManager.gd -> finish_drag veya masaya oturduğu an:
	if card.has_node("ShadowImage"):
		# Kart masaya indiği için gölge yaklaşıyor
		var tween = create_tween().set_parallel(true)
		tween.tween_property(card.get_node("ShadowImage"), "modulate:a", 0.4, 0.15)
		
	card_being_dragged = card
	card.scale = Vector2(1, 1)

func next_round():
	current_round += 1
	lead_suit = ""
	tricks_won = [0, 0, 0, 0]
	
	if current_round > TOTAL_ROUNDS:
		show_game_over_screen()
	else:
		start_new_round()
	
	
func finish_drag():
	if is_bidding_phase:
		player_hand_referance.update_hand_positions()
		card_being_dragged = null
		return
	if NetworkManager.game_mode == NetworkManager.GameMode.MULTIPLAYER:
		_mp_finish_drag()
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
				if card_being_dragged.suit.to_lower() != lead_suit.to_lower():
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
		
		player_hand_referance.remove_card_from_hand(card_being_dragged)
		
		card_being_dragged.global_position = card_slot_found.global_position
		card_being_dragged.rotation_degrees = 0
		card_being_dragged.get_node("Area2D/CollisionShape2D").disabled = true
		card_slot_found.card_in_slot = true
		
		if card_being_dragged.has_node("ShadowImage"):
			card_being_dragged.get_node("ShadowImage").visible = false

		
		if lead_suit == "":
			lead_suit = card_being_dragged.suit
			print("Yerdeki Renk KİLİTLENDİ (Oyuncu): ", lead_suit)
		
		next_turn()
		
	else:
		if card_being_dragged.has_node("ShadowImage"):
			var shadow = card_being_dragged.get_node("ShadowImage")
			var tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(shadow, "position", Vector2(0, 25), 0.15)
		player_hand_referance.add_card_to_hand(card_being_dragged)
		
	card_being_dragged = null
	
func is_first_card_on_table() -> bool:
	for slot in center_slots:
		if slot.card_in_slot:
			return false # Eğer tek bir slot bile doluysa, bu ilk kart değildir.
	return true # Hepsi boşsa ilk karttır.
	
	
	
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
	print("DEBUG: Yerdeki Renk: ", lead_suit, " | Botun Elindeki Bir Kartın Rengi: ", hand[0].suit)
	# 1. KURAL: Eğer masaya İLK kartı bot atıyorsa (Lead)
	if lead_suit == "":
		var chosen_card = hand.pick_random()
		hand.erase(chosen_card)
		return chosen_card
	if is_first_card_on_table():
		var random_index = randi() % hand.size()
		var chosen_card = hand[random_index]
		hand.remove_at(random_index)
		return chosen_card

	# 2. KURAL: Renk Takibi (Zorunlu)
	var matching_suit_cards = []
	for card in hand:
		if card.suit.to_lower() == lead_suit.to_lower():
			matching_suit_cards.append(card)
	
	if matching_suit_cards.size() > 0:
		var chosen = matching_suit_cards.pick_random()
		hand.erase(chosen)
		return chosen
		
	if current_trump_suit != "None" and current_trump_suit != "":
		var trump_cards = []
		for card in hand:
			if card.suit.to_lower() == current_trump_suit.to_lower():
				trump_cards.append(card)
		
		if trump_cards.size() > 0:
			print("Bot ", current_turn, " elinde yerdeki renk yok, KOZ çakıyor!")
			var chosen = trump_cards.pick_random()
			hand.erase(chosen)
			return chosen

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
		await get_tree().create_timer(0.5).timeout 
		finish_bidding_phase()
		return
		
	if current_bidder == 0:
		# Sadece oyuncu sırası geldiğinde düğmeyi aç ve paneli göster
		confirm_button.disabled = false
		show_bidding_ui()
	else:
		# Bot sırasındayken panelin kapalı ve düğmenin kilitli olduğundan emin ol
		confirm_button.disabled = true
		# bidding_panel.hide() # İsteğe bağlı: Botlar oynarken panel kapansın mı?
		bot_make_bid(current_bidder)

func show_bidding_ui():
	bidding_panel.show()
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
	await get_tree().create_timer(0.8).timeout 
	
	var opponent_node = get_node_or_null("../OpponentHand" + str(bot_index))
	if opponent_node == null:
		advance_bidding()
		return

	var hand = opponent_node.cards_in_hand
	var bid = 0
	
	# --- AKILLI TAHMİN ANALİZİ ---
	for card in hand:
		var alabilir_mi = false
		
		if card.suit == current_trump_suit and card.value > 5:
			alabilir_mi = true
		
		
		if card.value >= 11:
			alabilir_mi = true
			
		if alabilir_mi:
			bid += 1
	
	# 2. Tahmini veritabanına kaydet
	player_bids_before[bot_index] = bid
	
	var array_index = bot_index - 1
	if array_index >= 0 and array_index < bot_bids.size():
		bot_bids[array_index] = bid
	
	var ui_idx = get_ui_index(bot_index)
	if spin_boxes[ui_idx]:
		spin_boxes[ui_idx].value = bid
	
	print("Bot ", bot_index, " elini analiz etti. Tahmini: ", bid)
	advance_bidding()

func advance_bidding():
	bids_received += 1
	current_bidder = (current_bidder + 1) % 4 
	process_next_bid()

func finish_bidding_phase():
	is_bidding_phase = false
	bidding_panel.hide()
	print("İHALE TAMAMLANDI: ", player_bids_before)
	
	show_all_biddings_on_table()
	
	if current_turn != 0:
		start_bot_turn()
	else:
		print("Sıra sende, kartını seç!")
	update_score_display()
	
func show_all_biddings_on_table():
	for i in range(3):
		var bid_value = bot_bids[i]
		var target_label = bot_player_bids[i]["target"]
		if target_label:
			target_label.text = "HEDEF: " + str(bid_value)


func _on_confirm_button_pressed():
	if NetworkManager.game_mode == NetworkManager.GameMode.MULTIPLAYER:
		_mp_on_confirm_pressed()
		return
	
	if not is_bidding_phase or current_bidder != 0 or confirm_button.disabled:
		return
	
	confirm_button.disabled = true
	
	player_bids_before[0] = int(spin_boxes[3].value)
	
	update_summary_label()
	advance_bidding()
	
func _mp_on_confirm_pressed():
	if current_bidder != local_koltuk_no or confirm_button.disabled:
		return
	confirm_button.disabled = true
	var idx = _seat_to_spin_index(local_koltuk_no)
	spin_boxes[idx].editable = false
	var bid = int(spin_boxes[idx].value)
	if multiplayer.is_server():
		_mp_submit_bid(bid)
	else:
		rpc_id(1, "_mp_submit_bid", bid)

func update_summary_label():
	var text = "Tahminler: P1=%d | P2=%d | P3=%d | Siz=%d" % [
		spin_boxes[0].value, spin_boxes[1].value, 
		spin_boxes[2].value, spin_boxes[3].value
	]
func update_score_display():
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


func _on_cay_pressed():
	print("Butona basıldı")
	if cay_sesi:
		cay_sesi.play()
		
func update_bot_bid_ui(bot_index: int, bid_value: int):
	var array_index = bot_index - 1
	
	if array_index >= 0 and array_index < bot_bids.size():
		bot_bids[array_index] = bid_value
		
		var target_label = bot_player_bids[array_index]["target"]
		if target_label:
			target_label.text = "HEDEF: " + str(bid_value)

func add_trick_to_bot(bot_index: int):
	var array_index = bot_index - 1
	
	if array_index >= 0 and array_index < bot_current_won_tricks.size():
		bot_current_won_tricks[array_index] += 1
		
		var current_label = bot_player_bids[array_index]["current"]
		if current_label:
			current_label.text = "ALINAN: " + str(bot_current_won_tricks[array_index])
			
func reset_bot_trackers():
	bot_bids = [0, 0, 0]
	bot_current_won_tricks = [0, 0, 0]
	
	for i in range(3):
		if bot_player_bids[i]["target"] and bot_player_bids[i]["current"]:
			bot_player_bids[i]["target"].text = "HEDEF: 0"
			bot_player_bids[i]["current"].text = "ALINAN: 0"
# Mutlak koltuğu, yerel oyuncuya göre görsel el düğümüne çevirir
func _koltuk_to_el_node(mutlak_koltuk: int) -> Node:
	var relative = (mutlak_koltuk - local_koltuk_no + 4) % 4
	match relative:
		0: return player_hand_referance         # ben → alt
		1: return get_node("../OpponentHand1")   # sol
		2: return get_node("../OpponentHand2")   # üst
		3: return get_node("../OpponentHand3")   # sağ
	return null

# SADECE host çalıştırır: desteyi kurar, dağıtır, herkese yollar
func _mp_oyunu_baslat():
	masadaki_kartlar.clear()
	lead_suit = ""
	var deck_node = get_node("../Deck")
	deck_node.create_deck()
	var settings = get_round_settings()
	var card_count = settings.cards

	# 4 koltuğa kart dağıt
	var eller := {}
	
	for koltuk in range(4):
		var kartlar := []
		for i in range(card_count):
			var c = deck_node.draw_card()
			if c: kartlar.append(c)
		eller[koltuk] = kartlar
	sunucu_eller = eller.duplicate(true) 

	# Koz belirle (1. raunt normal koz çeker)
	var koz_id := ""
	var koz_suit := ""
	if settings.is_sanzoti:
		koz_suit = "None"
	elif current_round >= 13 and current_round <= 16:
		koz_suit = settings.trump
	else:
		koz_id = deck_node.draw_card()
		if koz_id:
			koz_suit = koz_id.split("_")[0].capitalize()

	# Başlangıç koltuğu (single player'daki formülün aynısı)
	var baslangic = (3 + (current_round - 1) * 3) % 4

	# Herkesin kaç kartı var bilgisi
	var sayilar := {}
	for k in range(4):
		sayilar[k] = eller[k].size()

	# Her oyuncuya KENDİ kartlarını yolla (başkasının kartını göndermiyoruz)
	for peer_id in koltuklar.keys():
		var hedef_koltuk = koltuklar[peer_id]
		var o_kisinin_kartlari = eller[hedef_koltuk]
		if peer_id == multiplayer.get_unique_id():
			_mp_elini_dagit(o_kisinin_kartlari, sayilar, koz_id, koz_suit, baslangic, current_round)
		else:
			rpc_id(peer_id, "_mp_elini_dagit", o_kisinin_kartlari, sayilar, koz_id, koz_suit, baslangic, current_round)
	_mp_start_bidding(baslangic)

func _mp_start_bidding(baslangic: int):
	current_bidder = baslangic
	bids_received = 0
	player_bids_before = [0, 0, 0, 0]
	var max_cards = get_round_settings().cards
	rpc("_mp_bidding_start", max_cards, baslangic)  # panel herkeste açılsın
	_mp_bidding_next()
	
# İhale başında herkeste paneli açar, tüm kutuları sıfırlar ve kilitler
@rpc("authority", "call_local", "reliable")
func _mp_bidding_start(max_cards: int, baslangic: int):
	is_bidding_phase = true
	current_bidder = baslangic
	bidding_panel.show()
	for i in range(4):
		spin_boxes[i].max_value = max_cards
		spin_boxes[i].value = 0
		spin_boxes[i].editable = false
	confirm_button.disabled = true

# SADECE host: sıradaki tahmin sahibine geç ya da bitir
func _mp_bidding_next():
	if bids_received >= 4:
		rpc("_mp_bidding_finished")
		return
	rpc("_mp_bidding_turn", current_bidder)

# Client tahminini host'a yollar; host doğrular ve kaydeder
@rpc("any_peer", "reliable")
func _mp_submit_bid(bid: int):
	if not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1  # host kendi yerel çağrısı
	# Gönderen gerçekten sıradaki tahmin sahibi mi?
	if koltuklar.get(sender, -1) != current_bidder:
		print("Sıra dışı tahmin reddedildi: ", sender)
		return
	player_bids_before[current_bidder] = bid
	rpc("_mp_show_bid", current_bidder, bid)
	bids_received += 1
	current_bidder = (current_bidder + 1) % 4
	_mp_bidding_next()

# Sıra kimdeyse onun panelini açar, diğerlerinde kapatır
@rpc("authority", "call_local", "reliable")
func _mp_bidding_turn(bidder_seat: int):
	current_bidder = bidder_seat
	var benim_idx = _seat_to_spin_index(local_koltuk_no)
	if bidder_seat == local_koltuk_no:
		spin_boxes[benim_idx].editable = true
		confirm_button.disabled = false
		bidding_label.text = "Tahminini gir"
	else:
		spin_boxes[benim_idx].editable = false
		confirm_button.disabled = true

@rpc("authority", "call_local", "reliable")
func _mp_show_bid(seat: int, bid: int):
	player_bids_before[seat] = bid   # herkes kaydetsin (skor için)
	var idx = _seat_to_spin_index(seat)
	spin_boxes[idx].value = bid
	if seat == local_koltuk_no:
		score_status_label.text = "Hedef: %d\nAlınan: %d" % [bid, mp_alinan[local_koltuk_no]]
	else:
		var node = _koltuk_to_el_node(seat)
		var lbl = _find_label(node, "TargetLabel")
		if lbl:
			lbl.text = "HEDEF: " + str(bid)

@rpc("authority", "call_local", "reliable")
func _mp_bidding_finished():
	is_bidding_phase = false
	bidding_panel.hide()
	_mp_sira_goster()
	print("İHALE TAMAMLANDI (MP): ", player_bids_before)
	# Sıradaki adım: kart atma fazı (henüz bağlanmadı)

# Düğüm ağacında isme göre Label arar (opponent hand'lerin yapısı farklı olduğu için)
func _find_label(node, label_name: String):
	if node == null:
		return null
	if node.name == label_name and node is Label:
		return node
	for child in node.get_children():
		var r = _find_label(child, label_name)
		if r:
			return r
	return null
	
# Bir koltuğu, yerel oyuncuya göre spin kutusu index'ine çevirir (kendi kutun = 3)
func _seat_to_spin_index(seat: int) -> int:
	var relative = (seat - local_koltuk_no + 4) % 4
	return 3 if relative == 0 else relative - 1

func _sira_metni(seat: int) -> String:
	if seat == local_koltuk_no:
		return "Sıra sende! Tahminini gir."
	var relative = (seat - local_koltuk_no + 4) % 4
	var yon = ""
	match relative:
		1: yon = "Soldaki"
		2: yon = "Karşıdaki"
		3: yon = "Sağdaki"
	return yon + " oyuncu tahmin ediyor..."
	

# Her client'ta çalışır: kendi elini açık, diğerlerini kapalı dizer
@rpc("authority", "reliable")
func _mp_elini_dagit(benim_kartlar: Array, sayilar: Dictionary, koz_id: String, koz_suit: String, baslangic: int, raunt: int):
	current_round = raunt
	update_round_label()

	# Eski raunttan kalanları temizle
	if is_instance_valid(koz_kart_nesnesi):
		koz_kart_nesnesi.queue_free()
	koz_kart_nesnesi = null
	mp_alinan = [0, 0, 0, 0]
	player_bids_before = [0, 0, 0, 0]
	_mp_skor_etiketleri_sifirla()

	var deck_node = get_node("../Deck")
	var deck_start_pos = deck_node.global_position
	current_trump_suit = koz_suit
	current_turn = baslangic
	is_bidding_phase = true

	player_hand_referance.deal_new_hand(benim_kartlar, deck_start_pos)
	for card_node in player_hand_referance.player_hand:
		if card_node.has_node("ShadowImage"):
			card_node.get_node("ShadowImage").visible = true
		
			
	for k in range(4):
		if k == local_koltuk_no:
			continue
		var hand_node = _koltuk_to_el_node(k)
		if hand_node:
			var sahte := []
			for i in range(sayilar[k]):
				sahte.append("clubs_02")
			hand_node.deal_hand(sahte, deck_start_pos)

	# Koz görseli (raunt tipine göre)
	if koz_suit == "None":
		pass  # sanzoti, koz yok
	elif koz_id == "":
		spawn_special_trump_indicator(koz_suit, deck_start_pos)  # 13-16 sabit koz
	else:
		create_koz_card(koz_id, deck_start_pos)

	_mp_isimleri_uygula()
	_mp_sira_goster()
		
func _mp_isimleri_uygula():
	var isimler = NetworkManager.koltuk_isimleri

	# İhale panelindeki sütun isimleri (kendi sütunun en sağda)
	for seat in range(4):
		var idx = _seat_to_spin_index(seat)
		var kutu = spin_boxes[idx]
		if kutu and kutu.get_parent():
			var lbl = _ilk_label_bul(kutu.get_parent())
			if lbl:
				lbl.text = str(isimler.get(seat, "Oyuncu"))
	# Masadaki (orta) oyuncu isim etiketleri — sadece 3 rakip
	
	for seat in range(4):
		var relative = (seat - local_koltuk_no + 4) % 4
		if relative == 0:
			continue   # kendim → ortada etiketim yok (alttayım)
		var idx = relative - 1   # relative 1→0 (sol), 2→1 (üst), 3→2 (sağ)
		if idx < koltuk_isim_etiketleri.size() and koltuk_isim_etiketleri[idx]:
			koltuk_isim_etiketleri[idx].text = str(isimler.get(seat, "Oyuncu"))
			
	# Skor tablosu: yerel oyuncu hep son sütunda ("Siz") olacak şekilde göreli sıra
	if scoreboard_manager and scoreboard_manager.has_method("set_player_names"):
		var sira = [
			(local_koltuk_no + 1) % 4,
			(local_koltuk_no + 2) % 4,
			(local_koltuk_no + 3) % 4,
			local_koltuk_no
		]
		scoreboard_manager.ui_order = sira
		var isim_sirali := []
		for s in sira:
			isim_sirali.append(str(isimler.get(s, "Oyuncu")))
		scoreboard_manager.set_player_names(isim_sirali)

func _ilk_label_bul(node):
	for child in node.get_children():
		if child is Label:
			return child
	return null
	
func _mp_finish_drag():
	if card_being_dragged == null:
		return
	var card = card_being_dragged
	card_being_dragged = null
	card.scale = Vector2(1.0, 1.0)
	var slot = raycast_check_for_card_slot()
	var gecerli = current_turn == local_koltuk_no \
		and slot != null and slot.name == "CardSlot" and not slot.card_in_slot \
		and _mp_kart_gecerli_mi(card)
	if gecerli:
		if multiplayer.is_server():
			_mp_kart_at(card.card_id)        # host doğrudan çağırsın
		else:
			rpc_id(1, "_mp_kart_at", card.card_id)
	else:
		if card.has_node("ShadowImage"):
			var shadow = card.get_node("ShadowImage")
			var tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(shadow, "position", Vector2(0, 25), 0.15)
		player_hand_referance.update_hand_positions() 

func _mp_kart_gecerli_mi(card) -> bool:
	if lead_suit == "":
		return true
	if player_hand_referance.has_suit(lead_suit):
		return card.suit.to_lower() == lead_suit.to_lower()
	if current_trump_suit != "None" and player_hand_referance.has_suit(current_trump_suit):
		return card.suit == current_trump_suit
	return true

# Client kartı host'a yollar; host doğrular, herkese yayınlar
@rpc("any_peer", "reliable")
func _mp_kart_at(card_id: String):
	if not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	var seat = koltuklar.get(sender, -1)
	if seat != current_turn:
		return
	var el = sunucu_eller.get(seat, [])
	if not (card_id in el):
		print("Elinde olmayan kart reddedildi.")
		return
	el.erase(card_id)

	if lead_suit == "":
		lead_suit = card_id.split("_")[0].capitalize()
	masadaki_kartlar[seat] = card_id
	rpc("_mp_kart_oynandi", seat, card_id)   # görsel yerleştirme

	if masadaki_kartlar.size() >= 4:
		_mp_el_sonlandir()
	else:
		current_turn = (current_turn + 3) % 4
		rpc("_mp_sira_guncelle", current_turn)

# Herkeste: kartı doğru slota yerleştir
@rpc("authority", "call_local", "reliable")
func _mp_kart_oynandi(seat: int, card_id: String):
	if lead_suit == "":
		lead_suit = card_id.split("_")[0].capitalize()
	var slot = _koltuk_to_slot(seat)
	if slot == null:
		return
	var kart_node = null
	if seat == local_koltuk_no:
		kart_node = _eldan_kart_bul(player_hand_referance.player_hand, card_id)
		if kart_node:
			player_hand_referance.remove_card_from_hand(kart_node)
	else:
		var hand_node = _koltuk_to_el_node(seat)
		var bas_pos = slot.global_position
		if hand_node and hand_node.cards_in_hand.size() > 0:
			var sahte = hand_node.cards_in_hand.pop_back()
			if is_instance_valid(sahte):
				bas_pos = sahte.global_position
				sahte.queue_free()
			hand_node.update_hand_positions()
		kart_node = _kart_olustur(card_id)
		kart_node.global_position = bas_pos
	if kart_node == null:
		return
	kart_node.is_face_up = true
	kart_node.is_draggable = false
	kart_node.setup_appearance()
	if kart_node.has_node("Area2D/CollisionShape2D"):
		kart_node.get_node("Area2D/CollisionShape2D").disabled = true
	slot.card_in_slot = true
	
	if kart_node.has_node("ShadowImage"):
		kart_node.get_node("ShadowImage").visible = false
	
	if seat == local_koltuk_no:
		# Single player'daki gibi: kendi kartım ANINDA oturur (tween yok, rotation'a dokunma)
		kart_node.scale = Vector2(1.0, 1.0)
		kart_node.global_position = slot.global_position
	
	else:
		var tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(kart_node, "global_position", slot.global_position, 0.4)\
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(kart_node, "rotation_degrees", 0, 0.4)

@rpc("authority", "call_local", "reliable")
func _mp_sira_guncelle(yeni_sira: int):
	current_turn = yeni_sira
	_mp_sira_goster()

# Sırası gelen oyuncunun elini parlatır, diğerlerini soluklaştırır
func _mp_sira_goster():
	for seat in range(4):
		var hand_node = _koltuk_to_el_node(seat)
		if hand_node == null:
			continue
		if is_bidding_phase:
			hand_node.modulate = Color(1, 1, 1, 1)          # ihalede hepsi normal
		elif seat == current_turn:
			hand_node.modulate = Color(1, 1, 1, 1)          # sıradaki: parlak
		else:
			hand_node.modulate = Color(0.55, 0.55, 0.55, 1) # diğerleri: soluk

# SADECE host: 4 kart dolunca kazananı bul, süpür, sırayı kazanana ver
func _mp_el_sonlandir():
	var kazanan = _mp_kazanani_belirle()
	tricks_won[kazanan] += 1
	rpc("_mp_el_temizle", kazanan)
	masadaki_kartlar.clear()
	lead_suit = ""
	current_turn = kazanan
	rpc("_mp_sira_guncelle", current_turn)
	# Round bitti mi? (eller boşaldıysa) → SONRAKİ ADIM: skor + yeni raunt
	if sunucu_eller.get(kazanan, []).size() == 0:
		_mp_raunt_bitti()

func _mp_kazanani_belirle() -> int:
	var trump = current_trump_suit
	var is_sanzoti = (trump == "None")
	var best_seat = -1
	var best_suit = ""
	var best_value = -1
	for seat in masadaki_kartlar.keys():
		var parts = masadaki_kartlar[seat].split("_")
		var suit = parts[0].capitalize()
		var value = _kart_degeri(parts[1])
		if best_seat == -1:
			best_seat = seat; best_suit = suit; best_value = value
			continue
		var cur_trump = (not is_sanzoti and suit == trump)
		var best_trump = (not is_sanzoti and best_suit == trump)
		if cur_trump and not best_trump:
			best_seat = seat; best_suit = suit; best_value = value
		elif cur_trump and best_trump:
			if value > best_value:
				best_seat = seat; best_suit = suit; best_value = value
		elif not best_trump and suit == lead_suit:
			if best_suit != lead_suit or value > best_value:
				best_seat = seat; best_suit = suit; best_value = value
	return best_seat

func _kart_degeri(val_str: String) -> int:
	match val_str:
		"ace": return 14
		"king": return 13
		"queen": return 12
		"jack": return 11
		_: return val_str.to_int()

# Herkeste: masadaki kartları kazanana doğru süpür
@rpc("authority", "call_local", "reliable")
func _mp_el_temizle(kazanan_seat: int):
	mp_alinan[kazanan_seat] += 1
	_mp_alinan_goster(kazanan_seat)
	var relative = (kazanan_seat - local_koltuk_no + 4) % 4
	var target_pos = Vector2.ZERO
	match relative:
		0: target_pos = Vector2(screen_size.x / 2, screen_size.y + 500)
		1: target_pos = Vector2(-500, screen_size.y / 2)
		2: target_pos = Vector2(screen_size.x / 2, -500)
		3: target_pos = Vector2(screen_size.x + 500, screen_size.y / 2)
	var cards_to_clear = []
	for child in get_children():
		if child is Node2D and child != koz_kart_nesnesi and child.has_method("setup_appearance"):
			if not player_hand_referance.player_hand.has(child):
				cards_to_clear.append(child)
	await get_tree().create_timer(1.2).timeout
	var tween = get_tree().create_tween().set_parallel(true)
	for c in cards_to_clear:
		tween.tween_property(c, "global_position", target_pos, 0.3)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.tween_property(c, "scale", Vector2(0.4, 0.4), 0.2)
	await tween.finished
	for c in cards_to_clear:
		c.queue_free()
	for slot in center_slots:
		slot.card_in_slot = false
	lead_suit = ""

# Yardımcılar
func _koltuk_to_slot(seat: int) -> Node:
	var relative = (seat - local_koltuk_no + 4) % 4
	return center_slots[relative]

func _eldan_kart_bul(hand_array: Array, card_id: String):
	for c in hand_array:
		if is_instance_valid(c) and c.card_id == card_id:
			return c
	return null

func _kart_olustur(card_id: String):
	var card_scene = preload("res://Scenes/Card.tscn")
	var c = card_scene.instantiate()
	c.card_id = card_id
	add_child(c)
	c.is_face_up = true
	c.setup_appearance()
	return c
	
# SADECE host: raunt sonu skorları yolla, sonra yeni rauntu başlat
func _mp_raunt_bitti():
	await get_tree().create_timer(1.5).timeout   # son el süpürülsün
	rpc("_mp_skor_goster", tricks_won.duplicate(), player_bids_before.duplicate())
	await get_tree().create_timer(3.0).timeout   # skor görünsün

	current_round += 1
	if current_round > TOTAL_ROUNDS:
		rpc("_mp_oyun_bitti")
		return
	tricks_won = [0, 0, 0, 0]
	_mp_oyunu_baslat()   # yeni rauntu dağıt

# Herkeste: ÇIKTIN/BATTIN + skor tablosuna ekle
@rpc("authority", "call_local", "reliable")
func _mp_skor_goster(final_tricks: Array, final_bids: Array):
	var alinan = final_tricks[local_koltuk_no]
	var hedef = final_bids[local_koltuk_no]
	if alinan == hedef:
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

	if scoreboard_manager:
		var is_sanzoti = (current_trump_suit == "None")
		scoreboard_manager.add_new_round_results(final_tricks, final_bids, is_sanzoti)

	await get_tree().create_timer(2.0).timeout
	result_label.hide()

@rpc("authority", "call_local", "reliable")
func _mp_oyun_bitti():
	is_bidding_phase = true   # girişi kilitle
	result_label.text = "OYUN BİTTİ!"
	result_label.add_theme_color_override("font_color", Color.WHITE)
	result_label.scale = Vector2(1, 1)
	result_label.position = Vector2(1295,416)
	result_label.show()
	
	await get_tree().create_timer(2.0).timeout
	result_label.hide()
	show_game_over_screen()

func _mp_alinan_goster(seat: int):
	if seat == local_koltuk_no:
		score_status_label.text = "Hedef: %d\nAlınan: %d" % [player_bids_before[local_koltuk_no], mp_alinan[local_koltuk_no]]
	else:
		var node = _koltuk_to_el_node(seat)
		var lbl = _find_label(node, "CurrentLabel")
		if lbl:
			lbl.text = "ALINAN: " + str(mp_alinan[seat])

func _mp_skor_etiketleri_sifirla():
	score_status_label.text = "Hedef: 0\nAlınan: 0"
	for seat in range(4):
		if seat == local_koltuk_no:
			continue
		var node = _koltuk_to_el_node(seat)
		var t = _find_label(node, "TargetLabel")
		var c = _find_label(node, "CurrentLabel")
		if t: t.text = "HEDEF: 0"
		if c: c.text = "ALINAN: 0"
		
func show_game_over_screen():
	# main.tscn altındaki hazır GameOverScreen düğümünü buluyoruz
	var game_over_screen = get_node("../GameOverScreen") 
	
	# Puanları Scoreboard'dan Çek
	var raw_scores = scoreboard_manager.total_scores 
	var is_mp = (NetworkManager.game_mode == NetworkManager.GameMode.MULTIPLAYER)
	
	var scores = []
	var isimler = []
	
	for i in scoreboard_manager.ui_order:
		scores.append(raw_scores[i])
		
		if is_mp:
			isimler.append(NetworkManager.koltuk_isimleri.get(i, "Oyuncu"))
		else:
			if i == 0:
				isimler.append("Siz")
			else:
				isimler.append("Player " + str(i))

	game_over_screen.setup_results(scores, isimler, is_mp)
