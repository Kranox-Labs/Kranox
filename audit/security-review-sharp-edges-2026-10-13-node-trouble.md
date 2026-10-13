# Security scan of the look for the trouble with the node, and of the close of a running card

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 13 Oct 2026, on the change after the
commit [`489f3d5`](https://github.com/Kranox-Labs/Kranox/tree/489f3d5) of the Mac app. Not an audit by Trail of
Bits.

This report covers a quick scan of the change that lets the Mac app say why its node or the relay does not answer,
such as a proxy that is not running, and lets the user close the card of a swap that still runs, after a word about
what that means. Claude ran the skill in Claude Code and wrote every finding. No person at Trail of Bits or at
another firm read the code.

After you read this report, you know what the scan covered, what it found, and how each finding was fixed. The
reports of the earlier reviews are [security-review-0.2.0.md](security-review-0.2.0.md),
[security-review-consensys-0.3.1.md](security-review-consensys-0.3.1.md),
[security-review-sharp-edges-2026-10-10.md](security-review-sharp-edges-2026-10-10.md),
[security-review-sharp-edges-2026-10-12.md](security-review-sharp-edges-2026-10-12.md), and
[security-review-sharp-edges-2026-10-12-providers.md](security-review-sharp-edges-2026-10-12-providers.md).

## Scope

| Part | What the scan read |
|---|---|
| The look | `lib/core/socks.dart` (moved from `lib/bridge/`, with a plain connection through the proxy), the new `lib/core/connection_probe.dart`, the new settings of the look in `lib/config/app_config.dart`, and the look and the reconnect in `lib/wallet/controller.dart` |
| The bridge and the screens | The close of any card, the look for the trouble with the relay, and the merge of a read state in `lib/bridge/controller.dart`; the word of the relay from `lib/bridge/pay_controller.dart`; the question before a close in `lib/ui/widgets/confirm_sheet.dart` and `lib/ui/widgets/swap_steps.dart`; the notice on Home, the line in the sidebar, the line under the relay in Settings, the swaps on the activity page, and the way from there to the page of a swap, in `lib/ui/`; the words in `lib/ui/copy.dart` and `lib/ui/format.dart` |

The app reaches its Monero node and the relay of Kranox through a SOCKS proxy when the user set one, such as Tor at
127.0.0.1:9050. From this change, once wallet2 has reported no connection to the node for five seconds, the app looks
for the trouble with plain connections that carry nothing: to the proxy, then through the proxy to the node, with the
name of the node for the proxy to resolve; or, without a proxy, to the name and the node straight. It tells the user
what it found, with a button that connects again. The same look serves the relay when a call to it fails. A card of
a swap can close whether the swap runs or ended; the app keeps following a swap whose card closed, and the activity
page lists every swap.

The scan left out the code that the earlier reviews read and that did not change, the web app, the relay, the site,
the exchanger, and the wallets of the user.

## Method

The scan used the skill `sharp-edges` 1.1.3 of the marketplace `trailofbits/skills`, at the commit `82fe822` of
28 Sep 2026, under the license CC-BY-SA-4.0. Claude Code ran it with the model Claude Fable 5.1.

The skill looks for designs that make mistakes easy: dangerous defaults, silent failures, settings that fail with one
wrong value, and values of one kind that pass for another. Two agents of the skill read the two parts, each with the
diff and the full sources around it, and wrote their findings with a scenario and a fix each. Claude then read each
finding against the code, fixed it with a test where a test fits, and ran the checks of the app: the analyzer, the
formatter, the unit tests, and the test of the screens on the Flutter tester.

## Summary

The scan found 22 findings: 1 High, 6 Medium, 9 Low, and 6 Info. Nothing is Critical.

- No finding touches the keys, the seed, or a payment: the change makes plain connections that carry nothing, and
  closes cards.
- The High finding was in the close of a card that still runs: the app stopped following such a swap the moment it
  failed or ran out, so a refund that came later never showed. The card of a closed swap comes back now whenever the
  swap leaves the good way: a failure, a hold, a refund, or a deposit that did not come.
- The Medium findings were about the words of the look and of the close: a look that failed read as "no trouble", a
  report could name a node or a proxy that the user had changed since, the question before a close promised what the
  app cannot promise, the close of a failed card stopped the check for a refund without a word, and the tests left
  the race and the relay look uncovered.

| Severity | The look | The bridge and the screens | Total |
|---|---|---|---|
| High | 0 | 1 | 1 |
| Medium | 2 | 4 | 6 |
| Low | 6 | 3 | 9 |
| Info | 1 | 5 | 6 |

Every finding is fixed, with the notes that the table names.

## Findings

| ID | Part | Severity | Finding | Status |
|---|---|---|---|---|
| A-01 | The look | Medium | A failure inside a look read as "no trouble" and escaped unhandled | Fixed |
| A-02 | The look | Medium | A report could name a node or a proxy that the user had changed since | Fixed |
| A-03 | The look | Low | "Try again" ran twice on two clicks and dropped a refusal of wallet2 | Fixed |
| A-04 | The look | Low | A proxy that is no SOCKS5 proxy read as "Tor may still be starting" | Fixed |
| A-05 | The look | Low | The probe took a timeout of nothing | Fixed |
| A-06 | The look | Low | A dispose during a look ended in a notification of a dead controller | Fixed |
| A-07 | The look | Low | The delay and the interval of the look ran on the clock of the Mac | Fixed |
| A-08 | The look | Info | The state "unknown" as a sentinel, and a plain connection with a consumed stream | Fixed in part |
| A-09 | The look | Low | Tests of the look | Fixed in part |
| B-01 | The bridge | High | A card closed while running stopped being followed when the swap failed or ran out | Fixed |
| B-02 | The bridge | Medium | A failure, a hold, or a refund of a closed swap never reached the user | Fixed |
| B-03 | The screens | Medium | The question before a close promised what the app cannot promise | Fixed |
| B-04 | The screens | Medium | The close of a failed card stopped the check for a refund without a word | Fixed |
| B-05 | The bridge | Low | A close after a lock threw, and the question outlived the lock | Fixed |
| B-06 | The bridge | Low | A write of the file that failed during a read skipped the cleanup of the lock | Fixed |
| B-07 | The bridge | Info | The look for the relay kept state across a lock and said nothing for a relay that takes a connection | Fixed |
| B-08 | The bridge | Info | A relay address without a host made the look throw | Fixed |
| B-09 | The bridge | Info | Two notifications after a dispose | Fixed |
| B-10 | Tests | Medium | Tests of the close and of the relay look | Fixed |
| B-11 | The screens | Info | The tab of a page followed a card the user had closed | Fixed |
| B-12 | The screens | Low | "Try again" could throw and run twice | Fixed, with A-03 |
| B-13 | The screens | Info | A doc comment on the wrong part | Fixed |

## Details of each finding

### A-01: a failure inside a look read as "no trouble" and escaped unhandled

The look ran in a `try` with a `finally` that wrote the report whatever happened, so a look that threw, such as on a
node name too long for the command of SOCKS5, left a report of no trouble: "takes a connection, but the wallet got
no answer from it yet", the opposite of the truth, and the failure escaped from an unawaited future every interval.
Fixed: a look that throws records `ConnectionTrouble.lookFailed` ("Kranox could not look for the trouble. Check the
node and the proxy in Settings.") and hands the failure to the zone of the app once; `parseNodeAddress` keeps a host
name within the bounds of DNS (253 characters, labels of 63), which fit the command of SOCKS5; and the settings
check every node of their file with it, as they checked the proxy already. Tests: a look that throws, a name of 254
characters, a node of the file of another form.

### A-02: a report could name a node or a proxy that the user had changed since

The words took the node and the proxy of the settings as they stood when drawn, while the report could come from a
look before a change of them, or from a look in flight during the change. Fixed: every connect forgets the look (the
report, the silence, and a look in flight, through its generation), the report carries the node and the proxy that
the look tried, and the words name those. Test: a change of the proxy and of the node drops the report, and a report
names what was tried.

### A-03: "Try again" ran twice on two clicks and dropped a refusal of wallet2

The button called `reconnect()` and dropped its future; the button was busy only while a look ran, not while wallet2
connected; a refusal of wallet2 other than a node that does not answer escaped unhandled. Fixed: one reconnect runs
at a time and a second call joins it, `reconnecting` keeps the button busy, a refusal stays in `reconnectFailure`
and shows under the notice, and a lock waits for a reconnect in flight. Test: two reconnects at once connect once,
and a refusal of wallet2 shows and clears on the next try.

### A-04: a proxy that is no SOCKS5 proxy read as "Tor may still be starting"

Every refusal of the proxy counted as a host it could not reach, so the control port of Tor, an HTTP proxy, or a
SOCKS4 proxy had the user wait for Tor. Fixed: the SOCKS helper marks a greeting that is not SOCKS5, and the probe
names `proxyNotSocks5`: "The proxy at … answers, but it is no SOCKS5 proxy. Tor listens at 127.0.0.1:9050; check the
proxy in Settings." Test: a proxy that answers the greeting with the bytes of HTTP.

### A-05: the probe took a timeout of nothing

A timeout of zero made every step fail at once, so every look named the first step. Fixed: `run` refuses a timeout
of nothing with an `ArgumentError`. The timeout stays at 4 seconds a step; the words of a node that the proxy could
not reach hedge "Tor may still be starting". Test: a timeout of nothing throws.

### A-06: a dispose during a look ended in a notification of a dead controller

`dispose` cancelled the poll but let a look in flight notify the listeners when it ended. Fixed: the controller
remembers its dispose, bumps the generation of the look, and a look that ends after it changes nothing.

### A-07: the delay and the interval of the look ran on the clock of the Mac

A clock set back stopped the periodic look for as long as it was set back. Fixed: the look runs on a clock of the
controller that only moves forward (a `Stopwatch`), which a test replaces. Test: the delay of 5 seconds and the
interval of 20 seconds, on the clock of the test.

### A-08: the state "unknown" as a sentinel, and a plain connection with a consumed stream

The app told "no read yet" from the identity of `WalletStatus.unknown`, which a backend that builds an equal state
of its own would miss; and `connectThroughSocks` returned a socket whose stream was already listened to. Fixed in
part: the plain connection is `checkThroughSocks` now, which closes the connection itself; the sentinel stays, with
its meaning in the doc of `WalletStatus.unknown`, since the engine always builds a state of its own and the only
backends that report the sentinel are those of the tests.

### A-09: tests of the look

Fixed in part: tests of a proxy that is no SOCKS5 proxy, of a proxy that takes the connection and answers nothing,
of a timeout of nothing, of a look that throws, of a change of the node or the proxy, of two reconnects at once, and
of the delay and the interval on a clock of the test. The proxy tests name `node.invalid`, which never resolves, so
they show that the proxy gets the name and the resolver does not. The test of a name without an address keeps its
real resolver, with its reason in the test. A test of a lock during a look is left: the generation check covers it.

### B-01: a card closed while running stopped being followed when the swap failed or ran out

`watched` read the flag `closed` as "the user has read the result", so a swap whose card the user closed while it
waited stopped being followed the moment it failed or ran out: the poll ended, a refund that came later was never
read, and the list said "Failed" for good. Fixed: the state of a read brings the card of a closed swap back when the
swap leaves the good way (a failure, a hold, a refund, or a deposit that did not come), through `reopen()`, so that
the user sees it and the app follows it again. Test: a closed card comes back on a failure and the swap is followed
to its refund.

### B-02: a failure, a hold, or a refund of a closed swap never reached the user

After a close while running, the swap stood in the lists alone, with its state on one small line. Fixed with B-01:
the card comes back under the form on any of those states, and the pages open on the way from or to Robinhood Chain
while a card is in view.

### B-03: the question before a close promised what the app cannot promise

The words said that the XMR arrives and the coin reaches the recipient as facts, covered a swap on hold with the
same words, and called a payment "left" before its XMR had left. Fixed: the words say that ChangeNOW goes on, that
Kranox keeps following, and that a failure or a refund brings the card back; a swap on hold gets its own words with
the address of the support; a receive that waits learns that the swap stays open at ChangeNOW for about a day with
its deposit address on its page; and the card of a payment has no close until its XMR has left.

### B-04: the close of a failed card stopped the check for a refund without a word

The new close button on a compact card closed a failed or expired swap at once, after which the app stopped asking
for its refund, with no way back. Fixed: the question comes for every swap the app still follows, and for a failed
or expired one it says "Stop checking this swap?" with what that means. Test: the close of a failed card asks first.

### B-05: a close after a lock threw, and the question outlived the lock

A lock while the question showed left the question over the unlock screen, and an answer then threw on the closed
file of the swaps and set the state of a page that was gone. Fixed: `closeSwap` does nothing after a lock or for a
swap that is gone, a lock closes every sheet over the page, and the way back from the page of a swap checks that the
page is still there. Test: a close after a lock changes nothing.

### B-06: a write of the file that failed during a read skipped the cleanup of the lock

A read whose write of the file failed made the lock path throw before it closed the file of the swaps and dropped
them from memory. Fixed: a read that fails hands its failure to the zone of the app once, and nothing that waits for
the read, such as a lock, throws.

### B-07: the look for the relay kept state across a lock and said nothing for a relay that takes a connection

The trouble, the time of the last look, and the answer of the relay survived a lock; a relay that failed again soon
after an answer got no fresh look; and a relay that took a connection but did not answer showed "Relay offline" with
no line. Fixed: the lock forgets all of it, an answer clears the time of the last look, and the settings say "The
relay takes a connection, but it did not answer."

### B-08: a relay address without a host made the look throw

A relay address of a dev build without a scheme gave an empty host, which the lookup refused with an error that
escaped. Fixed: the look refuses an empty host as a failed look, through A-01.

### B-09: two notifications after a dispose

The reads of the states and the check of the relay notified after their awaits without a check of the dispose.
Fixed.

### B-10: tests of the close and of the relay look

The comment of the merge named a test that did not exist, and the relay look, the close from the page of a swap, and
the way from the activity page had no test. Fixed: a read held by the relay while the card closes, a closed swap
followed to its refund, the relay look with a probe of the test, the close from the page of a swap, the question of
a failed card, the way from the activity page to the page of a swap, and the count of the looks on the home.

### B-11: the tab of a page followed a card the user had closed

The pages opened on the way from or to Robinhood Chain whenever a followed swap existed, even one whose card the
user had closed, and the way back from the page of a swap led to the Monero tab. Fixed: the tab follows the cards in
view, and the way back leads to the way where the list is.

### B-12: "Try again" could throw and run twice

Fixed with A-03.

### B-13: a doc comment on the wrong part

The doc of the cards sat above `confirmCloseSwap`. Fixed.

## After the fixes

`CHECKED` 13 Oct 2026: `fvm flutter analyze` clean, `fvm dart format`, 231 unit tests, and the test of the screens
on the Flutter tester. One older test of the bridge, "quotes an amount and allows a swap only above the minimum",
failed once in a run of the whole suite and passed alone and in the next whole run: it waits a fixed time for a
quote, which a loaded machine can miss.
