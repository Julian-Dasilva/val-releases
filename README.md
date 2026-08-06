# val — releases

Signed binary releases for the `val` runner. The source repository is private;
this repository holds release artifacts only.

Every artifact here is signed with a detached minisign (Ed25519) signature over a
release manifest, and every byte is digest-pinned. The installer verifies the
signature and every digest **before any artifact byte executes**. Nothing here
requires an account, a token, or repository access.

## Trust anchor

Pin this key. It is the one thing you commit and the one thing you verify
out-of-band. Everything else — version, digests, sizes, URLs — is resolved and then
checked against it.

```
key_id:     5A1B6A28FDC535FF
public key: RWT/NcX9KGobWpwGVQ92bSiTIEiAOV0kCWm7k9PdnmS+viv8LFT9emQP
```

If a download ever presents a different key id, stop. Do not install it.

## Supported hosts

| Host | Target triple |
|---|---|
| macOS arm64 | `aarch64-apple-darwin` |
| Linux x86_64 | `x86_64-unknown-linux-gnu` |

Anything else fails closed. There is no emulation flag.

## Install

You need `bash`, `python3` (3.11+), `tar`, and `zstd`. No `git`, no `gh`, no
credentials.

Download `val-install-assets-vX.Y.Z.tar.zst` from the release you want, extract it,
and run the bundled installer against its bundled lock:

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
