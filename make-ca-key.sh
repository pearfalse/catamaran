#!/usr/bin/env bash -e

# Makes the key for the root CA (and intermediates, if you want them).

# You don't need to alter anything here; just pass the arguments accordingly.

if [[ "$1" == "-h" || "$1" == "--help" ]] ;then
	echo "usage: $0 [CA codename, default 'ca'] ['rsa', to not make an ECDSA key]"
	exit 0
fi

CA="${1:-ca}"
KEY_TYPE="$2"

echo "CA name is $CA"

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

if [[ "$KEY_TYPE" == "rsa" ]] ;then
	set -x
	openssl genrsa -aes256 -passout stdin -out ca.key 4096 <<< "$CA_PASS"
else
	set -x
	openssl ec -in <(openssl ecparam -genkey -name secp384r1 -noout 2>/dev/null) \
		-out "$CA".key -aes256 -passout stdin <<< "$CA_PASS"
	openssl ec -in "$CA".key -pubout -out "$CA".key.pub \
		-passin stdin <<< "$CA_PASS"
fi
