#!/usr/bin/env bash -e

# Args: [root CA ID, default 'ca']
# Make intermediate certificate authorities. This is optional.

# This makes the certs, not the keys; run `make-ca-key.sh` for each intermediate CA first.

# To adjust for your needs, alter the `subj` calls below, as well as the `make_inter`
# calls at the bottom of the script.

SUBJ=""
if [[ -n "$1" ]] ;then
	ROOT_CA="$1"
else
	ROOT_CA="ca"
fi

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

	# Change this for your needs; `O` must match that in `make-ca-cert.sh`
	subj CN "$2"
	subj OU "$3"
	subj O  "PFHome"

	shift 3

	declare -a _ext_arg
	if [[ -n "$CUSTOM_EXTENSION" ]] ;then
		_ext_arg=( "-addext" "$CUSTOM_EXTENSION" )
	fi
	set -x
	openssl req -config openssl.cnf -new \
		-key inter_${ICA_CODE}.key -out inter_${ICA_CODE}.csr \
		-subj "$SUBJ" -sha384 \
		"${_ext_arg[@]}" \
		-passin stdin <<< "$INTER_PASS"


	openssl ca -config openssl.cnf -in inter_${ICA_CODE}.csr \
		-cert $ROOT_CA.pem -keyfile $ROOT_CA.key -md sha384 \
		-extensions v3_ca -name CA_${ROOT_CA} \
		-out inter_${ICA_CODE}.pem -days 3650 \
		-batch -passin stdin <<< "$CA_PASS"
	set +x
}

set -e

# Change as necessary

CUSTOM_EXTENSION="nameConstraints = critical, permitted;DNS:.pf" \
make_inter services "PFHome Services Certificate Authority" "Upper Echelons"

CUSTOM_EXTENSION="nameConstraints = critical, permitted;DNS:.device.pf" \
make_inter devices "PFHome Devices Certificate Authority" "Upper Echelons"
