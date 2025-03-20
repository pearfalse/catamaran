#!/bin/bash -e

# args: new-site.sh [CA to use [site domain [ecdsa|rsa]]]

SITE_CN="$2"
if [[ -z "$SITE_CN" ]] ;then
	read -p "Enter the full domain path of the site: " SITE_CN
fi
if [[ -z "$SITE_CN" ]] ;then
	echo "no domain entered"
	exit 1
fi

CA_CODE="${1:-ca}"

# i know this is restrictive; it's just here to catch mistakes
# feel free to subvert it if you need to
DNS_REGEX='^[A-Za-z]([A-Za-z0-9\-]*[A-Za-z0-9])?$'
DNS_VALIDITY="$(echo -n "$SITE_CN" | (
	IFS='.'
	for PART in $(cat) ; do
		grep -qE $DNS_REGEX <<< "$PART" || { echo X ; exit ;}
	done
)
echo -n "$SITE_CN" | grep -qvE '^\.|\.$' || echo X
)"

if grep -q X <<< "$DNS_VALIDITY" ;then
	echo "error: domain provided is not valid"
	exit 1
fi


KEYPATH="site_${SITE_CN}.key"
REQPATH="otmp-${SITE_CN}.csr"
CERTPATH="otmp-${SITE_CN}.pem"

echo "Will sign against CA \`${CA_CODE}\`."
read -s -p "Enter CA key password: " CA_PASS
echo
if [[ -z "$CA_PASS" ]] ;then
	echo "no password entered"
	exit 1
fi

echo "generating private key... "
if [[ "$3" == "rsa" ]] ;then
	echo "Using an RSA keypair"
	set -x
	openssl genrsa -out $KEYPATH 4096
	set +x
else
	echo "Using an ECDSA keypair"
	set -x
	openssl ec -in <(openssl ecparam -genkey -name secp384r1 -noout 2>/dev/null) \
		-out "$KEYPATH" -aes256 -passout stdin <<< "$CA_PASS"
	openssl ec -in "$KEYPATH" -pubout -out "$KEYPATH".pub \
		-passin stdin <<< "$CA_PASS"
	set +x
fi
echo "done"

SUBJ=""
subj()
{
	local escaped_value="$(echo -n "$2" | sed -re 's@\\@\\\\@g' -e 's@/@\\/@g')"
	SUBJ="$SUBJ/$1=${escaped_value}"
}

# keep this one first, or change MSYS2_ARG_CONV_EXCL= below in line with this
subj CN "$SITE_CN"
subj OU "A Website!"
subj O  "PFHome"

echo -n "Creating certificate... "
set -x
MSYS2_ARG_CONV_EXCL="/CN" openssl req -config openssl.cnf \
	-new -sha384 \
	-key "$KEYPATH" -out "$REQPATH" \
	-subj "$SUBJ" \
	-extensions v3_req -addext 'subjectAltName=DNS:'"$SITE_CN" \
	-passin stdin <<< "$CA_PASS"

CUR_SERIAL=$(cat ${CA_CODE}.db/serial)

openssl ca -config openssl.cnf -in ${REQPATH} \
	-cert $CA_CODE.pem -keyfile $CA_CODE.key -md sha384 \
	-extensions v3_ca -name CA_${CA_CODE} -days 730 \
	-out "site_${SITE_CN}.pem" \
	-batch -passin stdin <<< "$CA_PASS"
set +x


# uncomment this for convenient import of local servers into a Windows cert store
# echo -n "creating PKCS#12 file for import into system keychain: "
# PKCS12_PASS="$(echo -n "$SITE_CN" | grep -oE '[^.]+$')"
# openssl pkcs12 -export -in "$CERTPATH" -inkey "$KEYPATH" \
# 	-CSP "Microsoft Enhanced RSA and AES Cryptographic Provider" \
# 	-passout stdin -out "Keypair for $SITE_CN.pfx" <<< "$PKCS12_PASS"
# echo "done (password is \`$PKCS12_PASS\`)"
