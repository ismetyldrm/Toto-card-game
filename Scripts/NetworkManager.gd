extends Node

const DEFAULT_PORT = 12345
const MAX_PLAYERS = 4
const GAME_SCENE = "res://Scenes/main.tscn"

const BROADCAST_PORT = 12346 # Odaları aramak için kullanılacak bağımsız port
const BROADCAST_INTERVAL = 1.0 # 1 saniyede bir "Oda Açık" sinyali gönder

var udp_server: PacketPeerUDP # Oda açanın yayın yapması için
var udp_client: PacketPeerUDP # Oda arayanın dinlemesi için
var broadcast_timer: Timer
var _current_room_name := ""
enum GameMode { SINGLEPLAYER, MULTIPLAYER }
var game_mode: GameMode = GameMode.SINGLEPLAYER
var koltuk_haritasi := {}   # { peer_id: koltuk_no }
var local_koltuk_no := 0
var _game_started := false
var _hazir_oyuncu_sayisi := 0
var local_player_name := "Oyuncu"
var koltuk_isimleri := {}    # { koltuk_no: isim }  → oyun sahnesinde kullanılır
var _peer_isimleri := {}     # host'ta geçici: { peer_id: isim }


var active_rooms = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

	# YENİ: Sunucu (oda sahibi) bağlantıyı kapatınca client'larda otomatik tetiklenir
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_server_disconnected)

	udp_client = PacketPeerUDP.new()

func _process(_delta: float) -> void:
	if udp_client and udp_client.is_bound():
		_listen_for_rooms()          # arayan: gelen cevapları topla
	if udp_server and udp_server.is_bound():
		_answer_discovery_requests() # host: gelen istekleri cevapla


func create_room(room_name: String) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	
	if error != OK:
		return false
		
	multiplayer.multiplayer_peer = peer
	
	_start_broadcasting(room_name)
	return true

func _start_broadcasting(room_name: String):
	_stop_udp()
	_current_room_name = room_name

	udp_server = PacketPeerUDP.new()
	udp_server.set_broadcast_enabled(true)
	var err = udp_server.bind(BROADCAST_PORT, "*")  # host sabit portu dinler
	if err != OK:
		print("Host keşif portuna bağlanamadı: ", err)
	else:
		print("Host keşif isteklerini dinliyor.")

func _answer_discovery_requests():
	while udp_server.get_available_packet_count() > 0:
		var packet = udp_server.get_packet()
		var sender_ip = udp_server.get_packet_ip()
		var sender_port = udp_server.get_packet_port()

		if packet.get_string_from_utf8() == "DISCOVER_ROOMS":
			var reply = {
				"room_name": _current_room_name,
				"player_count": str(multiplayer.get_peers().size() + 1) + " / " + str(MAX_PLAYERS)
			}
			# Cevabı doğrudan isteyene gönder (unicast)
			udp_server.set_dest_address(sender_ip, sender_port)
			udp_server.put_packet(JSON.stringify(reply).to_utf8_buffer())

var _returning_to_menu := false  # çift tetiklenmeyi engelleyen kilit

# --- Oda sahibi iptale basınca burası çağrılır ---
func host_close_room():
	if multiplayer.multiplayer_peer and multiplayer.is_server():
		# Önce client'lara haber ver
		rpc("force_everyone_to_main_menu")
		# RPC paketinin ağa çıkması için KISA bir an bekle, SONRA soketi kapat
		await get_tree().create_timer(0.2).timeout
	return_to_main_menu()

# Yalnızca sunucu çağırabilir, yalnızca uzak (client) tarafta çalışır
@rpc("authority", "call_remote", "reliable")
func force_everyone_to_main_menu():
	print("Sunucudan komut geldi: ana menüye dönülüyor.")
	return_to_main_menu()

# Client'ta sunucu koparsa otomatik tetiklenir (yedek garanti yol)
func _on_server_disconnected():
	print("Sunucu bağlantısı kesildi, ana menüye dönülüyor.")
	return_to_main_menu()

# Herkes için tek, güvenli dönüş fonksiyonu
func return_to_main_menu():
	if _returning_to_menu:
		return
	_returning_to_menu = true

	leave_room()  # UDP + ağ soketini temizler
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

	await get_tree().process_frame
	_returning_to_menu = false

func start_searching_rooms():
	active_rooms.clear()
	_stop_udp()

	udp_client = PacketPeerUDP.new()
	udp_client.set_broadcast_enabled(true)
	var err = udp_client.bind(0, "*")  
	if err != OK:
		print("Arama soketi açılamadı: ", err)
		return

	broadcast_timer = Timer.new()
	broadcast_timer.wait_time = BROADCAST_INTERVAL
	broadcast_timer.autostart = true
	broadcast_timer.timeout.connect(_send_discovery_request)
	add_child(broadcast_timer)
	_send_discovery_request()  
	
@rpc("any_peer", "reliable")
func oyuncu_sahnede_hazir():
	if not multiplayer.is_server():
		return
	_hazir_oyuncu_sayisi += 1
	print("Sahnede hazır: ", _hazir_oyuncu_sayisi, "/", MAX_PLAYERS)
	if _hazir_oyuncu_sayisi >= MAX_PLAYERS:
		_hazir_oyuncu_sayisi = 0
		var cm = get_tree().current_scene.get_node_or_null("CardManager")
		if cm:
			cm._mp_oyunu_baslat()
		else:
			print("HATA: CardManager bulunamadı, düğüm adını kontrol et.")

func _send_discovery_request():
	if udp_client and udp_client.is_bound():
		udp_client.set_dest_address("255.255.255.255", BROADCAST_PORT)
		udp_client.put_packet("DISCOVER_ROOMS".to_utf8_buffer())
func _listen_for_rooms():
	while udp_client.get_available_packet_count() > 0:
		var packet = udp_client.get_packet()
		var remote_ip = udp_client.get_packet_ip()
		var remote_port = udp_client.get_packet_port()
		
		var json_string = packet.get_string_from_utf8()
		var json = JSON.new()
		
		if json.parse(json_string) == OK:
			var data = json.get_data()
			active_rooms[remote_ip] = {
				"room_name": data["room_name"],
				"players": data["player_count"],
				"last_seen": Time.get_ticks_msec()
			}
			
			var current_time = Time.get_ticks_msec()
			for ip in active_rooms.keys():
				if current_time - active_rooms[ip]["last_seen"] > 4000:
					active_rooms.erase(ip)

func stop_searching_rooms():
	_stop_udp()

func _stop_udp():
	if is_instance_valid(broadcast_timer):
		broadcast_timer.queue_free()
		broadcast_timer = null
	if udp_server:
		udp_server.close()
		udp_server = null
	if udp_client:
		udp_client.close()

func join_room(ip_address: String, port: int = DEFAULT_PORT) -> bool:
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, port)
	if error != OK: return false
	multiplayer.multiplayer_peer = peer
	return true

func leave_room():
	_stop_udp()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	active_rooms.clear()

func _on_player_connected(id: int):
	print("Odaya yeni oyuncu katıldı! ID: ", id)
	if multiplayer.is_server():
		_send_updated_player_count_to_everyone()
		# 4 kişi dolduğunda oyunu başlat
		if not _game_started and multiplayer.get_peers().size() + 1 >= MAX_PLAYERS:
			_game_started = true
			await get_tree().create_timer(0.3).timeout
			_start_multiplayer_game()
			
func _start_multiplayer_game():
	koltuk_haritasi.clear()
	koltuk_haritasi[1] = 0
	var koltuk = 1
	for peer_id in multiplayer.get_peers():
		koltuk_haritasi[peer_id] = koltuk
		koltuk += 1

	_peer_isimleri[1] = local_player_name

	koltuk_isimleri.clear()
	for peer_id in koltuk_haritasi.keys():
		var seat = koltuk_haritasi[peer_id]
		koltuk_isimleri[seat] = _peer_isimleri.get(peer_id, "Oyuncu " + str(seat + 1))

	rpc("_setup_and_load_game", koltuk_haritasi, koltuk_isimleri)

@rpc("authority", "call_local", "reliable")
func _setup_and_load_game(harita: Dictionary, isimler: Dictionary):
	game_mode = GameMode.MULTIPLAYER
	koltuk_haritasi = harita
	koltuk_isimleri = isimler
	local_koltuk_no = harita[multiplayer.get_unique_id()]
	_stop_udp()
	get_tree().change_scene_to_file(GAME_SCENE)
	
func _on_connected_to_server():
	print("Sunucuya bağlanıldı")
	stop_searching_rooms()
	rpc_id(1, "_isim_bildir", local_player_name) 

@rpc("any_peer", "reliable")
func _isim_bildir(isim: String):
	if not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	_peer_isimleri[sender] = isim


func _on_player_disconnected(id: int):
	print("Bir oyuncunun odadan bağlantısı koptu. Ağ ID: ", id)
	
	if active_rooms.has(id):
		active_rooms.erase(id)
		
	if multiplayer.is_server():
		_send_updated_player_count_to_everyone()
		
		
func _send_updated_player_count_to_everyone():
	var toplam_oyuncu = multiplayer.get_peers().size() + 1
	var metin = "Oyuncu Sayısı: " + str(toplam_oyuncu) + " / " + str(MAX_PLAYERS)
	
	rpc("update_lobby_player_count", metin)

@rpc("any_peer", "call_local", "reliable")
func update_lobby_player_count(sayi_metni: String):
	var ana_sahne = get_tree().current_scene
	if ana_sahne:
		_recursive_update_label(ana_sahne, sayi_metni)

func _recursive_update_label(node: Node, metin: String):
	if not is_instance_valid(node):
		return
		
	if node.name == "OyuncuSayisiLabel" and node is Label:
		node.text = metin
		return
		
	for child in node.get_children():
		_recursive_update_label(child, metin)
