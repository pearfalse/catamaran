#!/usr/bin/env bash

read -s -p "Enter CA key password: " CA_PASS
echo
if [[ -z "$CA_PASS" ]] ;then
	echo "no password entered"
	exit 1
fi
read -s -p "Confirm: " CA_PASS2
echo
if [[ "$CA_PASS" != "$CA_PASS2" ]] ;then
	echo "key password not confirmed"
	exit 1
fi
set -x
exec openssl genrsa -aes256 -passout stdin \
	-out ca.key 4096 <<< "$CA_PASS"
