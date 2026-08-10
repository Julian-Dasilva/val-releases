# Engagement access — issuing and revoking

How a client team installs `val`, and how their access ends when the engagement
does.

## The model

**Updates are gated. Installed versions are not.**

Each engagement gets its own access token. While it is valid, that team installs
and upgrades normally. When the engagement ends the token is revoked or expires,
and they stop receiving new versions.

They keep whatever they already installed, and it keeps working. Installed
releases live in immutable content-addressed slots under their own data home;
nothing phones home, nothing expires, and this repository is never contacted at
run time. That is deliberate — a departed client is not left with a tool that
stops working, only one that stops changing.

There is no license check and no kill switch. If you ever need to stop a departed
team from *running* val, that is a different mechanism and it does not exist today.

## Issuing access for a new engagement

1. github.com → Settings → Developer settings → Personal access tokens →
   **Fine-grained tokens** → *Generate new token*
2. **Token name:** `val-dist-<engagement>` — the name is how you find it later, so
   make it unambiguous.
3. **Resource owner:** `Julian-Dasilva`
4. **Repository access:** *Only select repositories* → **this repository only**.
   Never include the source repository.
5. **Permissions → Repository permissions → Contents: Read-only.** Nothing else.
6. **Expiration: set it to the expected engagement end date.**

Step 6 is the important one. An expiry dated to the engagement means access
self-terminates even if offboarding is missed. Renewing a token for an extended
engagement is a minute of work; discovering a year later that a finished client
still pulls releases is not.

Record the token name, engagement, and expiry wherever you track engagement
assets.

## What the client runs

```sh
export VAL_TOKEN=<their-token>
curl -fsSL -H "Authorization: Bearer $VAL_TOKEN" \
  https://raw.githubusercontent.com/Julian-Dasilva/val-releases/main/install.sh \
  | bash
```

Or pin a version:

```sh
VAL_TOKEN=<token> bash install.sh --version 0.1.5
```

The token can also be passed as `--token`. Tell them to put `VAL_TOKEN` in their
shell profile or CI secret store, not in a committed file.

`VAL_TOKEN` is also read by the toolchain wrappers that install Val from a
consuming repository, so one variable covers both the bootstrap script and those.

## Internal tokens

Tokens for your own tooling are the deliberate exception to the expiry rule. Name
them `val-dist-<system>` and set **no expiration** — there is no offboarding date,
and an expiry that lapses silently breaks your own pipelines for no security gain.

Everything else is unchanged: fine-grained, Contents: Read-only, this repository
only, never the source repository. Keep the naming distinct so an internal token
is never mistaken for a consumer one during offboarding.

## Offboarding

1. Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Find `val-dist-<engagement>` → **Delete**

Effective immediately. Their next install or upgrade fails with a message saying
the token may have been revoked and that installed versions keep working.

Nothing else is required. Do not delete releases — that would break other
engagements pulling the same versions.

## Why not a shared token

One token per engagement is what makes revocation surgical. A shared token means
offboarding one client forces every other client to re-key. The cost of separate
tokens is a naming convention; the cost of a shared one is a migration every time
someone leaves.

## Limits worth knowing

- **Tokens are bearer credentials.** Anyone holding one can download releases.
  They are not per-person and downloads are not attributable to individuals. If
  you need per-seat audit, that needs a package registry with entitlement tokens,
  not this.
- **Revocation stops downloads, not possession.** A team that mirrored the
  artifacts before leaving keeps them. Gating a download has never prevented that;
  only a runtime entitlement check would, and there isn't one.
- **All engagement tokens are issued from one account.** A leaked token exposes
  read access to this repository and nothing else — no source, no other repo.
  That is the intended blast radius, but it is worth being deliberate about.
