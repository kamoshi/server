.PHONY: aya momiji megumu megumu-up megumu-down update check

aya:
	sudo darwin-rebuild switch --flake .#aya

momiji:
	home-manager switch --flake .#momiji

megumu:
	sudo nixos-rebuild switch --flake .#megumu

megumu-up:
	rsync -avz --delete --progress . megumu:~/nix

megumu-down:
	rsync -avz --delete --progress megumu:~/nix/ .

nitori:
	home-manager switch --flake .#nitori

update:
	nix flake update

check:
	nix flake check
