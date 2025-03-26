# args: CA ID, CN value to search for
_catamaran_cn_found_in_index() {
	local cn="CN="$(echo -n "$2" | sed -r 's/\./\\./g')"\\b"
	grep -qE "$cn" "${1}.cadb/index"
}
