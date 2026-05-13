extends HBoxContainer

func set_data(account: Account,message: String):
	$Background/Account.text = account.username + ": "
	
	$Background2/Message.text = message
