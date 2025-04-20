
send:
	rsync -avz --delete . kamoshi:/etc/nixos

back:
	rsync -avz --delete kamoshi:/etc/nixos/ .
