# Security review of Kranox 0.3.1

Scanned with [repo-security-review](https://github.com/Consensys/repo-security-review), a skill of Consensys, on
8 Oct 2026, at the commit [`56d16b3`](https://github.com/Kranox-Labs/Kranox/tree/56d16b3f5dc10cc51b93fc0f500c5eb808c66587)
of the wallet and the commit
[`ef0cdc5`](https://github.com/Kranox-Labs/Relay/tree/ef0cdc56513201948b3e8b53c68108d6b7cf15a7) of the relay. Not an
audit by Consensys.

This report covers the second security review of the Kranox wallet 0.3.1 beta for macOS and of its relay. Claude ran
the skill in Claude Code and wrote every finding. No person at Consensys or at another firm read the code. The skill
calls itself experimental, and its repository has no license.

After you read this report, you know what the review covered, what it found, and what comes next. The report of the
first review, of Kranox 0.2.0, is [security-review-0.2.0.md](security-review-0.2.0.md).

## Scope

| Part | What the review read | Version |
|---|---|---|
| Wallet app | This repository | Kranox 0.3.1 beta: the commit `56d16b3`, the tag `v0.3.1` |
| Relay | [Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay) | The commit `ef0cdc5`, which the relay runs from 8 Oct 2026 |

The review left out the setup of the server, with its nginx and systemd files, because no repository holds it. It also
left out the site, ChangeNOW, Alchemy, Blockscout, and the inside of the Monero library `monero_c`.

## Method

The skill ran at its commit `4cc854c` of 27 Sep 2026, in its mode for more than one repository, with its default
flags. So the review read code and ran tools. It built no exploit, ran no proof of concept, and sent no request to a
live service.

Each phase ran as its own agent in Claude Code, 16 agents in all. Phase 2 ran on Claude Opus at high effort, and the
other phases ran on Claude Sonnet at medium effort.

| Phase | What it did |
|---|---|
| 0. Services | Mapped the wallet, the relay, and the calls between them. |
| 1. Secrets | Scanned the files and the history of each repository with gitleaks. |
| 2a. Stack | Found the languages, the frameworks, and the packages of each repository. |
| 2. Architecture | Read the design of each repository for weak points of trust. |
| 3. Dependencies | Scanned the packages for known CVEs with osv-scanner 2.6.0. |
| 4. Code | Reviewed the code against the lists of OWASP, with the rules of Semgrep 1.179.0 as a start. |
| 5. Validation | Checked each finding again from the start, and gave it a verdict. |
| 6. Report | Wrote the report of each repository. |
| 7. System | Joined the two repositories, and reviewed the contract between them. |

A finding is "confirmed" when the code alone shows it. A finding "needs review" when it is real or likely, but its
proof sits outside the two repositories, or a check of the skill lowered its confidence.

No code left the computer that ran the review. osv-scanner sent the names and the versions of the packages to osv.dev.
Semgrep fetched its rules from its registry, with its metrics off.

## Summary

The review found 17 distinct findings: 9 Medium, 7 Low, and 1 without a severity. Nothing is Critical or High.

- Neither repository holds a secret or a package with a known CVE. The wallet has 63 packages. The relay has 99, all of
  them for development, because the relay has no runtime dependency.
- No finding lets an attacker on the internet take funds or keys from a wallet.
- Most findings are about privacy: what the relay, a network, or a copy of the files of the app can learn.
- 9 findings are new. The other 8 were known from the first review, or are choices of the design.

| Severity | Found | New | Known |
|---|---|---|---|
| Critical | 0 | 0 | 0 |
| High | 0 | 0 | 0 |
| Medium | 9 | 4 | 5 |
| Low | 7 | 5 | 2 |
| No severity | 1 | 0 | 1 |
| Total | 17 | 9 | 8 |

On 9 Oct 2026, no new finding is fixed yet. When a fix ships, this report names its commit and its release.

## Findings

"Relation" compares each finding with the report of the first review. The skill numbers the findings of each
repository on its own, so the wallet and the relay both have an O-001.

### Wallet

| ID | Severity | Verdict | Finding | Relation | Status |
|---|---|---|---|---|---|
| O-001 | Medium | Confirmed | The app reaches the relay without the proxy of Settings | New | Open |
| O-003 | Medium | Confirmed | The signature of an answer does not bind the request | New | Open |
| O-007 | Medium | Confirmed | The file of the swaps is not encrypted | New | Open |
| O-004 | Low | Confirmed | One round of the KDF, and a password of 8 characters | New | Open |
| O-002 | Medium | Needs review | The link to the node is not encrypted | Same as K-11 | Open, as K-11 |
| O-005 | Medium | Needs review | Library validation is off, and the app has an ad hoc signature | Same as K-13 | A choice |
| O-006 | Low | Needs review | The app reads an answer of the relay without a size limit | New | Open |
| A-007 | None | Needs review | Neither repository shows how the prebuilt Monero library was built | Known | Known |

### Relay

| ID | Severity | Verdict | Finding | Relation | Status |
|---|---|---|---|---|---|
| O-001 | Medium | Needs review | A swap reads without its token | Same as K-18 | Open, as K-18 |
| O-002 | Medium | Needs review | All users share one budget of calls to ChangeNOW | Same as K-04 | Limited on the server |
| O-003 | Medium | Needs review | A scan spends paid calls to the explorer | Same as K-04 | Limited on the server |
| O-004 | Medium | Needs review | The signature leaves out the status, the method, and the path | New | Open |
| O-005 | Low | Needs review | Two calls carry the partner key in the URL | New | Open |
| O-006 | Low | Needs review | Addresses from Alchemy go into a URL without encoding | New | Open |
| O-007 | Low | Needs review | The relay records no security event | A choice | A choice |
| O-008 | Low | Needs review | A flood of keys can push out the idempotency key of a user | New, next to K-14 | Open |
| A-006 | Low | Needs review | The relay serves plain HTTP behind a proxy that no repository defines | Known | Known |

### Across the two

| ID | Severity | Finding | Same as |
|---|---|---|---|
| SYS-001 | Medium | The app treats the signature as proof of an answer to its own request, but the relay signs only the nonce and the body | Wallet O-003 and relay O-004 |
| SYS-002 | Medium | The app sends a read token that the relay does not require | Relay O-001, K-18 |
| SYS-003 | Medium | The proxy of Settings covers only the link to the node | Wallet O-001 |
| SYS-004 | Medium | All wallets share one budget of calls through the relay | Relay O-002, K-04 |

These four findings repeat findings of the wallet and the relay, so the count of 17 leaves them out.

## Details of each finding

Paths of the wallet point at this repository. Paths of the relay point at
[Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay).

### Wallet O-001: the app reaches the relay without the proxy of Settings

- **Severity:** Medium. **Verdict:** confirmed. **Status:** open.
- **What happens:** the proxy in Settings, such as Tor, carries the traffic to the node only. The client of the relay
  in `lib/bridge/client.dart` connects straight, for quotes, swaps, payments, and scans.
- **Impact:** with Tor set, the relay and Cloudflare still see the IP address of the Mac. They see it next to the
  addresses and the amounts of each swap, and next to each address that you scan. Funds are not at risk.
- **Plan:** send the calls to the relay through the same proxy.

### Wallet O-003: the signature of an answer does not bind the request

- **Severity:** Medium. **Verdict:** confirmed. **Status:** open.
- **What happens:** the relay signs the nonce of the request and the body of the answer, and the app checks that
  signature in `lib/bridge/relay_signature.dart`. The signature leaves out the method, the path, and the request
  itself. The app does not compare the id and the refund address of a new swap with what it sent.
- **Impact:** a party that can already intercept TLS on the Mac, such as a company proxy with its own certificate,
  could give the app a signed answer that belongs to another request. The checks of the recipient, the amount, and
  the deposit address still hold, so a payment still goes to its recipient. The refund of a failed swap could go to
  that party. Without an interception of TLS, nobody can use this finding.
- **Plan:** sign the status, the method, the path, and a hash of the request together with the nonce. The app then
  also compares the id and the refund address of each new swap with what it sent.

### Wallet O-007: the file of the swaps is not encrypted

- **Severity:** Medium. **Verdict:** confirmed. **Status:** open.
- **What happens:** `bridge.json`, in the folder of the app, keeps each swap: its id and its read token, the
  addresses, the amounts, and the transaction hashes. The password of the wallet does not protect this file, and the
  file stays readable while the wallet is locked.
- **Impact:** malware that runs as the user, a backup, or a disk without FileVault can read the swaps. The swaps link
  the wallet to addresses on Robinhood Chain. A read token shows the state of its swap, and it cannot move funds.
- **Plan:** encrypt the file with a key from the password of the wallet, or at least give the file permissions for
  its owner only.

### Wallet O-004: one round of the KDF, and a password of 8 characters

- **Severity:** Low. **Verdict:** confirmed. **Status:** open.
- **What happens:** wallet2 stretches the password of the keys file with one round of its key function, which is its
  default. A password needs 8 characters only (`lib/config/app_config.dart`).
- **Impact:** a person with a copy of the keys file can test passwords offline, at a low cost for each guess. With
  the right password, that person can spend the funds. A long password protects a copied file, and a short one does
  not.
- **Plan:** more rounds for new wallets, and a longer minimum for the password. Until then, choose a long password,
  such as a phrase of several random words.

### Wallet O-002: the link to the node is not encrypted

- **Severity:** Medium. **Verdict:** needs review. **Status:** open, as K-11.
- **What happens:** the app talks to its node over plain RPC. A proxy such as Tor hides the IP address of the Mac
  from the node and from the local network.
- **Impact:** an observer of that link can see the traffic, and can change the answers of the node. The app does not
  trust the node, and it stops a payment with a network fee above 0.01 XMR, so a changed answer can do little.
- **Plan:** as in K-11 of the first review. The Monero library that the app ships accepts any certificate, so SSL
  would add no real protection. Tor or a node of your own protects this link.

### Wallet O-005: library validation is off, and the app has an ad hoc signature

- **Severity:** Medium. **Verdict:** needs review. **Status:** a choice, as in K-13.
- **What happens:** the release build runs with the hardened runtime and in the sandbox of macOS, but with library
  validation off. The app carries an ad hoc signature, without a Developer ID and without a notarization by Apple.
- **Impact:** malware that can already write into the app could replace the Monero library with its own. That
  library sees the password and the seed. Such malware already runs code as the user.
- **Plan:** library validation stays off, so that you can replace the Monero library, as the LGPL-3.0 allows. A
  Developer ID and a notarization need an Apple Developer account. Until then, check each download with `hashes.txt`
  and the release key, as [Check the download](../README.md#check-the-download) shows.

### Wallet O-006: the app reads an answer of the relay without a size limit

- **Severity:** Low. **Verdict:** needs review. **Status:** open.
- **What happens:** the app reads the whole answer of the relay into memory before it checks the signature
  (`lib/bridge/client.dart`). Only the timeout of 30 seconds limits the read.
- **Impact:** a party that controls the connection to the relay could send a very large answer, and make the app slow
  or stop it. No data leaks, and funds are not at risk.
- **Plan:** a cap on the size of an answer, such as 1 MB.

### Wallet A-007: neither repository shows how the prebuilt Monero library was built

- **Severity:** none. **Verdict:** needs review, from Phase 7. **Status:** known.
- **What happens:** the app ships the prebuilt library of [monero_c](https://github.com/MrCyjaneK/monero_c)
  `v0.18.4.6-RC2`. The review cannot tie that file to its source.
- **What protects it:** `tool/fetch_monero_c.sh` checks the SHA-256 of the file, so the script refuses a file that
  changed upstream. The LGPL-3.0 lets you build the library yourself and replace the file.
- **Plan:** none for now.

### Relay O-001: a swap reads without its token

- **Severity:** Medium. **Verdict:** needs review. **Status:** open, as K-18.
- **What happens:** the relay checks the read token of a swap only when a request carries one, so that the apps
  before 0.3.1 keep following their swaps (`src/server.mts`).
- **Impact:** a person who holds the id of an exchange can read the stage, the amounts, and the transaction hashes of
  its swap, without its addresses. The hashes can tie the XMR of the swap to its payout on Robinhood Chain. The ids
  are random, so a guess is not practical.
- **Plan:** as in K-18 of the first review. The relay will refuse a read without a token once the apps before 0.3.1
  are gone.

### Relay O-002: all users share one budget of calls to ChangeNOW

- **Severity:** Medium. **Verdict:** needs review. **Status:** limited on the server, as K-04.
- **What happens:** every route of the relay draws from one budget of calls to ChangeNOW, and the relay itself has no
  limit for each client (`src/changenow.mts`).
- **Impact:** without other limits, one client could use up the budget, and quotes and swaps would fail for every
  user.
- **Why it needs review:** the limits for each client sit in the setup of the server, which no repository holds. The
  server limits every route for each client, with tighter limits for creations and for scans, as K-04 of the first
  review describes.

### Relay O-003: a scan spends paid calls to the explorer

- **Severity:** Medium. **Verdict:** needs review. **Status:** limited on the server, as K-04.
- **What happens:** a scan of a new address makes several calls to the explorer of Robinhood Chain, and the calls
  spend paid credits (`src/blockscout.mts`). The relay keeps the result for each address in a cache.
- **Impact:** without other limits, one client could scan many addresses and use up the credits of the day, and scans
  would fail for every user.
- **Why it needs review:** the server gives scans their own limit for each client, and no repository holds that
  setup.

### Relay O-004: the signature leaves out the status, the method, and the path

- **Severity:** Medium. **Verdict:** needs review. **Status:** open.
- **What happens:** the relay signs the nonce and the body of each answer, not the status code, the method, or the
  path (`src/signing.mts`). A request without a nonce, as from an app before 0.3.1, gets an answer signed over an
  empty nonce.
- **Impact:** this finding is the relay side of wallet O-003. An answer signed over an empty nonce could also answer
  another request without a nonce. The app 0.3.1 always sends a nonce of its own, so it refuses such an answer.
- **Plan:** sign the status, the method, the path, and a hash of the request together with the nonce. Once the apps
  before 0.3.1 are gone, refuse a request without a nonce on the routes that create exchanges.

### Relay O-005: two calls carry the partner key in the URL

- **Severity:** Low. **Verdict:** needs review. **Status:** open.
- **What happens:** two calls to version 1 of the API of ChangeNOW carry the partner key in the query string, next to
  the header that also carries it (`src/changenow.mts`).
- **Impact:** URLs often go into the logs of a server. A person who reads such logs at ChangeNOW, or at a proxy on the
  way, could use the key and its budget. Funds are not at risk.
- **Plan:** the key in the header only, if version 1 of the API accepts it there.

### Relay O-006: addresses from Alchemy go into a URL without encoding

- **Severity:** Low. **Verdict:** needs review. **Status:** open.
- **What happens:** for the names of the addresses in a scan, the relay asks the metadata service of Blockscout. It
  joins the addresses from the answers of Alchemy into that URL, without a check of their form and without encoding
  (`src/alchemy.mts`).
- **Impact:** only a compromised Alchemy could use this finding, and only to change the names that a scan shows. The
  host and the path of the URL are fixed.
- **Plan:** keep only addresses of `0x` and 40 hex digits, and build the query with `URLSearchParams`.

### Relay O-007: the relay records no security event

- **Severity:** Low. **Verdict:** needs review. **Status:** a choice.
- **What happens:** the relay writes no log. A refusal, a spent budget, or an exchange that fails its checks leaves no
  record.
- **Impact:** the operator of the relay cannot see abuse, or a fault of ChangeNOW, from the relay.
- **Why it stays:** the relay keeps no log of a request, so that it holds nothing about its users. Counts without any
  data of a request can come later.

### Relay O-008: a flood of keys can push out the idempotency key of a user

- **Severity:** Low. **Verdict:** needs review. **Status:** open.
- **What happens:** the relay keeps the idempotency keys of 2,000 creations for 10 minutes. Above 2,000, it drops the
  oldest key, also when that key has not expired (`src/creations.mts`).
- **Impact:** a flood of creations could push out the key of a user before the retry of that user, so the retry makes
  a second exchange. The app pays only the exchange whose answer it has, so the first exchange gets no funds. Each
  creation of the flood needs a valid request, and it makes a real exchange within the limits of the server.
- **Plan:** drop the expired keys first, and keep more keys.

### Relay A-006: the relay serves plain HTTP behind a proxy that no repository defines

- **Severity:** Low. **Verdict:** needs review, from Phase 7. **Status:** known.
- **What happens:** the relay listens for plain HTTP on the loopback address of the server. nginx and Cloudflare end
  TLS in front of it, and no repository holds their setup.
- **Impact:** the review could not check TLS, the limits, or the timeouts on the path to the relay.
- **What protects it:** Cloudflare connects to the server in its mode "Full (strict)", and the server takes requests
  for the relay only from Cloudflare, as K-03 of the first review describes. A release of the app talks to the relay
  over HTTPS only.

## Limits of the review

- The review read code and ran tools only. It built no exploit, ran no proof of concept, and tested no live service.
- The review could not see the setup of the server, so the findings on limits, TLS, and timeouts rest on the code
  alone.
- osv-scanner does not cover `monero_c`, because the app takes it from a commit in git and from a release, not from a
  registry of packages.
- Static rules can miss a flow of data across files. A clean result means that the review found no issue, not that no
  issue exists.
- gitleaks found one candidate in the relay, a public address in a test. The review ruled it out as a secret.
