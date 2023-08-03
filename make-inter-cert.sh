#!/usr/bin/env bash

SUBJ=""
read -s -p "Enter root CA key password: " CA_PASS
echo
if [[ -z "$CA_PASS" ]] ;then
	echo "no password entered"
	exit 1
fi

subj()
{
	local escaped_value="$(echo -n "$2" | sed -re 's@\\@\\\\@g' -e 's@/@\\/@g')"
	SUBJ="$SUBJ/$1=${escaped_value}"
}

make_inter()
{
	if [[ -z "$2" ]] ;then
		echo "missing CN for intermediate cert"
		exit 127
	fi
	if [[ -z "$3" ]] ;then
		echo "missing OU for intermediate cert"
		exit 127
	fi

	read -s -p "Enter *unique* password for the \`$1\` intermediate CA key: " INTER_PASS
	echo
	if [[ -z "$INTER_PASS" ]] ;then
		echo "no password entered; skipping"
		return
	fi
	read -s -p "Confirm \`$1\` password: " INTER_PASS2
	if [[ "$INTER_PASS2" != "$INTER_PASS" ]] ;then
		echo "passwords do not match; skipping"
		return
	fi

	ICA_CODE="$1"
	SUBJ=""
	subj CN "$2"
	subj OU "$3"
	subj O  "PFHome"
	subj C  "GB"

	shift 3

	declare -a _ext_arg
	if [[ -n "$CUSTOM_EXTENSION" ]] ;then
		_ext_arg=( "-addext" "$CUSTOM_EXTENSION" )
	fi

	openssl genrsa -aes256 -passout stdin \
		-out ca-inter-${ICA_CODE}.key 4096 <<< "$INTER_PASS"

	openssl req -config PFHome.conf -new \
		-key ca-inter-${ICA_CODE}.key -out ca-inter-${ICA_CODE}.csr \
		-subj "$SUBJ" \
		-extensions ca_self_ext \
		"${_ext_arg[@]}" \
		-passin stdin <<< "$INTER_PASS"


	openssl ca -config PFHome.conf -in ca-inter-${ICA_CODE}.csr \
		-cert ca.pem -keyfile ca.key \
		-out ca-inter-${ICA_CODE}.pem -days 3650 \
		-extensions ca_inter_ext \
		-passin file:<(echo "$CA_PASS")
}

set -e

CUSTOM_EXTENSION="nameConstraints = critical, permitted;DNS:.device.pf" \
make_inter dev "PFHome Devices Intermediate Certificate Authority" "Upper Echelons"

make_inter svc "PFHome Services Intermediate Certificate Authority" "Upper Echelons"
make_inter phi "PFHome Second Root Certificate Authority" "Phantom Intermediary"
