#!/usr/bin/env bash

HOST=`hostname`
if [[ ! -z "$1" ]]; then
	HOST=$1
fi

if [[ ! -e "hosts/$HOST/configuration.nix" ]]; then
	echo "missing config file for $HOST" >&2
	exit 1
fi

ln -f "hosts/$HOST/configuration.nix" .
