Configuration-as-Code project for HashiCorp Vault instance
==========================================================

Configure [HashiCorp Vault](https://www.vaultproject.io/) instance
with yaml files. Keep configuration under version control system.

- Initialize new vault instance;
- Unseal existing instance (master key shares should be provided with
  `VAULT_SECRET_KEYS` envvar);
- Reconfigure existing instance (root token should be provided with
  `VAULT_TOKEN` envvar);

Do not place here unencrypted secrets! If you want to manage secrets under version control, you can use:

- [Git-crypt](https://github.com/AGWA/git-crypt)
- [BlackBox](https://github.com/StackExchange/blackbox)
- [SOPS](https://github.com/mozilla/sops)
- [Transcrypt](https://github.com/elasticdog/transcrypt)


