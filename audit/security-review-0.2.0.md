# Security review of Kranox 0.2.0

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 7 Oct 2026, at the commit
[`10bc27f`](https://github.com/Kranox-Labs/Kranox/tree/10bc27fa88236f17d244837c7678036132080247) of the wallet.
Not an audit by Trail of Bits.

This report covers a security review of the Kranox wallet 0.2.0 for macOS and of its relay. Claude ran the skills
in Claude Code and wrote every finding. No person at Trail of Bits or at another firm read the code.

After you read this report, you know what the review covered, what it found, and what changed after it.

## Scope

| Part | What the review read | Version |
|---|---|---|
| Wallet app | `lib/`, `macos/`, `tool/`, and `pubspec.yaml` of this repository | Kranox 0.2.0: the commit `10bc27f`, the tag `v0.2.0` |
| Relay | `src/`, `package.json`, `.env.example`, and the TypeScript settings of [Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay) | The release that ran on 7 Oct 2026, before its fixes |
| Server of the relay | The setup of nginx and systemd | Not public |

The review left out the site, the tests of the app, and ChangeNOW itself. It read the Monero library `monero_c`
only where the app depends on its behavior.

## Method

The review ran in three stages. Each stage used one or more skills of the marketplace `trailofbits/skills`, at the
commit `82fe822` of 28 Sep 2026, under the license CC-BY-SA-4.0. Claude Code 2.1.292 ran them with the model
Claude Opus 5.5.

| Stage | Skill and version | What it did | Agents |
|---|---|---|---|
| 1. Map | `audit-context-building` 2.0.2 | Mapped 13 modules and 25 entry points, ranked 40 functions, and analyzed the 12 most important ones in depth. It names no bug. | 14 |
| 2. Hunt | `insecure-defaults` 2.0.3 | Swept 6 categories of insecure defaults. Of 84 candidates, its verifiers refuted 72 and confirmed 12, which make 8 distinct findings. | 16 |
| 2. Hunt | `sharp-edges` 1.1.3 | Looked for designs that make mistakes easy: one agent on the wallet (14 findings), one on the relay (9 findings). | 2 |
| 3. Verify | `fp-check` 1.0.5 | Verified the 3 High findings with the six gates of the skill. | 6 |

Claude merged the findings of stage 2, removed the ones that two skills reported twice, and checked each High
finding against the code itself before stage 3.

## Summary

The review found 24 distinct findings: 3 High, 10 Medium, and 11 Low.

- No finding lets a remote attacker take funds or keys from a wallet.
- The two High findings in the wallet could make a user lose money through ordinary actions: a payment that the
  app reported as failed, and a payment that differed from the one on the screen.
- The High finding in the relay let anyone use up the budget of the partner key of ChangeNOW, which stops the
  bridge for every user.

| Severity | Found | Fixed | Partly fixed | Open |
|---|---|---|---|---|
| High | 3 | 3 | 0 | 0 |
| Medium | 10 | 9 | 1 | 0 |
| Low | 11 | 10 | 1 | 0 |
| Total | 24 | 22 | 2 | 0 |

The first fixes of the wallet are in the commit [`b70aedb`](https://github.com/Kranox-Labs/Kranox/commit/b70aedb)
and ship in [Kranox 0.2.1 beta](https://github.com/Kranox-Labs/Kranox/releases/tag/v0.2.1). The rest, in the
commits [`76d2179`](https://github.com/Kranox-Labs/Kranox/commit/76d2179) and
[`aab392a`](https://github.com/Kranox-Labs/Kranox/commit/aab392a), ship in
[Kranox 0.3.1 beta](https://github.com/Kranox-Labs/Kranox/releases/tag/v0.3.1). The fixes of the relay are in
[Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay), and the relay runs all of them from 8 Oct 2026. Two
findings stay partly fixed, K-11 and K-18. A second review, of 0.3.1, ran on 8 Oct 2026 with another skill. It lists
K-11 and K-18 again, and it found a gap next to K-10:
[security-review-consensys-0.3.1.md](security-review-consensys-0.3.1.md).

## Findings

| ID | Severity | Finding | Part | Status |
|---|---|---|---|---|
| K-01 | High | A sent payment could come back as a failure | Wallet | Fixed in 0.2.1 |
| K-02 | High | Send and pay shared one built payment | Wallet | Fixed in 0.2.1 |
| K-03 | High | The rate limit of the relay took a key that the client chose | Relay | Fixed |
| K-04 | Medium | The rate limit could not protect the shared budget of the partner key | Relay | Fixed |
| K-05 | Medium | Any web page could create exchanges through the browsers of its visitors | Relay | Fixed |
| K-06 | Medium | Receive used the answer of ChangeNOW without a check | Relay and wallet | Fixed |
| K-07 | Medium | Failures on the screens that move money showed no message | Wallet | Fixed in 0.2.1 |
| K-08 | Medium | The deadline of a fixed rate failed open | Wallet | Fixed in 0.2.1 |
| K-09 | Medium | A damaged settings file or swap file stopped the app at start | Wallet | Fixed in 0.2.1 and 0.3.1 |
| K-10 | Medium | The relay alone decided where bridge money goes | Relay and wallet | Fixed in 0.3.1 |
| K-11 | Medium | Traffic to the node is not encrypted, and node fees had no limit | Wallet | Partly fixed in 0.3.1 |
| K-12 | Medium | The subaddress of a swap became the receive address on the screen | Wallet | Fixed in 0.2.1 |
| K-13 | Medium | The release build had no hardened runtime | Wallet | Fixed in 0.2.1 |
| K-14 | Low | Creating an exchange was not idempotent | Relay and wallet | Fixed in 0.3.1 |
| K-15 | Low | The relay passed raw error text of ChangeNOW to any caller | Relay | Fixed |
| K-16 | Low | `fetch` followed a redirect and kept the partner key | Relay | Fixed |
| K-17 | Low | The relay could print a misplaced key to the system log | Relay | Fixed |
| K-18 | Low | The id of an exchange alone read all details of a swap | Relay and wallet | Partly fixed in 0.3.1 |
| K-19 | Low | An amount of 0 meant "send the whole balance" | Wallet | Fixed in 0.2.1 |
| K-20 | Low | A very large amount broke the pay screen | Wallet | Fixed in 0.2.1 |
| K-21 | Low | The refund address of receive got no checksum check | Wallet | Fixed in 0.2.1 |
| K-22 | Low | The QR code of a receive deposit held a bare address | Wallet | Fixed in 0.3.1 |
| K-23 | Low | The GPG signature of a release was optional | Wallet | Fixed in 0.2.1 |
| K-24 | Low | The wallet never locked itself and sent without a password | Wallet | Fixed in 0.2.1 |

## Details of each finding

Paths of the wallet point at this repository. Paths of the relay point at
[Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay).

### K-01: a sent payment could come back as a failure

- **Severity:** High. **Status:** fixed in 0.2.1.
- **What happened:** after the engine sent a payment, the app read the state of the wallet again. A failure of
  that read turned the whole send into a failure. A lock or a quit during the send caused it, because the wallet
  closed before the read.
- **Impact:** the XMR left, but the app showed no payment. For a payment to Robinhood Chain, the app never saved
  the swap and lost the exchange id that ChangeNOW support needs. The review stayed open, so the user could pay
  twice.
- **Fix:** a lock, a change of network, and a quit wait for a send that runs. The reads after a send can no
  longer fail it. A payment to Robinhood Chain is saved before its XMR leaves, and dropped only when nothing left.

### K-02: send and pay shared one built payment

- **Severity:** High. **Status:** fixed in 0.2.1.
- **What happened:** the engine kept one built payment for the whole app, and a confirm sent whatever it held.
  While a payment to Robinhood Chain prepared its review, the send page still let the user build a plain send.
- **Impact:** the confirm on one screen could send the payment of the other screen, to another address and of
  another amount.
- **Fix:** each built payment has an id. The engine sends only the payment whose id, address, and amount match
  the review (`lib/wallet/pending_slot.dart`). The send page keeps its way while a payment prepares.

### K-03: the rate limit of the relay took a key that the client chose

- **Severity:** High. **Status:** fixed.
- **What happened:** nginx counted each client by a header that the client could set. The server also answered
  requests that did not come through Cloudflare.
- **Impact:** anyone could create exchanges under the partner key without limit and use up its budget. Pay and
  receive then failed for everybody, and ChangeNOW could suspend the key. User funds were not at risk.
- **Fix:** the server takes requests for the relay only from Cloudflare and from itself. nginx reads the address
  of each client from Cloudflare. After the deploy on 7 Oct 2026, a request straight to the server gets no answer.

### K-04: the rate limit could not protect the shared budget of the partner key

- **Severity:** Medium. **Status:** fixed.
- **What happened:** all routes shared one limit for each client, and the relay put no cap on its own calls to
  ChangeNOW.
- **Impact:** a few clients could use the whole budget of the partner key, so quotes and swaps failed for every
  user.
- **Fix:** the relay keeps its calls to ChangeNOW below the budget of the key and answers "busy" above it
  (`src/limiter.mts`). It keeps the minimum of each asset for a minute. The routes that create exchanges have a
  tight limit for each client. From 8 Oct 2026 the limits count a client of IPv6 by its /64, so a client cannot
  take a new address of its own block for each request.

### K-05: any web page could create exchanges through the browsers of its visitors

- **Severity:** Medium. **Status:** fixed.
- **What happened:** the relay read every POST body as JSON, whatever its content type. A browser can send such a
  request from any web page without asking the relay first.
- **Impact:** a web page could make its visitors create exchanges, and each visitor counted as a separate client.
- **Fix:** the relay refuses a POST without `Content-Type: application/json`. It also refuses any request with
  `Origin` or `Sec-Fetch-Site`, which browsers send and the app does not.

### K-06: receive used the answer of ChangeNOW without a check

- **Severity:** Medium. **Status:** fixed in the relay and in 0.2.1.
- **What happened:** for a payment to Robinhood Chain, the relay and the app checked the answer of ChangeNOW. For
  receive, neither checked it.
- **Impact:** a fault at ChangeNOW or at the relay could show a wrong deposit address or amount, or pay the XMR to
  an address that is not the user's.
- **Fix:** the relay and the app check the answer of receive: the form of the deposit address, the amount, the
  currencies, and the subaddress that gets the XMR.

### K-07: failures on the screens that move money showed no message

- **Severity:** Medium. **Status:** fixed in 0.2.1.
- **What happened:** the screens did not catch some failures of the engine, so they cleared their message and
  showed nothing.
- **Impact:** after K-01, the user could not tell whether a payment left.
- **Fix:** every failure of the engine reaches the screens as a failure of the wallet with its own text. The
  screens that move money show a message for any other error.

### K-08: the deadline of a fixed rate failed open

- **Severity:** Medium. **Status:** fixed in 0.2.1.
- **What happened:** the app checked the deadline of a fixed rate only when it could read one, and it read a time
  without a zone as local time. The send could also wait in a queue after the check.
- **Impact:** XMR could reach an exchange whose fixed rate had run out. The recipient then got another amount,
  or ChangeNOW refunded the XMR minus fees.
- **Fix:** a fixed rate needs a deadline with its zone. The engine refuses to send after the deadline, so time in
  the queue counts too.

### K-09: a damaged settings file or swap file stopped the app at start

- **Severity:** Medium. **Status:** fixed in 0.2.1.
- **What happened:** the app read `settings.json` and `bridge.json` before it showed a window, and it stopped on
  any error in them. A crash during a write could leave a file that the next start refused.
- **Impact:** the app showed no window and no message. The funds stayed safe through the seed, but the user had
  to find and delete a file by hand.
- **Fix:** the app writes both files through a temporary file and a rename. At start, it moves an unreadable file
  aside and keeps the swaps that it can read. From 0.3.1 a notice on the screen names the file that moved aside and
  says that the wallets did not change.

### K-10: the relay alone decided where bridge money goes

- **Severity:** Medium. **Status:** fixed in 0.3.1.
- **What happened:** the app trusted any certificate that the Mac trusts for the relay, and the relay names the
  deposit address of each exchange.
- **Impact:** a certificate that inspects TLS on the Mac, as some company networks install, or a compromised
  relay could name its own deposit address.
- **Fix:** the relay signs every answer with ECDSA on P-256 over the nonce of the request and the body, and the
  app trusts no answer without a signature under the key that it holds, so an interception of the connection
  cannot answer for the relay, and an old answer cannot answer a new request. A release talks to its relay over
  HTTPS only, and the release script refuses a build with another relay or without the key. A relay whose server
  falls still falls with its key.
- **After the fix:** the second review found that the signature does not bind the request that it answers, so an
  interception of TLS can still pass on the answer to another request. That report tracks the gap as
  [wallet O-003](security-review-consensys-0.3.1.md#wallet-o-003-the-signature-of-an-answer-does-not-bind-the-request).

### K-11: traffic to the node is not encrypted, and node fees had no limit

- **Severity:** Medium. **Status:** partly fixed in 0.3.1.
- **What happens:** the app connects to its Monero node without SSL. Before 0.3.1 it had no proxy and accepted
  the fee that the node suggests, with no upper limit.
- **Impact:** on a shared network, an observer can see that traffic and change the answers of the node, such as
  the fee estimate.
- **Fix:** a payment with a network fee above 0.01 XMR stops before its review. Settings take a SOCKS proxy, such
  as Tor, for the node of every network, and the menu Privacy says of a public node without a proxy that the
  connection is not encrypted.
- **Still open:** SSL nodes. The Monero library that the app ships accepts any certificate, so SSL would add no
  real protection; Tor or a node of your own does.

### K-12: the subaddress of a swap became the receive address on the screen

- **Severity:** Medium. **Status:** fixed in 0.2.1.
- **What happened:** a swap made a new subaddress for ChangeNOW through the same call that set the receive address
  on Home and Receive.
- **Impact:** the user then gave out an address that the records of ChangeNOW link with the user's side on
  Robinhood Chain.
- **Fix:** the receive page keeps its own subaddress, and ChangeNOW gets new subaddresses that the page never
  shows. The wallet saves at once after it makes one.

### K-13: the release build had no hardened runtime

- **Severity:** Medium. **Status:** fixed in 0.2.1.
- **What happened:** the release build did not turn on the hardened runtime of macOS.
- **Impact:** malware that runs as the user could start the app with a library of its own inside, where the
  password and the seed pass.
- **Fix:** release builds run with the hardened runtime, and the release script refuses a build without it. On
  the release build of 0.2.1, `DYLD_INSERT_LIBRARIES` loads nothing into the app. Library validation stays off,
  because the Monero library and the frameworks of Flutter carry an ad hoc signature, and the LGPL-3.0 lets you
  replace the Monero library. Notarization needs an Apple Developer account.

### K-14: creating an exchange is not idempotent

- **Severity:** Low. **Status:** partly fixed.
- **What happened:** when an answer came slowly or a check failed after ChangeNOW created an exchange, the app got
  no id. A retry then created a second exchange.
- **Impact:** exchanges under the partner key that nobody funds or follows. No funds moved, because the app pays
  only after it has the id.
- **Fix:** the relay reads the whole answer inside its error handling, and a refused exchange comes back with its
  id. From 0.3.1 the app sends an idempotency key with each creation and reuses it on a second try of the same
  request, and the relay makes one exchange for each key.

### K-15: the relay passed raw error text of ChangeNOW to any caller

- **Severity:** Low. **Status:** fixed.
- **What happened:** the relay passed any error text of ChangeNOW to the caller, a refused or suspended key
  included. Its health check never used the key.
- **Fix:** refusals reach the app in one short line. A refused key and a spent budget get fixed text. The route
  `GET /ready` checks the key.

### K-16: fetch followed a redirect and kept the partner key

- **Severity:** Low. **Status:** fixed.
- **What happened:** the `fetch` of Node follows redirects by default and keeps the header with the partner key on
  a redirect to another host.
- **Fix:** the relay follows no redirect.

### K-17: the relay could print a misplaced key to the system log

- **Severity:** Low. **Status:** fixed.
- **What happened:** when the variable for the path of the key file held the key itself, the error message
  printed the value, and systemd wrote it to the journal.
- **Fix:** the error names the variable and never its value.

### K-18: the id of an exchange alone read all details of a swap

- **Severity:** Low. **Status:** partly fixed.
- **What happened:** the id of an exchange alone read all its details through the relay, both addresses included.
  The app shows the id and asks users to send it to support.
- **Fix:** the status route of the relay returns no address. From 0.3.1 each new swap gets a read token, and the
  relay refuses a read with the token of another swap.
- **Still open:** a read without a token still passes, so that the apps before 0.3.1 keep following their swaps.
  The relay will refuse it once those apps are gone.

### K-19: an amount of 0 meant "send the whole balance"

- **Severity:** Low. **Status:** fixed in 0.2.1.
- **What happened:** `monero_c` reads an amount of 0 as a sweep of the whole balance, and nothing below the text
  field refused 0. No path of the app sent 0.
- **Fix:** the engine refuses an amount of 0.

### K-20: a very large amount broke the pay screen

- **Severity:** Low. **Status:** fixed in 0.2.1.
- **What happened:** the pay form accepted an amount too large for the amount type of the app, and the screen
  then failed to draw.
- **Fix:** pay reads no amount that the wallet cannot hold, and amount fields take at most 24 characters.

### K-21: the refund address of receive got no checksum check

- **Severity:** Low. **Status:** fixed in 0.2.1.
- **What happened:** a refund address in mixed case with one wrong character passed, though its checksum was
  wrong.
- **Fix:** the refund address gets the EIP-55 check.

### K-22: the QR code of a receive deposit held a bare address

- **Severity:** Low. **Status:** fixed in 0.3.1.
- **What happened:** the code carried no chain, token, or amount, so a wallet that scans it could propose a send
  on another chain. The screen shows the amount next to the code.
- **Fix:** the code holds a link of EIP-681 with the chain id of Robinhood Chain, for USDG its contract and the
  amount, for ETH the amount in wei. "Address only" shows the bare address for a wallet that cannot read such a
  link.

### K-23: the GPG signature of a release was optional

- **Severity:** Low. **Status:** fixed in 0.2.1.
- **What happened:** the release script signed the list of hashes only when the shell set a signing key, and went
  on without a warning when it did not. Both public releases before the review carry the signature.
- **Fix:** without the key, the script writes `hashes.unsigned.txt` and a warning, never `hashes.txt`. The app
  itself still carries an ad hoc signature until Kranox has an Apple Developer ID.

### K-24: the wallet never locked itself and sent without a password

- **Severity:** Low. **Status:** fixed in 0.2.1.
- **What happened:** an open wallet stayed open until the user locked it or quit, and a send asked for no
  password.
- **Fix:** each send asks for the password of the wallet, which the engine checks against the key file before
  anything leaves. An open wallet locks after 10 minutes without use. The lock reads the clock of the Mac, so a
  Mac that slept longer finds the wallet locked.

## Verification of the High findings

Stage 3 ran `fp-check` on K-01, K-02, and K-03. The skill passes a finding only when all six of its gates pass:
process, reachability by an attacker, real impact, PoC, math bounds, and environment.

| ID | Verdict of `fp-check` | Gates that failed | PoC | What it means |
|---|---|---|---|---|
| K-03 | True positive | None | One request straight to the server reached nginx without Cloudflare | Anyone could use the partner key without limit. |
| K-01 | False positive | 2 and 3 | 11 tests, all pass | A real defect that only the user's own actions trigger. |
| K-02 | False positive | 2 | 5 tests, all pass | A real defect that only the user's own clicks trigger. |

A false positive of `fp-check` means "not an attacker-exploitable vulnerability". It does not mean that the code
was correct. K-01 and K-02 stay High, because they could cost a user money through ordinary actions, and the PoCs
show it. The check for chains of findings found none that lets an attacker trigger K-01 or K-02.

The PoC tests ran against a model of the engine and the worker, without wallet2, a node, the relay, or ChangeNOW.
In the PoC of K-02, a plain review of 0.05 XMR to one address sent 0.16 XMR to the deposit address of ChangeNOW.

## What the review ruled out

The skills checked these leads and found them safe, each with the line that shows it.

- **Wallet:** a destination of another network, because wallet2 parses with the network of the open wallet and
  pay requires mainnet; integrated deposit addresses; the comparison of the recipient in lowercase; the trust
  setting of the node after a failed start; sending one built payment twice; a second press of Enter while a
  review prepares; the reveal of the seed, which checks the password again; the balance check while the wallet
  syncs.
- **Relay:** missing or malformed environment variables, which all stop the relay; the listen address
  `127.0.0.1`; the rights on the key file; the systemd unit, which runs as its own user without capabilities,
  with `ProtectSystem=strict` and `NoNewPrivileges`; request logs in nginx, which are off; prototype pollution,
  ReDoS, and injection into the addresses of ChangeNOW; the body limit of 4 kB in nginx and in the relay.
- **Defaults:** of 84 candidates for insecure defaults, the verifiers refuted 72.

## Tests after the fixes

The wallet gained 28 unit tests, among them the regression tests of K-01, K-02, K-06, K-08, K-09, K-12, and K-20.
One widget test drives the real send page. The relay gained 9 tests. For the fixes of 0.3.1, the wallet gained
tests of K-09, K-10, K-11, K-14, K-18, and K-22, and the relay tests of K-10, K-14, and K-18. Every test passes at
the commits that this report names.
