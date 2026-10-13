# Security scan of Starknet as the second way into the Kranox web app, through NEAR Intents and ChangeNOW

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 13 Oct 2026, on the change after the
commit [`5d88089`](https://github.com/Kranox-Labs/App-Web/tree/5d88089) of the web app and the commit
[`22e28e7`](https://github.com/Kranox-Labs/Relay/tree/22e28e7) of the relay, with the deploy tools of the relay.
Not an audit by Trail of Bits.

This report covers a quick scan of the change that opened Starknet as the second chain the coins can come from: the
user sends STRK from their own Starknet wallet, through the 1Click API of NEAR Intents, the new provider, or through
ChangeNOW, and USDG or ETH arrives in the wallet they connected on Robinhood Chain. Claude ran the skill in Claude
Code and wrote every finding. No person at Trail of Bits or at another firm read the code.

After you read this report, you know what the scan covered, what it found, and how each finding was fixed. The
reports of the earlier reviews are [security-review-0.2.0.md](security-review-0.2.0.md),
[security-review-consensys-0.3.1.md](security-review-consensys-0.3.1.md),
[security-review-sharp-edges-2026-10-10.md](security-review-sharp-edges-2026-10-10.md),
[security-review-sharp-edges-2026-10-12.md](security-review-sharp-edges-2026-10-12.md),
[security-review-sharp-edges-2026-10-12-providers.md](security-review-sharp-edges-2026-10-12-providers.md), and
[security-review-sharp-edges-2026-10-13-node-trouble.md](security-review-sharp-edges-2026-10-13-node-trouble.md).

## Scope

| Part | What the scan read | Version |
|---|---|---|
| Relay | The change to [Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay): the new `src/oneclick.mts` (the client of the 1Click API of NEAR Intents) and `src/starknet.mts` (the addresses of Starknet), the coin of origin in `src/exchanger.mts`, `src/changenow.mts`, and `src/simpleswap.mts`, the routes of pay with the coin of origin, its addresses, and the names of XMR for the Mac app in `src/server.mts`, the settings of 1Click and its optional partner key in `src/config.mts` and `src/main.mts`, and the deploy tools `scripts/deploy/relay.mts`, `server/relay.sh`, and `deploy/config.mts` of the workspace, which carry the key. | After `22e28e7` |
| Web app | The change to [Kranox-Labs/App-Web](https://github.com/Kranox-Labs/App-Web): the facts of the chains in `src/gate/chains.ts` and `src/gate/starknet-address.ts`, the catalog of chains and providers with their rates, the chain of origin in the shapes, the client of the relay, the records of swaps and their upgrade, the privacy check, the copy, and the pages of receive and of a swap. | After `5d88089` |

The web app runs in the browser of a phone or of a desktop. The user connects the wallet that receives, and receive
walks through the chain the coins come from, the amount, the provider with its quote, the privacy review, and the
transaction: the user sends the coins from their own wallet of that chain to the deposit address of the provider, and
the coins arrive in the wallet they connected. From this change the chain can be Starknet as well as Monero: STRK
goes through NEAR Intents, whose 1Click API quotes in seconds and settles in about a minute, or through ChangeNOW,
and the relay holds the keys of each.

The scan left out the code that the earlier reviews read and that did not change, the Mac app, the site, the
exchangers themselves, and the wallets of the user.

## Method

The scan used the skill `sharp-edges` 1.1.3 of the marketplace `trailofbits/skills`, at the commit `82fe822` of
28 Sep 2026, under the license CC-BY-SA-4.0. Claude Code ran it with the model Claude Fable 5.1.

The skill looks for designs that make mistakes easy: dangerous defaults, silent failures, settings that fail with one
wrong value, and values of one kind that pass for another. Two agents of the skill read the two parts, each with the
list of the changed files and the full sources around them, and wrote their findings with a scenario and a fix each.
Claude then read each finding against the code, fixed it with a test where a test fits, and ran the checks of each
part: the type check, the linter, the formatter, the tests, and, for the web app, the build and a walk through the
steps of a swap of STRK in headless Chrome against a relay on the machine with the real keys, which made one real
swap at NEAR Intents that nobody funds.

## Summary

The scan found 26 findings: 5 Medium, 8 Low, and 13 Info. Nothing is High or Critical.

- No finding lets a swap go to another address, another amount, another chain, or another provider than the one the
  user saw: the relay checks every created swap against its request, down to the base units of 1Click, and the web
  app checks every figure of an answer against what it asked.
- The Medium findings are about the edges of the new chain: an address of an EVM chain, such as the wallet on
  Robinhood Chain that stands right under the field, passed as a Starknet refund address, both in the app and in the
  relay, so that a refund would have gone to an account nobody holds; a deposit that arrived in part showed as
  waiting, with the box to send again, and later as expired, while NEAR Intents held the coins; one budget of calls
  to 1Click served every kind of call, so that a flood of reads of a swap, which need no token yet, could starve
  every creation; and a swap whose id carries an underscore or a dash, which the relay allows, could never be opened
  in the app.

| Severity | Web app | Relay | Total |
|---|---|---|---|
| Critical | 0 | 0 | 0 |
| High | 0 | 0 | 0 |
| Medium | 2 | 3 | 5 |
| Low | 3 | 5 | 8 |
| Info | 5 | 8 | 13 |
| Total | 10 | 16 | 26 |

Every finding is fixed, with tests where a test fits. Two design notes are answered with a test alone, as the
details say.

## Findings of the web app

| ID | Severity | Finding | Fix |
|---|---|---|---|
| D-17 | Medium | An address of an EVM chain passed as a Starknet refund address, with a green check. | A Starknet account address lies at or above 2^160 (an account address is a hash over 251 bits; one that fits in 160 bits is an EVM address or a system address of Starknet). The app and the relay refuse the rest, and the field names an EVM address for what it is. |
| D-18 | Medium | The router opened no swap whose id carries `_` or `-`, which the relay issues, so a swap could be opened and never seen. | One form of an id, `SWAP_ID_PATTERN`, shared by the router and by the check of a created swap, which refuses an id of another form before the record is stored. |
| D-19 | Low | The upgrade of an old record tied the chain to the rename of the amount, so a record with one change and not the other was dropped for good. | Each change on its own; the upgrade and the check of a record are open to a test, with the three shapes of the older builds. |
| D-20 | Low | "A fresh address, a clean start" showed next to "In 1 of your swaps", from a scan read before the first swap. | The fresh notice shows only when the rule of the address passes, and a new receive reads the history afresh. |
| D-21 | Low | The amount step read the range at the rate of a later step, which for STRK hid a range five times wider. | The amount step reads the widest range over every provider of the chain at every rate it serves; the provider step settles the rate. |
| D-22 | Info | "Reading the range" showed for good when no provider gave a range. | A quiet line says that no range came through and that the next step tells what each provider takes. |
| D-23 | Info | The words of a closed chain are empty and its checks take nothing; opening it in the catalog would run silently wrong. | A test: every open chain has its words for a refund and takes a known address of its own. |
| D-24 | Info | Two lists said which provider serves which chain. | A test that the two agree both ways. |
| D-25 | Info | The record kept the exchanger's spelling of the refund address, not the user's. | Once the chain says that the two name one account, the record keeps the user's. |
| D-26 | Info | Dead code: `formatXmr` and `MONERO_ADDRESS_PATTERN`. | Removed; the tests moved to `formatFrom`. |

## Findings of the relay

| ID | Severity | Finding | Fix |
|---|---|---|---|
| R-13 | Medium | An address of an EVM chain passed as a Starknet refund address and as a Starknet deposit address. | As D-17: the floor of 2^160 in `src/starknet.mts`, used for the refund and the deposit of STRK; the refusal names an EVM address. |
| R-14 | Medium | A deposit that arrived in part showed as waiting, with the box to send again, and later as expired, while 1Click held the coins and refunded them at the deadline. | `INCOMPLETE_DEPOSIT` shows as confirming, and the relay never says that time ran out while a deposit is in. |
| R-15 | Medium | One budget of five calls a second served every call to 1Click, so that a flood of reads of a swap, which need no token yet, or of quotes for fresh amounts could starve every creation. | Three budgets, for estimates, reads, and creations; the state of a swap is kept for five seconds; nginx counts the requests that name NEAR Intents in a zone of their own, by client, for ranges, quotes, and reads. |
| R-16 | Low | The table of states was a plain object, so a state named like a member of `Object.prototype` passed the check of an unknown state. | A `Map`. |
| R-17 | Low | The amount of a swap was checked from the formatted number, while the exact base units in the answer went unused. | Every echoed field of the request, the amount in base units among them, and the amount in of the quote must equal what was sent; the amount reported is the one of the request. |
| R-18 | Low | A state without the deadline of the request fell back to the deadline of the quote, three days later. | No fallback: without the deadline of the request the relay names no time to send and never says that it ran out. |
| R-19 | Low | `fromAmount` without `from` meant XMR. | Only `xmrAmount` means XMR by itself, as the Mac app writes it; `fromAmount` without a coin is refused. |
| R-20 | Low | A refusal of 1Click whose message is a list reached the app as raw JSON. | The lines of a list are joined; JSON without a message gives a fixed text, never the body. |
| R-21 | Info | `toBaseUnits` dropped a third part of a number silently, and an amount with more decimals than a coin holds ended as a 500. | A third part throws; the relay refuses an amount with more decimals than its coin holds (XMR 12, STRK 18) with a 400. |
| R-22 | Info | A real swap was told from a dry one only by a field of the answer, and the placeholder addresses of a dry quote were not refused for a real swap. | `dry` is among the echoed fields that must match; a swap for either placeholder is refused before any call. |
| R-23 | Info | `/ready` read the token list alone, which may not check the key, so an expired partner key passed the deploy. | With a key, `/ready` asks one dry quote of the minimum as well, now and then; the warning of the deploy names no exchanger. |
| R-24 | Info | Three tables had to agree for a coin of origin at 1Click. | The origins come from one table, the minimum is typed by the coin, and a missing minimum stops the relay at its start. |
| R-25 | Info | The answer of a creation carried no time to send; the app learned it from the first read. | The creation names the time until which the exchanger takes the deposit, and the app starts its record with it. |
| R-26 | Info | An empty key sent an empty bearer. | An empty key is no key. |
| R-27 | Info | A constant and a helper that no test used. | Removed. |
| R-28 | Info | Comments that named ChangeNOW for code that serves every exchanger; tests that were missing. | The comments name the exchanger; tests for a swap of 1Click that differs from the request in its deposit address, its recipient, its pair, or its refund address, for a message that is a list, for a state named like a member of `Object.prototype`, and for an EVM refund address of STRK. |

## After the fixes

The checks of each part ran clean: the type check, the linter, the formatter, the tests (117 of the relay, 44 of
the web app), the build of the web app, and the build of the relay. The web app was walked once more through a swap
of STRK in headless Chrome against the relay on the machine: the amount step, the provider step with NEAR Intents and
ChangeNOW, the refund field refusing the address of the wallet on Robinhood Chain, the review, and the page of the
swap with its deposit address and its time to send.

Not checked: a funded swap of STRK through either provider to its end, what 1Click does with a second deposit on top
of a partial one, and the budget of calls that 1Click allows a key or none. The reads of a swap still pass without a
token while the apps before 0.3.1 run (K-18 of the first review); the budgets and the zone of nginx bound what a read
without a token can cost until the tokens become required.

