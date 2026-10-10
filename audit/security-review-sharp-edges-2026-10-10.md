# Security scan of the code after Kranox 0.3.1

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 10 Oct 2026, at the commit
[`630c1ea`](https://github.com/Kranox-Labs/Kranox/tree/630c1ea9d2fc580d8468f9085825bf3714ad354c) of the wallet and the
commit [`c30fc70`](https://github.com/Kranox-Labs/Relay/tree/c30fc704527e35666d5b3f0c55f7343b18d223d0) of the relay.
Not an audit by Trail of Bits.

This report covers a quick scan of the code that the wallet and the relay gained after the second security review.
Claude ran the skill in Claude Code and wrote every finding. No person at Trail of Bits or at another firm read the
code.

After you read this report, you know what the scan covered, what it found, and how each finding was fixed. The
reports of the earlier reviews are [security-review-0.2.0.md](security-review-0.2.0.md) and
[security-review-consensys-0.3.1.md](security-review-consensys-0.3.1.md).

## Scope

| Part | What the scan read | Versions |
|---|---|---|
| Wallet app | The changes to `lib/` of this repository: 36 files | From `56d16b3`, the second review, to `630c1ea` |
| Relay | The changes to `src/` of [Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay): 10 files | From `ef0cdc5`, the second review, to `c30fc70` |

The new code holds the client of the relay through the proxy of Settings, the second form of the signature of an
answer, the sealed file of the swaps, the rule of a new password, the pages of the swaps, the scans of addresses on
Robinhood Chain, and the checks of privacy. In the relay, it holds the signer, the store of creation keys, the scans
through Alchemy and Blockscout, and the reader of the first funding of an address.

The scan left out the code that the earlier reviews read and that did not change, the tests, the server, the site,
ChangeNOW, Alchemy, Blockscout, and the inside of the Monero library `monero_c`.

## Method

The scan used the skill `sharp-edges` 1.1.3 of the marketplace `trailofbits/skills`, at the commit `82fe822` of
28 Sep 2026, under the license CC-BY-SA-4.0. Claude Code 2.1.296 ran it with the model Claude Opus 5.5.

The skill looks for designs that make mistakes easy: dangerous defaults, silent failures, settings that fail with one
wrong value, and values whose kind is easy to mix up. Two agents of the skill ran, one on the changes of the wallet
and one on the changes of the relay. They could only read and search the code: they ran no program and sent no
request.

Before any fix, Claude checked the High finding, two of the Medium ones, and one Low one against the code itself.

## Summary

The scan found 13 findings: 1 High, 3 Medium, and 9 Low. Nothing is Critical.

- No finding lets an attacker on the internet take funds or keys from a wallet.
- The High finding is about privacy: a proxy given by its name never reached the node, while the app said it did.
- The three Medium findings are about checks that said "sure" or "clear" without the data for it.

| Severity | Wallet | Relay | Total |
|---|---|---|---|
| Critical | 0 | 0 | 0 |
| High | 1 | 0 | 1 |
| Medium | 1 | 2 | 3 |
| Low | 4 | 5 | 9 |
| Total | 6 | 7 | 13 |

Every finding is fixed, with tests. The fixes of the wallet ship in
[Kranox 0.3.2 beta](https://github.com/Kranox-Labs/Kranox/releases/tag/v0.3.2), in the commit
[`a27472f`](https://github.com/Kranox-Labs/Kranox/commit/a27472f). The fixes of the relay are in its commit
[`dd886be`](https://github.com/Kranox-Labs/Relay/commit/dd886be), and the relay runs them after its next deploy.

## Findings

| ID | Part | Severity | Finding | Status |
|---|---|---|---|---|
| S-01 | Wallet | High | A proxy given by its name never reached the node | Fixed in 0.3.2 |
| S-02 | Wallet | Medium | A privacy rule without its data passed, so the check said "All clear" | Fixed in 0.3.2 |
| S-03 | Relay | Medium | A failure inside an answer of 200 counted as a complete list | Fixed in the relay |
| S-04 | Relay | Medium | "No funding" was sure while the address held value | Fixed in the relay |
| S-05 | Wallet | Low | The file of the swaps took a plain file after its seal | Fixed in 0.3.2 |
| S-06 | Wallet | Low | The key of the files came from the view key | Fixed in 0.3.2 |
| S-07 | Wallet | Low | The rule of a new password lived on the screens only | Fixed in 0.3.2 |
| S-08 | Wallet | Low | A scan was not matched to the address that the app asked for | Fixed in 0.3.2 |
| S-09 | Relay | Low | Fields of rows from the explorer went into a path without a check | Fixed in the relay |
| S-10 | Relay | Low | The check of the refund address passed when ChangeNOW left it out | Fixed in 0.3.2 and in the relay |
| S-11 | Relay | Low | The signer left the check of the nonce to its callers | Fixed in the relay |
| S-12 | Relay | Low | Nothing enforced the sum behind the store of creation keys | Fixed in the relay |
| S-13 | Relay | Low | The name of a sender did not say where it came from | Fixed in 0.3.2 and in the relay |

## Details of each finding

Paths of the wallet point at this repository. Paths of the relay point at
[Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay).

### S-01: a proxy given by its name never reached the node

- **Severity:** High. **Part:** wallet. **Status:** fixed in 0.3.2.
- **What happened:** Settings took a proxy with a host name, such as `localhost:9050`. The client of the relay used
  it, but wallet2 reads a SOCKS proxy as an IP address only. `Wallet_init` failed, the app took that failure for a
  node that does not answer, and the wallet kept its connection without the proxy. Settings said that the wallet used
  the new node, and the menu Privacy said that the node saw the proxy.
- **Impact:** with Tor set by its name, the node saw the IP address of the Mac, while the app said it did not.
- **Fix:**
  - The field takes an IP address and a port only, such as `127.0.0.1:9050` (`lib/core/node_address.dart`).
  - A settings file of 0.3.1 with `localhost` reads as `127.0.0.1`. Another host name makes the file unreadable, so
    the app says so and starts without a proxy, and its notice now names the proxy (`lib/wallet/settings.dart`).
  - If wallet2 still refuses a proxy, the wallet fails closed. It pauses its scan, asks the node nothing, and builds
    no payment (`lib/wallet/engine.dart`). It still opens, so that you can reach Settings, which shows the error from
    the start (`lib/wallet/controller.dart`, `lib/ui/screens/settings_page.dart`).

### S-02: a privacy rule without its data passed, so the check said "All clear"

- **Severity:** Medium. **Part:** wallet. **Status:** fixed in 0.3.2.
- **What happened:** the privacy check on a review had no state for a rule that could not read its data. While the
  scan of the recipient of pay or of the refund address of a receive ran, or after it failed, the rule of the address
  passed. Only the scan can see that an address sent the coin of one of your receives. On the receive page right
  after a restore, a subaddress whose history the wallet had not read yet showed as never paid.
- **Impact:** the check could call a payment or a receive "All clear" when it had not checked it.
- **Fix:**
  - A rule has a fourth state, "not checked". It keeps the card from "All clear", and the card counts it, as in
    "1 not checked" (`lib/ui/widgets/privacy_check.dart`).
  - It covers a scan that runs or that failed, on pay and on a receive (`lib/ui/screens/send_to_chain.dart`,
    `lib/ui/screens/receive_from_chain.dart`), and a wallet that has not caught up with its node
    (`lib/ui/screens/receive_page.dart`).
  - A scan in the model of the app is unsure of its first funding unless it says otherwise, as the reader of the
    answer of the relay already was (`lib/bridge/chain_scan.dart`).

### S-03: a failure inside an answer of 200 counted as a complete list

- **Severity:** Medium. **Part:** relay. **Status:** fixed in the relay, live after its next deploy.
- **What happened:** the API of Blockscout in the style of Etherscan reports some failures inside an answer of 200,
  with a text in place of its rows. The relay read such an answer as a complete empty list, and it dropped rows that
  it could not read. The metadata service of Blockscout did the same with an answer that held no list of addresses.
- **Impact:** a scan could miss the first funding of an address, name a later one or none, and still say that it was
  sure. The hot wallet of an exchange could show as a sender without a name.
- **Fix:** a list whose answer holds no rows, or a row that does not read, leaves the first funding unsure. So does an
  answer of the metadata service without its addresses (`src/blockscout.mts`, `src/names.mts`).

### S-04: "no funding" was sure while the address held value

- **Severity:** Medium. **Part:** relay. **Status:** fixed in the relay, live after its next deploy.
- **What happened:** the explorer of Robinhood Chain still misses some transfers that contracts make. When the relay
  found no transfer in, it said so for sure, also for an address that held ETH or tokens, or had sent transactions. An
  address that the explorer had not seen yet got the same answer, and the relay kept it for 10 minutes.
- **Impact:** the app could call an address a clean start when a transfer that the explorer missed had funded it.
- **Fix:** no transfer in is sure only for an address that shows nothing: no balance, no transaction, and no token.
  An address that the explorer has not seen is unsure (`src/scan.mts`, `src/blockscout.mts`, `src/alchemy.mts`).

### S-05: the file of the swaps took a plain file after its seal

- **Severity:** Low. **Part:** wallet. **Status:** fixed in 0.3.2.
- **What happened:** to move the plain file of 0.3.1 to the seal, the store sealed any plain file that it found. A
  plain file put in place of the sealed one was taken and sealed again, without a notice.
- **Impact:** anyone who could write to the folder of the app could plant a swap, such as a receive whose deposit
  address is theirs.
- **Fix:** once the store has read the file under the key of the seal, the wallet records that in its cache, inside
  the wallet file. After that, a plain file moves aside, and the app says that it could not read the swaps
  (`lib/bridge/store.dart`, `lib/bridge/controller.dart`, `lib/wallet/engine.dart`).
- **What stays:** someone who can put an older copy of the wallet file in place can remove the record, and plant a
  plain file after it.

### S-06: the key of the files came from the view key

- **Severity:** Low. **Part:** wallet. **Status:** fixed in 0.3.2.
- **What happened:** the app sealed the file of the swaps under a key from the secret view key. People share a view
  key on purpose, with an auditor or a view-only wallet.
- **Impact:** a holder of the view key with a copy of the file could read your addresses on Robinhood Chain, your
  swaps, and their read tokens, which the view key alone never shows. The same person could write a file that opens.
- **Fix:** the key comes from the secret spend key, under a new label (`lib/wallet/engine.dart`). A file under the
  earlier key opens once and is sealed again, and after the record of S-05 it moves aside like a plain file. No
  release ever used the earlier key.

### S-07: the rule of a new password lived on the screens only

- **Severity:** Low. **Part:** wallet. **Status:** fixed in 0.3.2.
- **What happened:** the rule of at least 12 characters, from the second review, was in the form only. The controller
  made or restored a wallet under any password, also an empty one. The form counted units of UTF-16, so six emoji
  counted as 12 characters.
- **Fix:** the controller checks the rule too, and both count code points of Unicode (`lib/wallet/controller.dart`,
  `lib/ui/format.dart`). The error never holds the password. A wallet made before keeps its password, so an unlock
  checks no length.

### S-08: a scan was not matched to the address that the app asked for

- **Severity:** Low. **Part:** wallet. **Status:** fixed in 0.3.2.
- **What happened:** the app judged whatever address the answer of a scan named. The scan of another address would
  show under the address that you checked, and would join the list of your own addresses.
- **Fix:** the app refuses the scan of another address, in any case of its letters, as it already did with the state
  of a swap (`lib/privacy/chain_scans.dart`).

### S-09: fields of rows from the explorer went into a path without a check

- **Severity:** Low. **Part:** relay. **Status:** fixed in the relay, live after its next deploy.
- **What happened:** the relay took the sender of a row from the explorer as it came, and put it into the path of its
  next call to the explorer, which carries its key. The host and the key could not change, but the path and the query
  could. A transfer whose time did not read could also win as the oldest one. This is the same kind of issue as relay
  O-006 of the second review, which was fixed for Alchemy only.
- **Fix:** both parties of a row must be addresses, or the row drops out and leaves the list incomplete. Every part of
  a path and of a query is encoded, and a transfer without a time that reads is no candidate (`src/blockscout.mts`,
  `src/scan.mts`).

### S-10: the check of the refund address passed when ChangeNOW left it out

- **Severity:** Low. **Part:** relay. **Status:** fixed in 0.3.2, with the relay part after its next deploy.
- **What happened:** the relay passed an exchange whose answer named no refund address, and an exchange with a refund
  address that the request never named. It answered the app with the refund address of the request, so the check of
  the app compared its own value with itself.
- **Impact:** the app could promise a refund that ChangeNOW never recorded.
- **Fix:** the relay requires the refund address of the request in the answer of ChangeNOW, whose documentation says
  that the answer carries it when the request names one, and no refund address when the request names none. It
  answers the address that ChangeNOW recorded, and the app compares that one, in any case of its letters
  (`src/server.mts` of the relay, `lib/bridge/controller.dart` of the wallet).

### S-11: the signer left the check of the nonce to its callers

- **Severity:** Low. **Part:** relay. **Status:** fixed in the relay, live after its next deploy.
- **What happened:** the signer of answers took an empty nonce, a nonce with a slash, and fields with a line break.
  The split between the two forms of signature, and the fix of relay O-004 of the second review, both rest on the form
  of the nonce. A later call could have signed over an empty nonce again.
- **Fix:** the signer refuses a nonce that does not have the form of the app, and a line break in any field before
  the body (`src/signing.mts`).

### S-12: nothing enforced the sum behind the store of creation keys

- **Severity:** Low. **Part:** relay. **Status:** fixed in the relay, live after its next deploy.
- **What happened:** the store keeps up to 20,000 creation keys for 10 minutes, because the budget of calls to
  ChangeNOW allows 12,000 in that time. Only a comment said so, and the store also took a lifetime or a capacity of 0.
- **Impact:** a higher budget or a longer lifetime could let a flood of creations fill the store, so that a new swap
  would get an answer of 503.
- **Fix:** the relay checks the sum as it starts, and the store takes whole numbers above zero only
  (`src/config.mts`, `src/creations.mts`).

### S-13: the name of a sender did not say where it came from

- **Severity:** Low. **Part:** relay. **Status:** fixed in 0.3.2, with the relay part after its next deploy.
- **What happened:** the name of a sender came from a public tag of the explorer, from the name of a verified
  contract, which its deployer chose, or from a domain, which anyone can register. Nothing said which, so a contract
  verified as "Binance" showed as the exchange.
- **Fix:** each name carries its source, a tag, a contract, or a domain, and a tag comes first (`src/scan.mts`,
  `src/blockscout.mts`, `src/alchemy.mts`). The app words each source in its own way, as "Funded through the contract
  Disperse" or "Funded by the domain friend.eth" (`lib/bridge/chain_scan.dart`, `lib/ui/screens/privacy_page.dart`,
  `lib/ui/widgets/address_check.dart`). A named sender still ties the address in the check, whatever its source.

## Noted, and not changed

- A scan of the relay has no deadline of its own. Each call to a source stops after 20 seconds, so a slow scan through
  Alchemy and then Blockscout can run for more than two minutes. The app stops waiting after 30 seconds and offers to
  check again, and the relay keeps a finished scan for 10 minutes.
- The relay reads the answers of ChangeNOW, Alchemy, and Blockscout without a limit on their size. It calls only
  those fixed hosts, over HTTPS, and refuses a redirect.
- A comment of the relay still described the first version of the API of ChangeNOW, which the relay no longer calls.
  It is fixed.

## Tests after the fixes

- **Wallet:** `flutter analyze` finds no issue, and 202 tests pass. The test of the engine ran on the real wallet2 with
  a stagenet node. It shows that the key of the files stays the same, differs from the earlier key, keeps the record of
  S-05 across a lock, and comes back after a restore from the seed. The tests of the screens and of the showcase pass.
- **Relay:** the type check and the lint pass, and 69 tests pass.
- **Mutation checks:** each fix was broken on purpose, one at a time, 17 in the wallet and 15 in the relay, and the
  tests failed for each one. One check passed at first: in its test, the explorer had no answer for the sender of the
  funding, which left the funding unsure on its own. The test now gives the explorer that answer, so it checks S-03
  alone.

## Limits of the scan

- The scan read the changes since the second review, not the whole code. A flaw in code that did not change, or in
  the way old and new code meet, can escape it.
- The skill looks for sharp edges of design. It is no hunt for every kind of bug, and it ran no tool such as Semgrep
  or osv-scanner.
- The agents read code only. Nobody built an exploit or ran a proof of concept, and no request went to a live
  service during the scan. The test of the engine, after the fixes, talked to a public stagenet node.
- A clean result means that the scan found no issue, not that no issue exists.
