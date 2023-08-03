# catamaran

Some simple bash scripts to help wrangle OpenSSL for internal CAs.

These scripts should make it a little easier to make your own internal root certificate authority, and any intermediate certificate authorities you want. You will need to change the OpenSSL config and scripts so that the cert names match what you want.

So far, these scripts will make all CAs, but using them to sign actual certificates is not done yet. The basics are in the OpenSSL config, but it's not as end-to-end.
