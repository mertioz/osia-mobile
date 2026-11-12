# Security Policy

## Supported versions

Until OSIA publishes versioned releases, security fixes are provided only for the
latest commit on the default branch. Older commits and private forks are not
supported.

## Reporting a vulnerability

Do not open a public issue, discussion, or pull request containing a
vulnerability, credential, token, private key, user data, or reproduction that
would expose one.

Use GitHub private vulnerability reporting when available. Otherwise, email
contact@osia.space privately with a minimal, redacted description. Never place
credentials or user data in a public issue or pull request. OSIA does not
currently claim a bug-bounty program.

Include the affected component and a minimal reproduction, but replace every
credential and user record with a non-secret synthetic value.

## Credential response

Treat a committed credential as compromised even after deleting it from the
current tree. The safe order is:

1. revoke or rotate the credential;
2. freeze repository writes and coordinate with every collaborator;
3. rewrite a fresh mirror with `git-filter-repo`;
4. rescan the rewritten mirror with both Gitleaks and the OSIA scanner;
5. force-push all rewritten branches and tags only after explicit approval;
6. invalidate old clones, forks, caches, artifacts, and release archives.

Never paste the credential into an issue, commit message, shell history, or scan
report. Keep replacement material outside the repository and delete it after
validation.

## Local secret scanning

The repository scanner requires Gitleaks **8.30.1** exactly. Install the official
release outside the repository, verify its published SHA-256 checksum, and set
`GITLEAKS_BIN` if it is not on `PATH`.

Run before every commit:

```text
python scripts/scan_secrets.py
python scripts/test_security_policy.py
```

To audit every locally reachable branch and tag:

```text
python scripts/scan_secrets.py --history
```

Scanner output is intentionally sanitized: it reports only rule, path,
commit/date metadata, and an identifier derived from that metadata—not the
matched value.

## Repository and hosting controls

Enable GitHub secret scanning and push protection when the repository becomes
public. Keep workflow permissions read-only unless a documented job requires
more. Third-party Actions must be pinned by full commit SHA.

## Local secret storage

OSIA Mobile stores tokens and pairing state with platform secure storage.
Android signing files, `local.properties`, `key.properties`, keystores, iOS
provisioning profiles, export options, service configuration, `.env` files,
device logs/screenshots, and secure-storage exports are local and ignored.
Never pass production secrets through tracked Dart constants or committed build
defines.
