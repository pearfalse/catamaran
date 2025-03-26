_catamaran_escape_dn_part() {
	echo -n "$1" | sed -r -e 's@\\@\\\\@g' -e 's@/@\\/@g'
}

# Builds a DN in the bespoke format `openssl` wants.

# args: name of AA to ref, id to show the user
_catamaran_build_openssl_dn()
{
	local -n _aa="$1"
	local cn="${_aa[SUBJECT_CN]}"
	if [[ -z "$cn" ]] ;then
		echo "error: CA '$2' does not define a CN in its subject" >&2
		return 1
	fi

	# Always put CN first
	local SUBJ="/CN=$(_catamaran_escape_dn_part "$cn")"

	local key
	for PART in ${!_aa[@]} ;do
		if [[ "$PART" == "SUBJECT_CN" || "${PART#SUBJECT_}" == "$PART" ]] ;then
			# not a SUBJECT_ key, or is CN, which we handle specially
			continue
		fi
		key="_aa[$PART]"
		SUBJ="$SUBJ/${PART#SUBJECT_}=$(_catamaran_escape_dn_part "${!key}")"
	done

	echo -n "$SUBJ"
}

export MSYS2_ARG_CONV_EXCL="/CN"
