source "$CATAMARAN_LIB"/config.sh
source "$CATAMARAN_LIB"/openssl-cnf.sh

case "$1" in
	-c)
		_catamaran_generate_openssl_cnf
		;;
	-h | --help)
		echo "usage: $CATAMARAN_0 $CATAMARAN_SUBCMD [-c]"
		;;
	*)
		_catamaran_generate_openssl_cnf > ./openssl.cnf
		;;
esac
