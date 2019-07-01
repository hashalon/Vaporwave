extends Control

func _ready():
	$buttons/host_btn.connect("button_down", self, "_on_host")
	$buttons/join_btn.connect("button_down", self, "_on_join")


func _on_host()->void:
	lobby.own_name = $buttons/name_field.text
	lobby.host_game()
	

func _on_join()->void:
	lobby.own_name = $buttons/name_field.text
	var ip:String=$buttons/ip_field.text
	if ip == "": ip = "localhost"
	lobby.join_game(ip)