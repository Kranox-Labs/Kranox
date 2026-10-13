# Security scan of the way out of the Kranox web app: USDG and ETH on Robinhood Chain into Monero, Zcash, and Starknet

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 13 Oct 2026, on the change after the
commit [`dbc95f8`](https://github.com/Kranox-Labs/App-Web/tree/dbc95f8) of the web app and the commit
[`ed906e2`](https://github.com/Kranox-Labs/Relay/tree/ed906e2) of the relay. Not an audit by Trail of Bits.

This report covers a quick scan of the change that opened the way out: the user sends USDG or ETH from the wallet
they connected on Robinhood Chain to a deposit address of ChangeNOW, SimpleSwap, or NEAR Intents on that chain, and
XMR, ZEC, or STRK arrives at an address of their own on Monero, Zcash, or Starknet, at the floating rate. The wallet
sends the deposit itself, one transfer that the user confirms in it, through a button of the page of the swap. The
same change renamed the way in to "In" in the app. Claude ran the skill in Claude Code and wrote every finding. No
person at Trail of Bits or at another firm read the code.

After you read this report, you know what the scan covered, what it found, and how each finding was fixed. The
reports of the earlier reviews are [security-review-0.2.0.md](security-review-0.2.0.md),
[security-review-consensys-0.3.1.md](security-review-consensys-0.3.1.md),
[security-review-sharp-edges-2026-10-10.md](security-review-sharp-edges-2026-10-10.md),
[security-review-sharp-edges-2026-10-12.md](security-review-sharp-edges-2026-10-12.md),
[security-review-sharp-edges-2026-10-12-providers.md](security-review-sharp-edges-2026-10-12-providers.md),
[security-review-sharp-edges-2026-10-13-node-trouble.md](security-review-sharp-edges-2026-10-13-node-trouble.md),
[security-review-sharp-edges-2026-10-13-starknet.md](security-review-sharp-edges-2026-10-13-starknet.md), and
[security-review-sharp-edges-2026-10-13-zcash.md](security-review-sharp-edges-2026-10-13-zcash.md).

## Scope

| Part | What the scan read | Version |
|---|---|---|
| Relay | The change to [Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay): the way out in `src/exchanger.mts` (the methods of the exchangers, the decimals of the coins on Robinhood Chain), in the three exchangers `src/changenow.mts`, `src/simpleswap.mts`, and `src/oneclick.mts` (with the minimums and the dry quotes of the way out, and the check of `/ready`), the minimums in `src/config.mts`, and the three routes with their checks in `src/server.mts`, with the tests of each. | After `ed906e2` |
| Web app | The change to [Kranox-Labs/App-Web](https://github.com/Kranox-Labs/App-Web): the transfer of the wallet in `src/wallet/transfer.ts`, the way out in the client of the relay, the store of swaps with the direction of a swap, the draft, the privacy check, the amounts, the five steps of the way out in `src/ui/pages/out/`, the page of a swap with the button that sends, the routes with the move of `/receive` to `/in`, and the copy. | After `dbc95f8` |

The web app runs in the browser of a phone or of a desktop. Out walks through the chain the coins go to, the amount
of USDG or ETH to send, the provider with its quote, the address on that chain with the privacy review of the wallet
that sends, and the review; "Open the gate" makes the swap, and the page of the swap shows the deposit address on
Robinhood Chain, the amount to send exactly, and the button "Send from your wallet", which asks the connected wallet
for one transfer: a plain transfer of ETH, or `transfer(to, amount)` of the contract of USDG. The refund of a swap out
goes to that wallet. The relay checks every created exchange against its request, as on the way in.

The scan left out the code that the earlier reviews read and that did not change, the Mac app, the site, the
exchangers themselves, and the wallets of the user.

## Method

The scan used the skill `sharp-edges` 1.1.3 of the marketplace `trailofbits/skills`, at the commit `82fe822` of
28 Sep 2026, under the license CC-BY-SA-4.0. Claude Code ran it with the model Claude Fable 5.1.

The skill looks for designs that make mistakes easy: dangerous defaults, silent failures, settings that fail with one
wrong value, and values of one kind that pass for another. One agent of the skill read both parts with the list of
the changed files and the full sources around them, with questions to probe: whether the amount the wallet transfers
can differ from the amount the swap expects, whether the deposit address or the amount shown can come from anywhere
but a checked answer of the relay, whether a swap out can take a refund to another wallet than the one that sends,
whether the records of the way out mix with those of the way in, whether the move of `/receive` can open a path it
should not, whether the addresses of a dry quote are refused for a real swap out, whether the key of a creation tells
the two ways apart, whether `eth_sendTransaction` can be triggered by anything but a click of the user, and whether
the guard of the steps lets a step open without what it needs. Claude then read each finding against the code, fixed
it with a test where a test fits, and ran the checks of each part: the type check, the linter, the formatter, the
tests, and, for the web app, the build and two walks in headless Chrome against a relay on the machine with the real
keys: one through the five steps of the way out, which made one real swap of 50 USDG into XMR at ChangeNOW that
nobody funds, with a made-up wallet that answered the transfer with a made-up hash; and one of the page of that swap
in four browsers, with the wallet on Robinhood Chain, with a wallet that named no hash, with a wallet on another
network, and with a record a day old.

## Summary

The scan found 10 findings: 1 High, 1 Medium, and 8 Low. Nothing is Critical.

- The High finding: the button "Send from your wallet" asked the wallet for the transfer without naming the chain,
  and the page checked the address of the wallet but not its network; a wallet that the user had switched to another
  network after "Open the gate" would have signed a transfer of the coins of that network to an address that only
  Robinhood Chain knows. The transfer now names Robinhood Chain, which makes a wallet on another network refuse it,
  and the page shows the switch to Robinhood Chain in its place.
- The Medium finding: after a failure that was not a refusal of the user, the page said that the wallet did not
  send and offered the button again, while a wallet of a smart account may answer another thing than a hash having
  sent all the same; one swap could have taken two deposits. A wallet that names no hash now counts as having sent,
  with the record saying so, and the words after another failure say to check the wallet before sending again.
- No finding lets the amount the wallet transfers differ from the amount the swap expects, lets the deposit address
  come from anywhere but a checked answer of the relay, lets a swap out take a refund to another wallet than the one
  that sends, or lets the two ways share a key of a creation.

| Severity | Web app | Relay | Total |
|---|---|---|---|
| Critical | 0 | 0 | 0 |
| High | 1 | 0 | 1 |
| Medium | 1 | 0 | 1 |
| Low | 5 | 3 | 8 |
| Info | 0 | 0 | 0 |
| Total | 7 | 3 | 10 |

Every finding is fixed, with tests where a test fits. Two notes (N1, N2) are answered below.

## Findings of the web app

| ID | Severity | Finding | Fix |
|---|---|---|---|
| D-32 | High | The transfer that the button asks of the wallet carried no chain, and the page checked the address of the wallet against the refund address of the swap but not its network, which the wallet reports on every change. The steps hold the user on Robinhood Chain up to "Open the gate", but the page of the swap is opened later, from the activity or a bookmark, and a wallet switched to another network for another site, or a wallet that keeps one network for every site, would have signed a plain transfer of the ETH of that network, or a call of the address of the contract of USDG on that network, to the deposit address of the exchanger, which only Robinhood Chain knows. The words of the page said "on Robinhood Chain" all the while. | The transfer names the chain of Robinhood Chain (`chainId: 0x1237`), so that a wallet on another network refuses it itself, and the page shows the button only for a wallet on Robinhood Chain: on another network it shows the line "Your wallet is on another network" and the switch to Robinhood Chain. A test pins the chain in the transfer; the walk of the page with a wallet on chain 1 showed the switch and no button. |
| D-33 | Medium | Every failure of the transfer but a refusal of the user got the line "The wallet did not send. Try again, or send by hand", with the button still there, and a wallet whose answer was not a hash of 32 bytes got the same, although a wallet of a smart account answers another identifier, and a session over WalletConnect may drop after the user confirmed: the transfer out, the page saying it was not, and one swap taking two deposits. What NEAR Intents does with a second deposit on one address is not checked. | A wallet that answers something other than a hash counts as having sent: the record keeps the time it sent, the page says that the wallet named no transaction and that the provider sees the deposit after a few confirmations, and the button goes away; the hash comes with the state of the swap from the provider. After a failure that is not a refusal of the user, the line says to check the activity of the wallet before sending anything to the address again, since one swap takes one deposit. Tests of the transfer and of the record. |
| D-34 | Low | A swap out at ChangeNOW names no time to send (`validUntil` null), so a record weeks old in the storage of the browser still offered one tap that signs a transfer to its old deposit address; whether ChangeNOW still watches an old address of the standard flow is not checked. | A ceiling of the app: a day after a swap out opened, without a time of its own, the button goes away and the page says to open a new swap instead. The walk of the page with a record 25 hours old showed the line and no button. |
| D-35 | Low | The check of a record from the storage of the browser took any text as the deposit address and the refund address of a swap out, which now feed the transfer that the wallet signs; the transfer refuses an address that is not one of an EVM chain, but a well-formed other address, put there by an extension or a hand in the tools of the browser, would have passed to the code and to the wallet. | A record of a swap out needs an address of Robinhood Chain as its deposit address and as its refund address, or it stays out of the store. A test. |
| D-36 | Low | The card of the scan of an address on the privacy page counted the swaps that paid an address, so an address that sent a swap out showed "In none of your swaps here", while the rule of the address on the steps read the sender of a swap out. | The card reads the address of a swap whichever way it went, with the one helper of the privacy check. |
| D-37 | Low | The transfer took the coin, the amount, the sender, and the recipient as four values in a row, of which three are text: a sender and a recipient swapped would have compiled, with the wallet paying the address of the user (wasted fee, no loss), and the sender went unchecked. | The transfer takes one object of named fields, and refuses a sender or a recipient that is not an address of an EVM chain. A test. |
| D-38 | Low | A change of the coin on the amount step kept the figure typed: 100 USDG became 100 ETH, which the review and the wallet would have shown with its coin, and the line of the balance would have warned about. | A change of the coin starts the figure over. |

Design notes of the web app, not defects:

- N1: the address of the contract of USDG in the app is written in mixed case. Claude checked its checksum of EIP-55
  on 13 Oct 2026 with keccak-256: it is the right one, so a wallet that checks the case takes the transfer.
- N2: the amount of a swap out passes through a number in the record, written back with six decimals; an amount to
  send has at most nine digits before the point and six after, which a number holds exactly, and the relay compares
  the amount of the exchanger with the request within a billionth. Keeping the text of the request in the record,
  and having the relay echo it, would keep the figure out of a number altogether; a hardening for later.

## Findings of the relay

| ID | Severity | Finding | Fix |
|---|---|---|---|
| R-39 | Low | The guard that refuses a real swap for the addresses of a dry quote (R-22) compared the text: the address of nobody on Starknet without its leading zero, or in another case of its digits, is the same account by value and passed. A leak of the placeholder would carry its exact text, so the guard still caught the bug it was written for. | A hex address is compared by its value, in and out. Tests with the placeholder without its zero and in another case. |
| R-40 | Low | The routes of the way out took a request without a provider as one for ChangeNOW, through the default that the Mac app needs on the way in; no client of the way out predates the field, so a bug of a client that drops it would quietly have made a swap at ChangeNOW (the web app refuses an answer for another provider, so none would have reached the user). | A request of the way out without a provider is refused with 400. Tests. |
| R-41 | Low | `/ready`, which needs no key, asked 1Click again on every call while a check failed, up to seven calls each, four of them new with the way out; a flood of `/ready` while 1Click is down would have spent the budget on the same answer. | A failed check is kept for a minute and answered again without a call. A test. |

## What the scan did not cover

- The way in, the Mac app, the site, and the code that did not change.
- The exchangers themselves: what each does with a deposit of another amount than the one of the swap, or with a
  second deposit on one address; whether ChangeNOW and SimpleSwap still watch an old deposit address of the standard
  flow; and whether 1Click pays STRK to an address written in another case than the one sent.
- A funded swap out at any of the three exchangers to its end: the walks made one real swap at ChangeNOW that
  nobody funds, and none at SimpleSwap or at NEAR Intents.

## Checks

The relay: 133 tests, the type check, the linter, and the formatter pass. The web app: 60 tests, the type check, the
linter, the formatter, and the build pass; the two walks in headless Chrome against the relay on the machine passed,
with the pictures of each page.
