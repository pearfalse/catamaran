source "$CATAMARAN_LIB"/config.sh
source "$CATAMARAN_LIB"/dn.sh
source "$CATAMARAN_LIB"/cadb.sh

if [[ "$1" == "-h" || "$1" == "--help" ]] ;then
	echo "usage: $CATAMARAN_0 $CATAMARAN_SUBCMD {CA ID} {domain to sign for} [rsa]"
	exit 0
fi

ca_id="$1"
if [[ -z "$ca_id" ]] ;then
	echo "error: CA to use not specified" >&2
	exit 1
fi

if [[ "$ca_id" == "${CATAMARAN_ROOT_CA[ID]}" ]] ;then
	ref=CATAMARAN_ROOT_CA
else
	ref="${CATAMARAN_INTER_CA[$ca_id]}"
fi
declare -n ca_data=$ref 2>/dev/null || {
	echo "error: unknown CA '$ca_id'" >&2
	exit 1
}

site_cn="$2"
if [[ -z "$site_cn" ]] ;then
	echo "error: no domain entered" >&2
	exit 1
fi

# check cert doesn't seem to exist already
if _catamaran_cn_found_in_index "$ca_id" "$site_cn" ;then
	echo "error: CA '$ca_id' appears to have already made a certificate for $site_cn" >&2
	echo "note: please remove this manually from the database first" >&2
	exit 2
fi

key_path="site_${site_cn}.key"
csr_path="otmp-${site_cn}.csr"

echo "Will sign against CA \`${ca_id}\`" >&2
read -s -p "Enter CA key password: " CA_PASS
echo
if [[ -z "$CA_PASS" ]] ;then
	echo "no password entered"
	exit 1
fi

echo "generating private key... "
if [[ "$3" == "rsa" || "${ca_data[KEY_TYPE]}" == "rsa" ]] ;then
	echo "Using an RSA keypair"
	openssl genrsa -out $key_path 4096
	cert_hash_type=sha256
else
	echo "Using an ECDSA keypair"
	openssl ecparam -genkey -name secp384r1 -noout -out "$key_path"
	cert_hash_type=sha384
fi
echo "done"

echo -n "Creating certificate... "
openssl req -config openssl.cnf \
	-new -$cert_hash_type \
	-key "$key_path" -out "$csr_path" \
	-subj "/CN=${site_cn}/O=${CATAMARAN_ORG}" \
	-addext 'subjectAltName=DNS:'"$site_cn" \
	-passin stdin <<< "$CA_PASS"

serial=$(cat ${ca_id}.cadb/serial)

openssl ca -config openssl.cnf -in ${csr_path} \
	-cert ${ca_id}.cadb/ca.pem -keyfile ${ca_id}.cadb/private/ca.key -md $cert_hash_type \
	-extensions user_cert_${ca_id} -name CA_${ca_id} -days 360 \
	-out "site_${site_cn}.pem" \
	-batch -passin stdin <<< "$CA_PASS"

rm $csr_path

echo "Certificate for ${site_cn} created at ${ca_id}.cadb/newcerts/${serial}.pem" >&2
