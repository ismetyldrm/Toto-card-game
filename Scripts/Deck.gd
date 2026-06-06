extends Node2D

var player_deck = []

func _ready() -> void:
	randomize()
	create_deck()


func create_deck():
	player_deck.clear() 
	var suits = ["clubs", "diamonds", "hearts", "spades"] 
	var face_cards = ["ace", "jack", "queen", "king"] 
	
	for suit in suits:
		for i in range(2, 10):
			player_deck.append(suit + "_0" + str(i)) 
		
		player_deck.append(suit + "_10") 
		
		for face in face_cards:
			player_deck.append(suit + "_" + face) 
			
	player_deck.shuffle()

func draw_card():
	if player_deck.size() > 0:
		return player_deck.pop_back()
	else:
		print("Deste bitti!")
		return null
