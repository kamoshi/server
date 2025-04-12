
send:
	rsync -avz . kamoshi:/etc/nixos/

back:
	rsync -avz kamoshi:/etc/nixos/ .
