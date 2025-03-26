# catamaran

Some bash scripts to help wrangle OpenSSL for internal CAs.

These scripts should make it a little easier to make your own internal root certificate authority, and any intermediate certificate authorities you want. In their current form, these scripts are unfinished; you may need to make changes to them to fit your needs. Said places are documented in each script, as well as in the rest of this readme.

# Setting up

Most of the folder structure you're going to use is informed by what `openssl ca` wants. The rest is about keeping catamaran scripts available to, but separate from, the actual certificate database.

Catamaran supports multiple certificate authorities, and gives each one an ID. This is a small text string, chosen by you, that's substituted into folder names and OpenSSL config keys. Most scripts will default this to `ca`, but if you have multiple coexisting certificate authorities, you may want to choose something more descriptive.

## Requirements

You will need installed:

- OpenSSL 3.x
- Bash
- Ruby 2.x, with ERB

## Installation

You will need to follow this section once.

- Create a folder to hold your CA info.
- Under it, create two more folders, `db` and `scripts`. Check out this repo into `scripts`. `db` will hold the data for all CAs you have under a single hierarchy; this name is in no way special, and you can rename it, or make multiple of these if you want multiple separate CA groups.
- Open `openssl.cnf.erb` in a text editor. Adjust the intermediate CAs in the `cas = [` array to match your needs; comment them out if you don't want intermediate CAs at all.
- Run `erb -T - root_ca={put your root CA ID here} > ../db/openssl.cnf` to generate a config file. (Unlike every command before and after this, this handles all CAs in a hierarchy at once.)

I would not recommend manually changing `openssl.cnf` after it's created; this is an easy way to make load-bearing alterations that get accidentally lost forever.

## Preparing the environment

You should follow this every time you open a shell to make data under your CA.

- Open a Bash shell and make `scripts` the working directory.
- Add the repo root to your PATH: `export PATH="$(pwd):$PATH"`
- `cd` to your database folder, where `openssl.cnf` is.

## Creating CA data

Follow this to create the key, cert and data folder for each CA. You will need to already have an `openssl.cnf` with the correct contents for each CA; you will need to remake that if you add a new intermediate CA.

### Root CA

- Run `[CA_SERIAL={serial here}] init-ca.sh ../db/<ID of your CA>` for all CAs you want to make. This creates a file/folder structure under `<CA ID>.db` that `openssl ca` will be happy with. Pre-setting `CA_SERIAL` is optional; see the comment block inside `init-ca.sh` to learn why you might want to do this.
- Create a keypair for your root CA: `make-ca-key.sh {CA ID} [rsa]`. You'll be prompted for a password for encrypting the private key; use something **strong** and store it in a password manager. If the second argument is `rsa`, it will make a 4096-bit RSA key (slower, worse, but more compatible); if not, it will default to an ECDSA key with the secp384r1 curve (faster, better, but less compatible with older systems). Consider that some systems [will reject](https://stackoverflow.com/a/47881232) certificates with ECDSA keys that are signed by certificate authoritites with RSA keys; I have seen this myself. The other way round is fine.
- Open `make-ca-cert.sh` and alter the `subj` calls to give your root CA the _Distinguished Name_ you want it to have. `CN` (Common Name) and `O` (Organisation) are required here, but everything else is optional.

You will now have an encrypted private key, a self-signed certificate, and an empty data folder ready to do some Signing.

### Intermediate CAs

Optionally, you can also set up intermediate certificate authorities with Catamaran. Most orgs use intermediate CAs to reduce exposure to the root CA private key. Server-specific certificates are signed by the intermediate CA instead, and its certificate is also presented to the user by the relevant server. This means the end user's system only needs to have the root CA cert pre-installed, which is less logistical hassle for everyone involved.

The reasons why you, as a Catamaran user, would want to use an intermediate CA, is probably for one of these two reasons:

- Showing off.
- Providing a good validation of this new link in the system trust chain.
- Adding optional [name constraints](https://timothy-quinn.com/name-constraints-in-x509-certificates/), so that trusting your root CA is less risky (e.g. more difficult to make a local arbitrary certificate for your bank, and other no-nos. The above point about reducing exposure to the root CA key is also relevant here.

Adding your own intermediate CAs will require changes to the `make-inter-cert.sh` script:

- Like with the root CA, alter the `subj` calls to match your needs. The `subj O` **must** match the root CA, and `subj CN` **must** be present and should be first. All other values can be changed or removed, and you can add your own.
- Alter the calls to `make_inter` at the bottom of the script. Each call defines a single intermediate CA, and the `CUSTOM_EXTENSION` variable, if set, can add one arbitrary extension to the certificate. The default values show what adding name constraints looks like (99% of the syntax is `openssl`'s design).

Once that's done:

- Make keys for your intermediate CAs. You do this with `make-ca-key.sh`, and the syntax and steps are exactly the same as they were for the root CA. Again, use **strong** passwords, which are **different from the root key password** and kept in a password manager.
- Run `make-inter-cert.sh {root CA ID}` to generate certificates for your intermediate CAs, each signed by the root CA. You will be prompted for the root CA password.

### Trust time!

- Import the root CA certificate (**not the key**) into your system's certificate store. For Windows, this should be the _Third-Party Root Certification Authorities_ at machine level (run `certlm.msc` to open this). For MacOS, the _System_ keychain is where you should import it; override the trust level for _Basic X.509 Policy_ to _Always Trust_.
- Import any intermediate CA certificates you have (again, **not the keys**). For Windows, use the _Intermediate Certification Authorities_ store to avoid automatically trusting the cert (that's what the trusted root CA cert is for). For MacOS, import the certificate to the _System_ keychain as before, but do not override any of the trust levels.

Verify that your system considers the intermediate certificate valid. If it does, this shows that your homegrown link in the system's trust chain is working.

> Theoretically, you don't need to import an intermediate cert this way; the server in question for the leaf certificate will offer up its intermediates as well. However, as well as providing proof that things are working as intended, this also works around an issue you might have where server software does not let you specify a second certificate to include in the TLS handshake, so the system needs to know about it ahead of time. The [IPMI firmware](https://en.wikipedia.org/wiki/Intelligent_Platform_Management_Interface) on my NAS mainboard is one such case I have.

## Creating leaf certificates

Let's make some actual certificates for actual things now.

The script `new-cert.sh` makes a leaf certificate for a server/domain. It takes the following parameters:

- The ID of the CA to use, which should be one of your intermediates, if you have them;
- The site domain, which should be fully qualified;
- The string `rsa`, if you want an RSA key and signature; omit it, or set it to anything else, to default to an ECDSA key.

Other elements of the final certificate's distinguished name can only be set by altering the script itself. `subj O` must match the signing certificate, and `subj CN` should be left as-is. All others can be changed.

You will be prompted for the password of the signing CA's key. Running this will create the following files:

- `site_{domain}.key`, which is the server's private key in PEM (plaintext) format. This file is unencrypted; you are encouraged to encrypt it in a way that makes sense for your application.
- `site_{domain}.pem`, a signed certificate in PEM format. `openssl` will also add a human-readable dump of the certificate contents above the header; this is technically fully standards-compliant, but you may want to remove it.

`openssl ca` also saves the generated certificate in its own "database" folder, under `{CA ID}.db/newcerts/{serial}`. The Catamaran script will print out the value of `{serial}` that was used here; look for the line starting `+ CUR_SERIAL=`. The `index` file is a TSV-format text file summarising every signed certificate, and the serial it was given.

# Not currently supported

- CRL or OCSP
- Signing SSH keys

