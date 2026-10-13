# Security scan of Zcash as the third way into the Kranox web app, through NEAR Intents, ChangeNOW, and SimpleSwap

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 13 Oct 2026, on the change after the
commit [`ccef264`](https://github.com/Kranox-Labs/App-Web/tree/ccef264) of the web app and the commit
[`06ae1c0`](https://github.com/Kranox-Labs/Relay/tree/06ae1c0) of the relay. Not an audit by Trail of Bits.

This report covers a quick scan of the change that opened Zcash as the third chain the coins can come from: the user
sends ZEC from their own Zcash wallet to a transparent deposit address of NEAR Intents, ChangeNOW, or SimpleSwap, and
USDG or ETH arrives in the wallet they connected on Robinhood Chain. Claude ran the skill in Claude Code and wrote
every finding. No person at Trail of Bits or at another firm read the code.

After you read this report, you know what the scan covered, what it found, and how each finding was fixed. The
reports of the earlier reviews are [security-review-0.2.0.md](security-review-0.2.0.md),
[security-review-consensys-0.3.1.md](security-review-consensys-0.3.1.md),
[security-review-sharp-edges-2026-10-10.md](security-review-sharp-edges-2026-10-10.md),
[security-review-sharp-edges-2026-10-12.md](security-review-sharp-edges-2026-10-12.md),
[security-review-sharp-edges-2026-10-12-providers.md](security-review-sharp-edges-2026-10-12-providers.md),
[security-review-sharp-edges-2026-10-13-node-trouble.md](security-review-sharp-edges-2026-10-13-node-trouble.md), and
[security-review-sharp-edges-2026-10-13-starknet.md](security-review-sharp-edges-2026-10-13-starknet.md).

## Scope

| Part | What the scan read | Version |
|---|---|---|
| Relay | The change to [Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay): the new `src/zcash.mts` (the transparent addresses of the Zcash mainnet), ZEC as a coin of origin in `src/exchanger.mts`, `src/changenow.mts`, `src/simpleswap.mts`, and `src/oneclick.mts` (with the refund address of a dry quote by coin), its minimum at 1Click in `src/config.mts`, and its addresses in `src/server.mts`, with the tests of each. | After `06ae1c0` |
| Web app | The change to [Kranox-Labs/App-Web](https://github.com/Kranox-Labs/App-Web): the new `src/gate/zcash-address.ts`, the facts of Zcash in `src/gate/chains.ts` with its link of payment, the catalog with three providers of ZEC in `src/gate/catalog.ts`, the copy, and the pages of receive and of a swap as they read the facts of the chain. | After `ccef264` |

The web app runs in the browser of a phone or of a desktop. The user connects the wallet that receives, and receive
walks through the chain the coins come from, the amount, the provider with its quote, the privacy review, and the
transaction: the user sends the coins from their own wallet of that chain to the deposit address of the provider, and
the coins arrive in the wallet they connected. From this change the chain can be Zcash as well as Monero and
Starknet: the three providers take ZEC at transparent addresses alone, both for the deposit and for a refund, and
the relay holds the keys of each.

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
steps of a swap of ZEC in headless Chrome against a relay on the machine with the real keys. The walk and the checks
of the relay made four real swaps of ZEC that nobody funds, two at NEAR Intents, one at ChangeNOW, and one at
SimpleSwap, with addresses made for the tests; one of them found a defect that no reading had (R-38).

## Summary

The scan found 15 findings: 2 Medium, 4 Low, and 9 Info. Nothing is High or Critical.

- No finding lets a swap go to another address, another amount, another chain, or another provider than the one the
  user saw. The check of a transparent address holds in both parts: the shape, the checksum of a double SHA-256,
  and then the two prefixes of the mainnet, so that a shielded address, a unified one, a testnet one, a Bitcoin one,
  or one with a wrong character never serves as a refund address, and a deposit address of another form stops the
  swap with its id.
- The Medium findings: the app said nothing about the transparent side of Zcash, so that a user with shielded ZEC
  could move it to their own transparent address first and read "All clear" for a swap that then paired their address
  with the arrival; and the relay read the field `expectedAmount` of SimpleSwap as the coin that arrives, while the
  first real exchange at SimpleSwap showed that it is the deposit expected, so that a swap of 0.1 ZEC showed
  "You get 0.1 USDG" and the record kept it.

| Severity | Web app | Relay | Total |
|---|---|---|---|
| Critical | 0 | 0 | 0 |
| High | 0 | 0 | 0 |
| Medium | 1 | 1 | 2 |
| Low | 2 | 2 | 4 |
| Info | 2 | 7 | 9 |
| Total | 5 | 10 | 15 |

Every finding is fixed, with tests where a test fits, but one note of the relay (R-37, the refund fee of 1Click, which
the estimate does not carry) that stays as a note. Three design notes of the web app (N1 to N3) and two of the relay
(R-35, R-36) are answered below.

## Findings of the web app

| ID | Severity | Finding | Fix |
|---|---|---|---|
| D-27 | Medium | Nothing said that the deposit is a transparent transaction on Zcash, so that its amount and the deposit address are public, and the address the user sends from as well unless they send from their shielded balance; the privacy step reported "All clear" for a swap whose side of origin is public, and the line of the chain, "through a transparent address", read like an instruction to deshield first. | Each chain carries a note of what its own side shows, shown on the privacy step under the three rules and on the page of the swap above the deposit address: for Zcash, that the deposit is transparent, what is public, and to send from the shielded balance so that the user's own address stays out of it; for Starknet, that the chain is public. The line of the chain reads "From your shielded balance, to a transparent deposit address." A test asks for the note of Zcash. |
| D-28 | Low | The page of a swap said "The rate holds until the time runs out" for a floating swap too, which is the default for ZEC and the only rate of NEAR Intents. | The lead of the page takes the rate: a fixed rate holds until the time runs out; at a floating one, what arrives follows the rate at the time of the deposit. |
| D-29 | Low | The amount step read the widest range over every provider and rate, and when one call failed, such as a 429 of a zone of nginx after a few visits, it computed the range from the rest and blocked an amount that the missing provider takes. | The step keeps whether every provider answered; a range with one missing shows "Not every provider gave its range right now" and blocks nothing, since the provider step names the range of each. |
| D-30 | Info | Comments that said Monero and Starknet were the open chains, that NEAR Intents is the provider with the best rate (a fact of one day; the tag decides at run time), and a test list in the README that left out the addresses and the catalog. | Reworded. |
| D-31 | Info | Tests that were missing: the prefix check of a transparent address, the only line that can refuse a string that passed the shape and the checksum, was reached by no test in either part; a too-long address, `t2…`, a unified address, a non-base58 character; that the first provider of a chain serves the rate the chain starts at, or the provider step would switch it on arrival; the least amount of ZEC in the link of payment, which must write without an exponent. | Tests for each: a vector with the bytes 0x1CB9 and a right checksum, built with a small encoder of base58 in the test, matches the shape and is refused; the other cases as named; the link `zcash:<address>?amount=0.00000001`. |

Design notes of the web app, not defects:

- N1: some exchanges issue TEX addresses of ZIP 320 (`tex1…`) for deposits of ZEC, to require transparent senders.
  If a provider switches, the app refuses the deposit address and the swap fails closed with its id, and the relay
  does the same (R-36); the link of payment would need the form too. Worth a watch, not a change.
- N2: the rule of the amount pairs swaps by the amount of the coin of origin per chain, not by the amount that
  arrives on Robinhood Chain, so two swaps from different chains that pay the same USDG are not paired. A rule for
  later, since the amount that arrives floats.
- N3: the switch of the rate on the provider step clears no quotes, which is unreachable in the flow of ZEC: the
  fixed card is disabled while NEAR Intents is chosen, and a batch of quotes replaces them within a second.

## Findings of the relay

| ID | Severity | Finding | Fix |
|---|---|---|---|
| R-38 | Medium | The relay read `expectedAmount` of an exchange at SimpleSwap as the coin that arrives, with `amountTo` as a fallback, from the documentation of v3. The first real exchange, 0.1 ZEC at a floating rate, answered `amountFrom` "0.1", `expectedAmount` "0.1", and `amountTo` "107.647781" while waiting: `expectedAmount` is the deposit that SimpleSwap expects, in the coin of origin. A swap at SimpleSwap, of XMR since 12 Oct 2026 as well, showed "You get 0.1 USDG" and kept it in the record; the coins themselves were not touched, since SimpleSwap pays by its own rate. Found by the check against the live API, not by the reading of the code. | The coin that arrives is `amountTo` alone, at creation and in the state of a swap, an estimate until the exchange is done and the fact then; an answer without it is refused with a 502. The tests carry the fields as SimpleSwap writes them, and the head of the module records the answer. |
| R-29 | Low | The floor of the bridge of 1Click, in a refusal of a dry quote in base units ("Amount is too low for bridge, try at least 132000"), was neither read nor compared with the minimum of the relay, and `/ready` asked a dry quote of STRK alone; a floor above the minimum of ZEC would have reached the app as a 422 with the words of 1Click, and the deploy would have stayed green. | The relay reads the floor of a refusal as the least that goes through, so that the app shows a range; `/ready` with a key asks one dry quote of the minimum of each coin, with a budget of its own, and fails when the floor of 1Click lies above the minimum of the relay. The comment of the minimum says that whether the floor moves with the price is not checked. |
| R-30 | Low | The refund address of a dry quote of ZEC, a made-up t1 address, was pinned by no test as an address of its chain, and the refusal of a real swap for a placeholder (R-22) was untested for the refund half. A wrong checksum in that constant would have broken every estimate of ZEC through 1Click while every test and `/ready` passed. | A test asks a dry estimate of STRK and of ZEC, checks the refund address sent with the check of its chain, and asks a swap for that address, which is refused with no call sent. |
| R-31 | Info | The check of the prefixes of a transparent address was reached by no test (as D-31): a 35-character string of the right shape with a right checksum and the bytes 0x1CB9 writes as `t1…` and only that line refuses it. | The same vector as in the web app, built with an encoder of base58 in the test; the two prefixes of the mainnet with a right checksum are taken. |
| R-32 | Info | The test of ZEC at the server made swaps through SimpleSwap and 1Click alone: a deposit address of another form from ChangeNOW and a refund address that differs were untested for ZEC. | A swap of ZEC through ChangeNOW as asked, and two that are refused with the id of the exchange: a deposit address that is not transparent, and another refund address. |
| R-33 | Info | Comments that named Monero and Starknet alone, 1Click as the exchanger of Starknet, the id of a swap at 1Click as hex alone, and the deadline of 20 minutes from the wallet on Starknet alone. | Reworded; the deadline names the blocks of Zcash, every 75 seconds, so that a deposit sent in the last minutes is in a block before the deadline. |
| R-34 | Info | SimpleSwap kept two lists by hand, its sides and its origins, which could disagree, and `/ready` asked one range of XMR alone, so that SimpleSwap dropping ZEC would show first to a user. | The origins come from the one table of the sides; `/ready` asks one range of each coin, which the cache keeps rare. |
| R-35 | Info | The comment said the placeholders of a dry quote belong to nobody, without saying how the one of Zcash was made. | The comment says: the public key hash of a fixed text, with the prefix t1 and its checksum, so that nobody holds its key; the test of R-30 pins it. |
| R-36 | Info | Not checked live: the form of the deposit address of ZEC at ChangeNOW and at SimpleSwap, and whether each exchanger takes a t3 (script hash) refund address, which the check allows. | Checked on 13 Oct 2026 with one unfunded swap each: ChangeNOW and SimpleSwap give t1 deposit addresses and take a t3 refund address, and 1Click quotes with a t3 refund address. A deposit address of another form would stop the swap with its id, as before. |
| R-37 | Info | The refund fee of 1Click for ZEC (0.00032 ZEC, 6.4% of the minimum of 0.005) is in its answer, and the estimate of the relay has no field for it; a deposit after the deadline comes back with the fee taken and the app never said so. | Kept as a note: to carry the refund fee through the estimate when the app shows the fees of a refund. |

## After the fixes

The checks of each part ran clean: the type check, the linter, the formatter, the tests (124 of the relay, 47 of
the web app), the build of the web app, and the build of the relay. The web app was walked once more through a swap
of ZEC in headless Chrome against the relay on the machine: the chain step, "From 0.005 ZEC", the provider step with
NEAR Intents, ChangeNOW, and SimpleSwap and the fixed card disabled at NEAR Intents, the privacy step with the note
of Zcash under "All clear", the refund field refusing a shielded address and taking a transparent one, the review,
and the page of the swap with the note, the lead of a floating rate, a t1 deposit address, the link of payment after
ZIP 321, and the time to send. The two swaps made at ChangeNOW and at SimpleSwap read back with the coin that arrives
in the hundreds of USDG for 0.1 ZEC, as their quotes said.

Not checked: a funded swap of ZEC through any provider to its end, whether the floor of the bridge of 1Click moves
with the price, and the form of the deposit addresses of the providers over time (N1). The reads of a swap still pass
without a token while the apps before 0.3.1 run (K-18 of the first review); the budgets and the zones of nginx bound
what a read without a token can cost until the tokens become required.
