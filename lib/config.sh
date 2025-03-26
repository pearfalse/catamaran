declare -A CATAMARAN_ROOT_CA
declare -A CATAMARAN_INTER_CA
CATAMARAN_ROOT_CA[ID]="root"
source ./catamaran.conf.sh

# normalise and standardise SUBJECT_O across all CAs

if [[ -z "$CATAMARAN_ORG" ]] ;then
	echo "error: config must define CATAMARAN_ORG" >&2
	exit 2
fi
CATAMARAN_ROOT_CA[SUBJECT_O]="$CATAMARAN_ORG"

# validate INTER_CA keys
for inter_key in ${!CATAMARAN_INTER_CA[@]} ;do
	if [[ "$inter_key" == "${CATAMARAN_ROOT_CA[ID]}" ]] ;then
		echo "error: CATAMARAN_INTER_CA defines an intermediate CA named '$inter_key', but the root CA is also called this" >&2
		exit 2
	fi
done
unset inter_key

# validate INTER_CA values
for inter_ref in ${CATAMARAN_INTER_CA[@]} ;do
	declare -n inter=$inter_ref || {
		echo "error: CATAMARAN_INTER_CA references non-existent '$inter_ref'" >&2
		exit 2
	}
	inter[SUBJECT_O]="$CATAMARAN_ORG"
done

# redeclare inter as not an alias, otherwise `unset` deletes the referent!
declare +n inter
unset inter
unset inter_ref
