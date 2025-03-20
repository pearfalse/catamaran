#!/usr/bin/env bash -e

CA="${1:-ca}"

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
set -x

# exec openssl genrsa -aes256 -passout stdin \
# 	-out ca.key 4096 <<< "$CA_PASS"

openssl ec -in <(openssl ecparam -genkey -name secp384r1 -noout 2>/dev/null) \
	-out "$CA".key -aes256 -passout stdin <<< "$CA_PASS"
openssl ec -in "$CA".key -pubout -out "$CA".key.pub \
	-passin stdin <<< "$CA_PASS"
mkdir -p "$CA".db/{newcerts,crl,certs}
touch "$CA".db/index
echo 1000 > "$CA".db/serial

