#!/usr/bin/env bash -e

SUBJ="$2"
CA="${1:-ca}"

if [[ -z "$2" ]] ;then
subj()
{
	local escaped_value="$(echo -n "$2" | sed -re 's@\\@\\\\@g' -e 's@/@\\/@g')"
	SUBJ="$SUBJ/$1=${escaped_value}"
}

subj CN "PFHome Root Certificate Authority"
subj OU "Upper Echelons"
subj O  "PFHome"
subj C  "GB"
fi

set -x
exec openssl req -config openssl.cnf \
	-x509 -new -days 3650 \
	-key "$CA".key -out "$CA".pem \
	-subj "$SUBJ" -extensions v3_ca \
	-sha384
