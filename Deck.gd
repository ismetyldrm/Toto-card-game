extends Node2D

var player_deck = []

func _ready() -> void:
	randomize()
	create_deck()

# Deck.gd

func create_deck():
	player_deck.clear() 
	var suits = ["clubs", "diamonds", "hearts", "spades"] 
	# Resimli kartlara 'ace'i de ekledik 
	var face_cards = ["ace", "jack", "queen", "king"] 
	
	for suit in suits:
		# 1. 02'den 09'a kadar olan sayılar (Başına 0 ekleyerek) 
		for i in range(2, 10):
			player_deck.append(suit + "_0" + str(i)) 
		
		# 2. 10 numaralı kart (Başına 0 gelmiyor) 
		player_deck.append(suit + "_10") 
		
		# 3. Resimli kartlar (ace, jack, queen, king) 
		for face in face_cards:
			player_deck.append(suit + "_" + face) 
			
	player_deck.shuffle()

func draw_card():
	if player_deck.size() > 0:
		# pop_back() hem kartın adını döndürür hem de onu player_deck'ten SİLER.
		return player_deck.pop_back()
	else:
		print("Deste bitti!")
		return null
