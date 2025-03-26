#!/usr/bin/env bash -e

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

# This is 1 to 20 bytes, stored concatenated in hex form. This is intended to uniquely
# identify every certificate signed by a single CA, and will increment by 1 after every
# successful signing. Feel free to change this to something else if you have a
# different stylistic opinion here, or want to obscure that you used catamaran scripts.
if [[ -z "$CA_SERIAL" ]] ;then
	CA_SERIAL='16060001'
fi

set -x
mkdir "$DB_FOLDER" # or whatever you called it, if you renamed it in config
cd "$DB_FOLDER"
mkdir certs crl newcerts private
echo db index.txt | xargs -n 1 truncate -s 0
rm -f db.{attr,old}
echo "$CA_SERIAL" > serial
set +x
