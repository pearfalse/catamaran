# Catamaran sample config file
# Catamaran will pay attention to select variables starting with `CATAMARAN_`

# It is just a Bash script though, so you can do your own scripting stuff
OU="Upper Echelons"

ca_cn()
{
	echo "$CATAMARAN_ORG $@ Certificate Authority"
}

# Organisation name, which will be written to the `O` part of all certificate names
CATAMARAN_ORG="PFHome"

# Define the root CA here
CATAMARAN_ROOT_CA[ID]="root" # this will default to `root` if not specified
CATAMARAN_ROOT_CA[SUBJECT_CN]="$(ca_cn Root)"
CATAMARAN_ROOT_CA[SUBJECT_OU]="$OU"
# This is 1 to 20 bytes, stored concatenated in hex form. This is intended to uniquely
# identify every certificate signed by a single CA, and will increment by 1 (in the
# database, not here) after every successful signing. Feel free to change this to
# something else if you have a different stylistic opinion here, or want to obscure
# that you used catamaran scripts.
CATAMARAN_ROOT_CA[SERIAL]="160603A10001" # if not specified, defaults to "1000"

# Intermediate CAs are a little more awkward, due to Bash's limited semantics

# Define the Services inter CA
declare -A INTER_SVC
INTER_SVC[SUBJECT_CN]="$(ca_cn Services Intermediate)"
INTER_SVC[SUBJECT_OU]="$OU"
INTER_SVC[SERIAL]="160603A20001"
# Any key beginning with `EXT_` will be added to this CA certificate. The syntax
# is that of the `-addext` argument to `openssl req`.
INTER_SVC[EXT_NAME]="nameConstraints = critical, permitted;DNS:.pf"
CATAMARAN_INTER_CA[services]="INTER_SVC"

# Define the Devices inter CA
declare -A INTER_DEV
INTER_DEV[SUBJECT_CN]="$(ca_cn Devices Intermediate)"
INTER_DEV[SUBJECT_OU]="$OU"
INTER_DEV[SERIAL]="160603A30001"
INTER_DEV[EXT_NAME]="nameConstraints = critical, permitted;DNS:.device.pf"
CATAMARAN_INTER_CA[devices]="INTER_DEV"

# Define the Legacy inter CA, which will use an RSA key type, and be preloaded
# along with the root CA (for server software that can't send a cert chain)
declare -A INTER_LEGACY
INTER_LEGACY[SUBJECT_CN]="$(ca_cn Legacy Intermediate)"
INTER_LEGACY[SUBJECT_OU]="$OU"
INTER_LEGACY[KEY_TYPE]="rsa"
INTER_LEGACY[SERIAL]="160603A40001"
INTER_LEGACY[EXT_NAME]="nameConstraints = critical, permitted;DNS:.lpool.pf"
CATAMARAN_INTER_CA[legacy]="INTER_LEGACY"

# Littering is rude
unset OU
unset ca_cn
