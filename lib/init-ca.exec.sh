source "$CATAMARAN_LIB"/config.sh
source "$CATAMARAN_LIB"/dn.sh

if [[ "$1" == "-h" || "$1" == "--help" ]] ;then
	echo "usage: $CATAMARAN_0 $CATAMARAN_SUBCMD [intermediate CA]"
	echo "(omit intermediate CA, or pass _, to init the root CA)"
	exit 0
fi

ca_id="$1"
if [[ -z "$ca_id" || "$ca_id" == "_" ]] ;then
	echo "initialising root CA" >&2
	ref="CATAMARAN_ROOT_CA" # needed later on, not here
	ca_id="${CATAMARAN_ROOT_CA[ID]}"
else
	echo "initialising intermediate CA '$ca_id'" >&2
	ref="${CATAMARAN_INTER_CA[$ca_id]}"
fi

declare -n ca_data=$ref 2>/dev/null || {
	echo "error: '$ca_id' is not a valid CA identifier" >&2
	echo "note: if you wanted to init the root CA, remove this argument, or pass _ instead" >&2
	exit 1
}
serial=${ca_data[SERIAL]}

if [[ -z "$ca_id" ]] ;then
	echo "error: CA ID is missing or empty" >&2
	exit 1
fi

# verify folder status first
ca_folder="${ca_id}.cadb"
if [[ -e "$ca_folder/index" ]] ;then
	echo "error: index in '$(realpath "$ca_folder")' already exists; aborting out of caution" >&2
	echo "note: if you want to completely reinit this CA, delete the existing $ca_folder first" >&2
	return 1
fi

# prompt for key password before doing anything
read -s -p "Enter CA key password: " CA_PASS
echo
if [[ -z "$CA_PASS" ]] ;then
	echo "error: no password entered" >&2
	exit 1
fi
read -s -p "Confirm: " CA_PASS2
echo
if [[ "$CA_PASS" != "$CA_PASS2" ]] ;then
	echo "error: key password not confirmed" >&2
	exit 1
fi

if [[ "$ref" != "CATAMARAN_ROOT_CA" ]] ;then
	# signing an intermediate cert, so also prompt for root CA
	read -s -p "Enter the *root* CA key password: " CA_ROOT_PASS
	if [[ -z "$CA_ROOT_PASS" ]] ;then
		echo "error: root CA key password not entered" >&2
		exit 1
	fi
fi

subj=$(_catamaran_build_openssl_dn "$ref" "$ca_id")

# make data folder
mkdir -p "$ca_folder"
pushd "$ca_folder"
mkdir certs crl newcerts private
echo db index | xargs -n 1 truncate -s 0
rm -f db.{attr,old}
echo "${serial:-1000}" > serial
popd

ca_key_path="${ca_folder}/private/ca.key"

# make private and public keys
if [[ "${ca_data[KEY_TYPE]}" == "rsa" ]] ;then
	echo "info: generating RSA/4096 key" >&2
	openssl genrsa -aes256 -passout stdin -out "$ca_key_path" 4096 <<< "$CA_PASS"
	openssl rsa -in "$ca_key_path" -pubout -out "${ca_folder}/ca.key.pub" \
		-passin stdin <<< "$CA_PASS"
	cert_hash_type="sha256"
else
	echo "info: generating ECDSA/secp384r1 key" >&2
	openssl ec -in <(openssl ecparam -genkey -name secp384r1 -noout 2>/dev/null) \
		-out "$ca_key_path" -aes256 -passout stdin <<< "$CA_PASS"
	openssl ec -in "$ca_key_path" -pubout -out "${ca_folder}/ca.key.pub" \
		-passin stdin <<< "$CA_PASS"
	cert_hash_type="sha384"
fi

# make cert
declare -a ext_arg
for key in ${!ca_data[@]} ;do
	if [[ "${key#EXT_}" != "$key" ]] ;then
		ext_arg+=(-addext "${ca_data[$key]}")
	fi
done

if [[ "$ref" == "CATAMARAN_ROOT_CA" ]] ;then
	# root CA? self-sign
	openssl req -config openssl.cnf \
		-x509 -new -days 3650 \
		-key "$ca_key_path" -out "${ca_folder}/ca.pem" \
		-subj "$subj" -extensions v3_ca \
		-$cert_hash_type \
		-passin stdin <<< "$CA_PASS"
else
	# intermediate CA; use root CA to sign it
	csr_path="${ca_folder}/.inter.csr"
	root_ca="${CATAMARAN_ROOT_CA[ID]}"

	openssl req -config openssl.cnf -new \
		-key ${ca_key_path} -out "$csr_path" \
		-subj "$subj" -$cert_hash_type \
		"${ext_arg[@]}" \
		-passin stdin <<< "$CA_PASS"

	openssl ca -config openssl.cnf -in "$csr_path" \
		-cert "$root_ca.cadb/ca.pem" \
		-keyfile "$root_ca.cadb/private/ca.key" -md $cert_hash_type \
		-extensions v3_ca -name "CA_${root_ca}" \
		-out ${ca_folder}/ca.pem -days 3650 \
		-batch -passin stdin <<< "$CA_ROOT_PASS"

	rm "$csr_path"
fi
echo "done" >&2
