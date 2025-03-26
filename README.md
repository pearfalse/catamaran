# catamaran

Some bash scripts to help wrangle OpenSSL for internal CAs.

These scripts should make it a little easier to make your own internal root certificate authority, and any intermediate certificate authorities you want. The grunt work of signing certificates is handled by the `openssl ca` command.

**Standard disclaimer**: I am not a security expert, cryptographer, or OpenSSL developer. I'm just somebody who wanted a valid chain of trust on a silly fake TLD he made up for his own private networking needs. And maybe that's you, too.

# Setting up

Most of the folder structure you're going to use is informed by what `openssl ca` wants. The rest is about keeping catamaran scripts available to, but separate from, the actual certificate database.

Catamaran supports multiple certificate authorities, and gives each one an ID. This is a small text string, chosen by you, that's substituted into folder names and OpenSSL config keys.

## Requirements

You will need installed:

- OpenSSL 3.x
- Bash 4.x or better

## Installation

You will need to follow this section once.

- Create a folder to hold your CA info, which this readme will refer to as the _database folder_. Do not make this a subfolder of the Catamaran scripts folder.
- Copy `examples/catamaran.conf.sh` to your database folder (keep the name the same) and adjust it according to your needs.
- Run `catamaran generate-openssl-config` to place an `openssl.cnf` file in your database folder. This reflects your Catamaran config, and you should re-run this command after every config change.

I don't recommend manually changing `openssl.cnf` after it's created; this is an easy way to make load-bearing alterations that get accidentally lost forever.

# Preparing the environment

You should follow this every time you open a shell to make data under your CA.

- Open a Bash shell and `cd` to the Catamaran checkout folder.
- Create an alias: `alias catamaran="'$(pwd)/catamaran'"`
- `cd` to your database folder. Catamaran must _always_ be run from this, or it will misbehave.

# Creating certificate authorities

Follow this to create the key, cert and data folder for each CA.

Run `catamaran init-ca` to create the root CA. This creates a file/folder structure under `<CA ID>.cadb` that `openssl ca` will be happy with. You'll be prompted for a password for encrypting the private key; use something **strong** and store it in a password manager. If `CATAMARAN_ROOT_CA[KEY_TYPE]` is set to `rsa`, it will make a 4096-bit RSA key with SHA-256 digest (slower, worse, but more compatible); if not, it will default to an ECDSA key on the secp384r1 curve with SHA-384 digest (faster, better, but less compatible with older systems). Consider that some systems [will reject](https://stackoverflow.com/a/47881232) certificates with ECDSA keys that are signed by certificate authoritites with RSA keys; I have seen this myself. The other way round is fine.

Optionally, you can also set up intermediate certificate authorities with Catamaran. Most orgs use intermediate CAs to reduce exposure to the root CA private key. Server-specific certificates are signed by the intermediate CA instead, and its certificate is also presented to the user by the relevant server. This means the end user's system only needs to have the root CA cert pre-installed, which is less logistical hassle for everyone involved.

The reasons why you, as a Catamaran user, would want to use an intermediate CA, is probably for one of these reasons:

- Showing off. Doing it because you can.
- Adding optional [name constraints](https://timothy-quinn.com/name-constraints-in-x509-certificates/), so that trusting your root CA is less risky (e.g. more difficult to make a local arbitrary certificate for your bank, and other no-nos. The above point about reducing exposure to the root CA key is also relevant here.

To generate data for intermediate CA, run `catamaran init-ca {CA ID}`. You will need to run this once per intermediate CA, so that you can always add more later.

**Warning**: Be careful when re-running `init-ca` for intermediate CAs. `openssl ca` doesn't let you generate a duplicate certificate for the same subject, and Catamaran may not 100% handle this case correctly. It will refuse to do anything if the intermediate CA folder already exists, but if you manually delete it, all bets are off. See _Remaking a certificate_ if you need to remake an intermediate CA.

## Import the CAs

Import the root CA certificate (**not the key**) into your system's certificate store. For Windows, this should be the _Third-Party Root Certification Authorities_ at machine level (run `certlm.msc` to open this). For MacOS, the _System_ keychain is where you should import it; override the trust level for _Basic X.509 Policy_ to _Always Trust_.

Import any intermediate CA certificates you have (again, **not the keys**). For Windows, use the _Intermediate Certification Authorities_ store to avoid automatically trusting the cert (that's what the trusted root CA cert is for). For MacOS, import the certificate to the _System_ keychain as before, but do not override any of the trust levels.

If your system shows intermediate CAs as valid, this shows that your homegrown link in the system's trust chain is working.

> Theoretically, you don't need to import an intermediate cert this way; the server in question for the leaf certificate will offer up its intermediates as well. However, as well as providing proof that things are working as intended, this also works around an issue you might have where server software does not let you specify a second certificate to include in the TLS handshake, so the system needs to know about it ahead of time. The [IPMI firmware](https://en.wikipedia.org/wiki/Intelligent_Platform_Management_Interface) on my NAS mainboard is one such case I have.

# Creating leaf certificates

Let's make some certificates for actual things now. `catamaran new-cert` makes a leaf certificate for a server/domain. It takes the following parameters:

- The ID of the CA to use, which should be one of your intermediates, if you have them;
- The site domain, which should be fully qualified;
- The string `rsa`, if you want an RSA key and signature; omit it, or set it to anything else, to default to an ECDSA key.

You will be prompted for the password of the signing CA's key. Running this will create the following files:

- `site_{domain}.key`, which is the server's private key in PEM (plaintext) format. This file is unencrypted; you are encouraged to encrypt it in a way that makes sense for your application.
- `{ca_id}.cadb/newcerts/{serial}.pem`, a signed certificate in PEM format. `openssl` will also add a human-readable dump of the certificate contents above the header; this is technically fully standards-compliant, but you may want to remove it. Catamaran will print out the exact path of this file.

# Remaking a certificate

If you need to remake a certificate for whatever reason, you should manually remove the old one from the CA's `.cadb` folder first:

- Find the certificate inside `index`. The fifth column in a row is the certificate's Subject, while the third column is its serial.
- Delete the file in `newcerts` named after this serial.
- Delete the certificate's row in `index`.
- Optionally, roll the index back by changing the contents in `serial`. Not recommended if you have already distributed certificates with rewound serial numbers anywhere.


# Not currently supported

- CRL or OCSP
- Signing SSH keys
- Extending OpenSSL config
- Generating certificates with additional DN components, or user-supplied extensions
