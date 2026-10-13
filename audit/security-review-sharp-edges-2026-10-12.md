# Security scan of the Kranox door and of the relay for it

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 12 Oct 2026, at the commit
[`8720912`](https://github.com/Kranox-Labs/Door/tree/8720912d46862fe86898e3fe584a2b13b108cbef) of the door and the
change of the relay after its commit
[`1bc103a`](https://github.com/Kranox-Labs/Relay/tree/1bc103a) that lets the door in. Not an audit by Trail of
Bits.

This report covers a quick scan of the Kranox door, the web app of Kranox, before its first release, and of the
change of the relay that answers it. Claude ran the skill in Claude Code and wrote every finding. No person at Trail
of Bits or at another firm read the code.

After you read this report, you know what the scan covered, what it found, and how each finding was fixed. The
reports of the earlier reviews are [security-review-0.2.0.md](security-review-0.2.0.md),
[security-review-consensys-0.3.1.md](security-review-consensys-0.3.1.md), and
[security-review-sharp-edges-2026-10-10.md](security-review-sharp-edges-2026-10-10.md).

## Scope

| Part | What the scan read | Version |
|---|---|---|
| Door | `src/` of [Kranox-Labs/Door](https://github.com/Kranox-Labs/Door): the settings, the client of the relay with its check of the signatures, the swaps kept in the browser, the privacy check, the wallet of the user, its balances, and the steps of receive | The first commit, `8720912` |
| Relay | The change to `src/config.mts`, `src/server.mts`, and `src/main.mts` of [Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay): the origins of the web app, the answer to the question of a browser, and the headers that let the web app read | After `1bc103a`, before the fixes below |

The door is a web app in the browser of a phone or of a desktop. The user connects the wallet that receives (an
extension such as MetaMask or Rabby, or the browser of a wallet app), and receive walks through the chain the coins
come from, the amount, the provider, the privacy review, and the transaction: the user sends XMR from their own Monero
wallet to the deposit address of the exchanger, and the coins arrive in the wallet they connected. The door holds no
key, opens no account, and keeps the swaps of the user in the browser only. It talks to the relay as the Mac app
does: a nonce on each request, and the signature of the relay checked over the request and the answer.

The scan left out the code of the relay that the earlier reviews read and that did not change, the Mac app, the
tests, the server, the site, ChangeNOW, Alchemy, Blockscout, and the wallets of the user.

## Method

The scan used the skill `sharp-edges` 1.1.3 of the marketplace `trailofbits/skills`, at the commit `82fe822` of
28 Sep 2026, under the license CC-BY-SA-4.0. Claude Code 2.1.296 ran it with the model Claude Opus 5.5.

The skill looks for designs that make mistakes easy: dangerous defaults, silent failures, settings that fail with one
wrong value, values whose kind is easy to mix up, and trust put in the wrong place. Two agents of the skill ran, one
on the door and one on the change of the relay, each with the questions that matter for its part: whether an
unsigned or wrongly signed answer can reach the user, whether a page other than the door can use the relay, and
whether a wrong address or a wrong amount can show. Each agent reported what it could tie to the code, and listed
the candidates that it refuted.

Before any fix, Claude checked each finding against the code itself.

## Summary

The scan found 22 findings: 2 Medium, 13 Low, and 7 Info. Nothing is High or Critical.

- No finding lets a page other than the door use the relay, or lets an answer that the relay did not sign reach the
  user. The agent of the relay called the gate of the origins "exact and fail-closed", and the agent of the door
  found that "the signed-answer design holds".
- The two Medium findings are about the door before any real use: a made-up wallet of development that could open a
  real swap, and a refund address that passed on its shape alone.

| Severity | Door | Relay | Total |
|---|---|---|---|
| Critical | 0 | 0 | 0 |
| High | 0 | 0 | 0 |
| Medium | 2 | 0 | 2 |
| Low | 10 | 3 | 13 |
| Info | 4 | 3 | 7 |
| Total | 16 | 6 | 22 |

Every finding but two is fixed, with tests. The two that stay are notes: a limit of nginx that the deploy of the
relay keeps on purpose, and a check that waits for wallets of another kind. The fixes of the door are in its commit
[`52e7e37`](https://github.com/Kranox-Labs/Door/commit/52e7e37), and the fixes of the relay are in its commit
[`2016b2f`](https://github.com/Kranox-Labs/Relay/commit/2016b2f), together with the change that lets the door in.

## Findings

| ID | Part | Severity | Finding | Status |
|---|---|---|---|---|
| D-01 | Door | Medium | The made-up wallet of development could open a real swap | Fixed |
| D-02 | Door | Medium | The refund address passed on its shape alone | Fixed |
| D-03 | Door | Low | The key of a creation outlived a changed request | Fixed |
| D-04 | Door | Low | The swap that came back was not compared with the request | Fixed |
| D-05 | Door | Low | The form took more decimals of XMR than the page showed | Fixed |
| D-06 | Door | Low | Two deadlines of different kinds shared one field | Fixed |
| D-07 | Door | Low | The deposit address stayed up after the time to send ran out | Fixed |
| D-08 | Door | Low | The address of a wallet was taken as any text | Fixed |
| D-09 | Door | Low | Balances were read on whatever network the wallet was on | Fixed |
| D-10 | Door | Low | A wallet connected again by its name alone, and two could race | Fixed |
| D-11 | Door | Low | A key of the relay off its curve passed the check of the settings | Fixed |
| D-12 | Door | Low | A stored swap with a state the pages do not know blanked the page | Fixed |
| D-13 | Door | Info | The id of a chain was read too loosely | Fixed |
| D-14 | Door | Info | No check that the address that receives is an account on Robinhood Chain | Later, with other kinds of wallet |
| D-15 | Door | Info | What arrived could overwrite the promised amount while the swap ran | Fixed |
| D-16 | Door | Info | The rate of an answer was not compared with the request | Fixed |
| R-01 | Relay | Low | The origins of the web app were bare text at every layer | Fixed |
| R-02 | Relay | Low | An origin on plain HTTP passed the settings | Fixed |
| R-03 | Relay | Low | A page got an unsigned answer when it sent no nonce | Fixed |
| R-04 | Relay | Info | Only an answer with the headers of the web app said that it depends on the origin | Fixed |
| R-05 | Relay | Info | The reader of the origins had no test, and some refusals named the wrong cause | Fixed |
| R-06 | Relay | Info | The question of a browser counts in the limit of nginx for creations | Kept on purpose |

## Details of each finding

Paths of the door point at [Kranox-Labs/Door](https://github.com/Kranox-Labs/Door). Paths of the relay point at
[Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay).

### D-01: the made-up wallet of development could open a real swap

- **Severity:** Medium. **Part:** door. **Status:** fixed.
- **What happened:** for a look at the pages without a wallet extension, a build of development offers "Use a
  sample address", a made-up wallet with a random address. The button hid in a production build, but not in a build
  of development that talks to the real relay. With it, the transaction step would open a real swap at the
  exchanger for an address that nobody holds.
- **Impact:** a developer who tests end to end with a small amount of XMR sends it to an address nobody holds.
- **Fix:** the button shows only when the app runs on sample data, and the transaction step refuses to open a swap
  for the made-up wallet when the client is real (`src/ui/pages/ConnectPage.tsx`,
  `src/ui/pages/receive/TransactionStep.tsx`, `src/wallet/provider.ts`).

### D-02: the refund address passed on its shape alone

- **Severity:** Medium. **Part:** door. **Status:** fixed.
- **What happened:** the Monero address for a refund passed with 95 characters of base58 that start with 4 or 8,
  and the form then said "Monero address" with a check. The relay leaves the checksum of an address to the app on
  purpose; the Mac app checks it, the door did not.
- **Impact:** an address with one wrong character got the check mark and went to the exchanger; a refund, rare as it
  is, could go to an address that decodes to nothing.
- **Fix:** the door decodes the base58 of Monero, checks the checksum of Keccak-256, and takes the prefixes of a
  standard address and a subaddress of mainnet only, as the Mac app does (`src/door/monero-address.ts`, with the
  package `@noble/hashes` for Keccak-256), with tests on real addresses and on an address with one wrong character.

### D-03: the key of a creation outlived a changed request

- **Severity:** Low. **Part:** door. **Status:** fixed.
- **What happened:** the transaction step made one key for its creation and kept it for a second try, so that a lost
  answer gives the same swap. The key stayed when the request changed, such as after a new quote, and the relay then
  refused the second try with a sentence of its own.
- **Fix:** the key belongs to the request: a second try of the same request carries the same key, and a changed
  request gets a new one (`src/ui/pages/receive/TransactionStep.tsx`).

### D-04: the swap that came back was not compared with the request

- **Severity:** Low. **Part:** door. **Status:** fixed.
- **What happened:** the door compared the address that receives and the refund address of a new swap with its
  request, but took the amount of XMR to send, which the page tells the user to send exactly, and the deposit address
  from the answer without a look. The relay checks both before it signs, so this was a second line, not an open hole.
- **Fix:** the amount of XMR must match the request, and the deposit address must be one of Monero
  (`src/door/relay-client.ts`).

### D-05: the form took more decimals of XMR than the page showed

- **Severity:** Low. **Part:** door. **Status:** fixed.
- **What happened:** the amount took up to 18 decimals, as the relay does, while the page of the swap and its
  `monero:` link wrote the amount with 8. An amount of nine decimals made a swap for one amount and asked the user to
  send another.
- **Fix:** the form takes at most 8 decimals and says so (`src/door/amount.ts`, `src/ui/pages/receive/AmountStep.tsx`),
  with tests.

### D-06: two deadlines of different kinds shared one field

- **Severity:** Low. **Part:** door. **Status:** fixed.
- **What happened:** a new swap kept the time of its quote, which is the time of the rate, about two minutes, in the
  field that the page shows as the time to send. The first read of the state of the swap replaced it with the time of
  the deposit; when that read failed, the page said "do not send" while the exchanger still waited.
- **Fix:** a new swap has no time to send until the relay reads one (`src/door/store.ts`).

### D-07: the deposit address stayed up after the time to send ran out

- **Severity:** Low. **Part:** door. **Status:** fixed.
- **What happened:** the page of a swap added the warning that the time ran out beside the QR code, the address, and
  the link, which stayed in reach.
- **Fix:** once the time ran out, only the warning stays (`src/ui/pages/SwapPage.tsx`).

### D-08: the address of a wallet was taken as any text

- **Severity:** Low. **Part:** door. **Status:** fixed.
- **What happened:** the first address that a wallet named was taken as any text that is not empty. A wallet of bad
  faith or with a fault could name something that is no address, which the relay refused later with its own words.
- **Fix:** an address must have the form of an address on an EVM chain, or the wallet gave none
  (`src/wallet/provider.ts`).

### D-09: balances were read on whatever network the wallet was on

- **Severity:** Low. **Part:** door. **Status:** fixed.
- **What happened:** the home read the balances through the wallet as soon as it connected, also on another
  network, and showed them under "On Robinhood Chain".
- **Fix:** the home reads balances on Robinhood Chain only (`src/ui/pages/HomePage.tsx`).

### D-10: a wallet connected again by its name alone, and two could race

- **Severity:** Low. **Part:** door. **Status:** fixed.
- **What happened:** after a reload, the door connected the remembered wallet again without a prompt, to the first
  wallet that announced the remembered name. Two wallets with the same name both started, and the last to answer
  won, also over a wallet that the user had just connected by hand.
- **Fix:** the door connects again only when one wallet carries the remembered name, and never over a wallet that the
  user connected meanwhile (`src/wallet/provider.ts`). The full address on the connect page and on the review stays
  the thing to check.

### D-11: a key of the relay off its curve passed the check of the settings

- **Severity:** Low. **Part:** door. **Status:** fixed.
- **What happened:** the settings checked the length and the first byte of a public key of the relay, not that it
  lies on its curve. Such a key failed later, in every call, with a general sentence.
- **Fix:** the app imports every key before it loads, and a key that is no point of the curve stops it with the
  reason on the page (`src/main.tsx`).

### D-12: a stored swap with a state the pages do not know blanked the page

- **Severity:** Low. **Part:** door. **Status:** fixed.
- **What happened:** the swaps kept in the browser were checked for their main fields, but the state could be any
  text, and the page of a swap had no answer for a state it does not know.
- **Fix:** a stored swap must have every field in its form and a state the pages know, or it stays out of the list
  (`src/door/store.ts`).

### D-13: the id of a chain was read too loosely

- **Severity:** Info. **Part:** door. **Status:** fixed.
- **What happened:** the id of the chain of a wallet was read from any text as hex, and from any number.
- **Fix:** hex with 0x, as the standard says, or a whole number; anything else counts as another network
  (`src/wallet/provider.ts`).

### D-14: no check that the address that receives is an account on Robinhood Chain

- **Severity:** Info. **Part:** door. **Status:** later.
- **What happened:** a contract wallet from another chain, such as a Safe, may hold no code on Robinhood Chain, and
  coins sent there stay. Today the door takes wallet extensions only, whose addresses are accounts everywhere.
- **Plan:** a read of the code at the address, with a warning, when the door takes WalletConnect or wallets of that
  kind.

### D-15: what arrived could overwrite the promised amount while the swap ran

- **Severity:** Info. **Part:** door. **Status:** fixed.
- **What happened:** any amount that the exchanger reported as arrived, also zero, replaced the amount of the swap
  while it still ran.
- **Fix:** what arrived counts once the swap is done (`src/door/store.ts`).

### D-16: the rate of an answer was not compared with the request

- **Severity:** Info. **Part:** door. **Status:** fixed.
- **What happened:** the range and the quote compared the coin and the amount of the answer with the request, not the
  rate.
- **Fix:** the rate must match too (`src/door/relay-client.ts`).

### R-01: the origins of the web app were bare text at every layer

- **Severity:** Low. **Part:** relay. **Status:** fixed.
- **What happened:** the settings checked that each origin of the web app is one as a browser sends it, but the
  relay itself took any list of text. A list made by hand with the origin "null", which a page in a sandbox or after a
  redirect sends, would have let such a page in.
- **Fix:** the relay checks the list itself when it starts, with the one check of the settings
  (`src/config.mts`, `src/server.mts`).

### R-02: an origin on plain HTTP passed the settings

- **Severity:** Low. **Part:** relay. **Status:** fixed.
- **What happened:** the settings took an origin on plain HTTP, such as a dropped character in the address of the web
  app. A page served on plain HTTP in the place of the web app, by someone on the path, would then have used the
  relay.
- **Fix:** an origin must be HTTPS, unless it is the machine of a developer on localhost or 127.0.0.1
  (`src/config.mts`), with a test for each wrong form.

### R-03: a page got an unsigned answer when it sent no nonce

- **Severity:** Low. **Part:** relay. **Status:** fixed.
- **What happened:** the relay signs an answer over the nonce of the request, and skips the signature for a request
  without one, for the apps before 0.3.1. A page of the web app that sent no nonce, or one of the wrong form, got an
  answer with the headers of the web app and no signature. The door sends a nonce on every call and refuses an answer
  without a signature, so nothing happened.
- **Fix:** a request from the web app needs its nonce, or the relay refuses it; the apps before 0.3.1 send no origin,
  so they pass as before (`src/server.mts`).

### R-04: only an answer with the headers of the web app said that it depends on the origin

- **Severity:** Info. **Part:** relay. **Status:** fixed.
- **What happened:** the answers to the web app carried `Vary: Origin`; the refusals of other pages and the answers
  to the Mac app did not, while they depend on the origin too. Every answer says `no-store`, so no cache keeps one.
- **Fix:** every answer carries `Vary: Origin` (`src/server.mts`).

### R-05: the reader of the origins had no test, and some refusals named the wrong cause

- **Severity:** Info. **Part:** relay. **Status:** fixed.
- **What happened:** an origin in capitals or with a default port was refused with the words for a path, and the
  reader had no test of its own.
- **Fix:** the refusal names the value and the rule it breaks, and tests cover each form, the origin "null", and the
  near misses of the origin of the web app (`src/config.mts`, `test/config.test.mts`, `test/server.test.mts`).

### R-06: the question of a browser counts in the limit of nginx for creations

- **Severity:** Info. **Part:** relay. **Status:** kept on purpose.
- **What happened:** before the first creation of a swap, a browser asks the relay what it may send, and nginx counts
  that question in its limit for creations, a few a minute for each client. A browser keeps the answer for ten
  minutes, so the first creation costs two counts and the next ones one. A refusal of nginx carries no headers of the
  web app, so the door reads it as a relay that did not answer.
- **Plan:** none. The limit keeps its direction, and the cost of one count is small.

## What the scan ruled out

The agents refuted their own candidates before they reported:

- A page other than the door cannot get a readable answer or create a swap: a browser puts the origin on every request
  that could change something, the relay refuses an origin that it does not know and a request that only a page
  sends, a body of JSON needs the question of the browser first, the relay issues no redirect, and the door follows
  none. The comparison of the origin is exact: no prefix, no pattern, no wildcard, no credentials.
- An answer that the relay did not sign cannot reach the user: the door checks the signature before it reads the
  answer, an error too, and the text that the signature covers holds the nonce, the method, the path with its query,
  the hash of the body of the request, the status, and the body. The path that the door signs is the path that the
  relay sees.
- A deposit address shows only from a signed answer, from the sample client on sample data, or from the storage of
  the browser, which only code of the door itself can write.
- The sample client and the made-up wallet stay out of a production build.
- The call data of a balance and the turn of units into an amount are right, with tests.
