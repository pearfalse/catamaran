# to init CA

DB_FOLDER="$1"
if [[ -z "$DB_FOLDER" ]] ;then
	echo "usage: $0 <db folder to init>"
	exit 1
fi

if [[ -e "$DB_FOLDER" ]] ;then
	echo "folder '$DB_FOLDER' already exists; refusing to wipe"
	exit 2
fi

# up to 20 hex octets, feel free to pick something more your style
SERIAL='1606000000000000000000000000000000000001'

set -xe
mkdir "$DB_FOLDER" # or whatever you called it, if you renamed it in config
cd "$DB_FOLDER"
mkdir certs crl newcerts private
echo db index.txt | xargs -n 1 truncate -s 0
rm -f db.{attr,old}
echo "$SERIAL" > serial
git init # the manpage for `openssl ca` warns that fixing a corrupted index.txt is basically impossible, so keep the contents of this folder safe!
set +x
echo "please copy the CA certificate to \`ca.pem\`, and the private key to \`private/ca.key\`"
