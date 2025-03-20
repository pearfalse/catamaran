#!/usr/bin/env bash -e

SUBJ=""
if [[ -z "$ROOT_CA" ]] ;then ROOT_CA="ca" ;fi

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

	read -s -p "Enter password for the \`$1\` intermediate CA key: " INTER_PASS
	echo
	if [[ -z "$INTER_PASS" ]] ;then
		echo "no password entered; skipping"
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
	set -x
	openssl req -config openssl.cnf -new \
		-key inter_${ICA_CODE}.key -out inter_${ICA_CODE}.csr \
		-subj "$SUBJ" \
		"${_ext_arg[@]}" \
		-passin stdin <<< "$INTER_PASS"


	openssl ca -config openssl.cnf -in inter_${ICA_CODE}.csr \
		-cert $ROOT_CA.pem -keyfile $ROOT_CA.key \
		-extensions v3_ca -name CA_{$ROOT_CA} -sha384 \
		-out inter_${ICA_CODE}.pem -days 3650 \
		-batch -passin stdin <<< "$CA_PASS"
	set +x
}

set -e

CUSTOM_EXTENSION="nameConstraints = critical, permitted;DNS:.pf" \
make_inter services "PFHome Services Certificate Authority" "Upper Echelons"

CUSTOM_EXTENSION="nameConstraints = critical, permitted;DNS:.device.pf" \
make_inter devices "PFHome Devices Certificate Authority" "Upper Echelons"
