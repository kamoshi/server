.PHONY: aya momiji megumu megumu-up megumu-down update check

aya:
	darwin-rebuild build --flake .#aya

momiji:
	home-manager switch --flake .#momiji

megumu:
	sudo nixos-rebuild switch --flake .#megumu

megumu-up:
	rsync -avz --delete --progress . megumu:~/nix-config

megumu-down:
	rsync -avz --delete --progress megumu:~/nix-config/ .

update:
	nix flake update

check:
	nix flake check
