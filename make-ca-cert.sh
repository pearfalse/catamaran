#!/usr/bin/env bash

SUBJ=""

subj()
{
	local escaped_value="$(echo -n "$2" | sed -re 's@\\@\\\\@g' -e 's@/@\\/@g')"
	SUBJ="$SUBJ/$1=${escaped_value}"
}

subj CN "PFHome Root Certificate Authority"
subj OU "Upper Echelons"
subj O  "PFHome"
subj C  "GB"

set -x
exec openssl req -config PFHome.conf \
	-x509 -new -days 3650 \
	-key ca.key -out ca.pem \
	-subj "$SUBJ" \
	-extensions ca_self_ext
