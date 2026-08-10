# val — releases

Signed binary releases for the `val` runner. The source repository is private;
this repository holds release artifacts only.

Every artifact here is signed with a detached minisign (Ed25519) signature over a
release manifest, and every byte is digest-pinned. The installer verifies the
signature and every digest **before any artifact byte executes**.

This repository is public. Installing needs no account and no token — just the
tools listed below.

## Trust anchor

```
key_id:     5A1B6A28FDC535FF
public key: RWT/NcX9KGobWpwGVQ92bSiTIEiAOV0kCWm7k9PdnmS+viv8LFT9emQP
```

Confirm these values through a channel other than this repository before relying on
them, and stop if a download ever presents a different key id.

**Be aware of what the installer does and does not enforce.** It reads the signing
key from the release lock and checks that the lock is internally consistent. It has
no option for you to supply an expected key, so it cannot detect a lock that carries
a *different but self-consistent* key. Comparing the key above against what a release
actually ships is currently a manual step, and it is on you. An out-of-band key
parameter is planned.

## Supported hosts

| Host | Target triple |
|---|---|
| macOS arm64 | `aarch64-apple-darwin` |
| Linux x86_64 | `x86_64-unknown-linux-gnu` |

Anything else fails closed. There is no emulation flag.

## Read this before installing

**The installer bundle is not signed.** `val-install-assets-vX.Y.Z.tar.zst` contains
`install-val.sh` — the program that performs every signature and digest check
described below — but the signed manifest covers only the two target archives, not
this bundle. It appears in `SHA256SUMS`, and **that file is unsigned too**.

So the first download is a **trust bootstrap**, not a verified step. If these bytes
were replaced, you would be running the attacker's verifier, and everything it told
you afterwards would be worthless.

Before extracting, confirm the bundle's SHA-256 through a channel **other than this
repository** — ask the maintainer directly. Do not trust a digest published beside
the artifact it claims to authenticate.

```sh
shasum -a 256 val-install-assets-vX.Y.Z.tar.zst   # or: sha256sum
```

Everything after that point *is* cryptographically verified: the installer checks the
detached minisign signature and every digest before any artifact byte executes. The
gap is the bootstrap, and it is being closed — the bundle will be bound into the
signed manifest.

## Install

```sh
curl -fsSL \
  https://raw.githubusercontent.com/Julian-Dasilva/val-releases/main/install.sh \
  | bash -s -- --version 0.1.6
```

Omitting `--version` installs the newest release, but see the selection caveat
below — pinning is recommended.

Needs `bash`, `python3` (3.11+), `tar`, `zstd`, and `curl`. The binary lands at
`~/.local/bin/val` — put that on your `PATH`. Override with `--bin-home`,
`--data-home`, `--val-home`.

The script only acquires bytes. All verification is done by the release's own
bundled installer: detached minisign signature over the release manifest, every
digest and size binding, and a mandatory `val doctor` gate before the selector
moves.

**Version selection is not authenticated.** Without `--version` the script asks
GitHub for the newest tag over plain HTTPS, and that answer is not signed. An
origin able to lie about the tag list could steer you to an older — validly
signed — release. Pass `--version` to remove that exposure. Signed release
selection is not implemented yet.

Piping a script from the network into `bash` is itself a trust decision. If you
would rather not, download `install.sh`, read it, and run it locally — it is
short and does nothing clever.

### Staying updated

From v0.1.6, `val update` is the consumer update path. Write `~/.val/update.toml`
once:

```toml
schema = "val-update-config.v1"
default_channel = "public"

[channels.public]
kind = "github-release"
repo = "Julian-Dasilva/val-releases"
```

— then `val update` (or `val update --version vX.Y.Z` to pin). It verifies
signatures before a single byte executes and never builds from source. Binaries at
v0.1.5 or older need one manual install of v0.1.6 first.

### Manual install

Extract the bundle and run its installer directly:

```sh
zstd -d -c val-install-assets-vX.Y.Z.tar.zst | tar -xf -
cd val-install-assets-vX.Y.Z

bash install-val.sh install \
  --lock       ./val-release-lock.toml \
  --data-home  "${XDG_DATA_HOME:-$HOME/.local/share}" \
  --bin-home   "${XDG_BIN_HOME:-$HOME/.local/bin}" \
  --val-home   "${VAL_HOME:-$HOME/.val}" \
  --receipt    ./val-install-receipt.json
```

On success the binary is at `<bin-home>/val` and the receipt records every verified
binding. Make sure `<bin-home>` is on your `PATH`.

## What the installer guarantees

These hold **once you are running an authentic `install-val.sh`** — see the bootstrap
caveat above. They are properties of the installer, not of your having obtained it.

1. Validates the lock's shape and refuses credentials, private URLs, mirrors, and
   floating `latest`/`stable` aliases.
2. Verifies the manifest digest, the key id agreement across lock ↔ manifest ↔
   public key, and the detached signature.
3. Verifies bindings in order: version, commit, target, artifact URL, recipe-catalog
   digest, receipt-schema digest, registry contract, artifact hash, artifact size.
4. Stages one immutable content-addressed slot, outside your `VAL_HOME`, so prior
   verified versions stay installed side by side.
5. Runs `val doctor --json` as a mandatory health gate. The selector only moves after
   doctor passes — there is no skip and no environment escape.

Exit codes are part of the contract:

| Code | Meaning |
|---|---|
| `0` | verified, staged, selected, doctor passed |
| `10` | verified + staged, but doctor was unavailable or not-ready; slot retained, selector unchanged |
| `11` | clean input but no detached signature |
| `20` | refused before any execution |
| `2` | usage error |
| `3` | environment precondition failure |

Route on the exit code and the receipt's `outcome` field — never on stdout text.

## Verifying without installing

To check a signature without staging or executing anything:

```sh
bash install-val.sh --list-refusals
bash install-val.sh --list-exit-codes
bash install-val.sh --list-bindings
bash install-val.sh --list-targets
```

## Reporting problems

Issues for the engine live in the private source repository. If you do not have
access there, contact the maintainer directly.
