# Security scan of Tor built into the Kranox app for Mac

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 13 Oct 2026, on the change after the
commit [`e18f8d5`](https://github.com/Kranox-Labs/Kranox/tree/e18f8d5) of the app. Not an audit by Trail of Bits.

This report covers a quick scan of the change that built Tor into the app: arti, the Tor client of the Tor Project,
starts inside the app through the plugin `tor` of Foundation Devices and runs a SOCKS5 proxy on this Mac, and the
wallet reaches its node and the relay through it, with no Tor of the user to run. The switch is on from the first
start. Claude ran the skill in Claude Code and wrote every finding. No person at Trail of Bits or at another firm read
the code.

After you read this report, you know what the scan covered, what it found, and how each finding was fixed. The
reports of the earlier reviews are [security-review-0.2.0.md](security-review-0.2.0.md),
[security-review-consensys-0.3.1.md](security-review-consensys-0.3.1.md),
[security-review-sharp-edges-2026-10-10.md](security-review-sharp-edges-2026-10-10.md),
[security-review-sharp-edges-2026-10-12.md](security-review-sharp-edges-2026-10-12.md),
[security-review-sharp-edges-2026-10-12-providers.md](security-review-sharp-edges-2026-10-12-providers.md),
[security-review-sharp-edges-2026-10-13-node-trouble.md](security-review-sharp-edges-2026-10-13-node-trouble.md),
[security-review-sharp-edges-2026-10-13-starknet.md](security-review-sharp-edges-2026-10-13-starknet.md),
[security-review-sharp-edges-2026-10-13-zcash.md](security-review-sharp-edges-2026-10-13-zcash.md), and
[security-review-sharp-edges-2026-10-13-out.md](security-review-sharp-edges-2026-10-13-out.md).

## Scope

| Part | What the scan read | Version |
|---|---|---|
| App | The change to [Kranox-Labs/Kranox](https://github.com/Kranox-Labs/Kranox): the engine of Tor on the plugin (`lib/core/tor_engine.dart`), the service with its states (`lib/wallet/tor_service.dart`), the switch in the settings (`lib/wallet/settings.dart`), the controller of the wallet (the wait for Tor, the proxy, the node of the own network, the start and the stop), the client of the relay and the bridge (no call and no look while the wallet waits), the trouble of a connection, the screens (Settings, the home, Privacy), the words, the start of the app, the entitlements, the Podfile, the packaging with its notices, and the tests; and the plugin at the pinned commit, with the parts of arti 1.7.0 it leans on. | After `e18f8d5` |

The app is a self-custodial Monero wallet for Mac with a bridge to Robinhood Chain through the relay of Kranox. Until
this change the user could set a SOCKS5 proxy of their own, such as a Tor on this Mac, in Settings; the wallet and the
relay went through it. From this change the app starts Tor itself and goes through it by default; the proxy of the
user stays for those who turn the switch off.

The scan left out the code that the earlier reviews read and that did not change, the web app, the relay, the site,
wallet2 (the Monero library) beyond what the app asks of it, and arti itself beyond the parts the plugin uses.

## Method

The scan used the skill `sharp-edges` 1.1.3 of the marketplace `trailofbits/skills`, at the commit `82fe822` of
28 Sep 2026, under the license CC-BY-SA-4.0. Claude Code ran it with the model Claude Fable 5.1.

The skill looks for designs that make mistakes easy: dangerous defaults, silent failures, settings that fail with one
wrong value, and values of one kind that pass for another. One agent of the skill read the change and the plugin with
the questions to probe: whether any connection to the node or the relay can go out without Tor while the switch is on,
at the start, at the unlock, on a change of the settings, during a retry, or after Tor died; whether the proxy of the
user gets used or lost; what the app does when the proxy of Tor dies; whether the proxy on this Mac is open to other
processes; whether the old settings files are read right; whether the calls of the switch race; whether the quit
leaves Tor running; whether errors of the plugin are swallowed; and whether the entitlements and the notices are
right. Claude then read each finding against the code, fixed it with a test where a test fits, and ran the checks:
the analyzer, the formatter, the 256 unit and widget tests, the build of the app for release, and the test of Tor
against the real Tor network on this Mac (`integration_test/tor_test.dart`): arti started inside the app, answered
the greeting of the app, resolved the name of the relay with RESOLVE, and carried a call of the relay through Tor
with its signature checked.

## Summary

The scan found 13 findings: 3 High, 5 Medium, and 5 Low. Nothing is Critical.

- The High findings: "Save node" in Settings wrote the address of the proxy of Tor, or nothing, over the proxy of the
  user while the switch was on; an unlock while Tor was still starting asked wallet2 about a node that it had never
  been connected to, which wallet2 answers with an exception through the C interface, so that the app would have
  stopped; and the switch turned on left the connection of wallet2 to the node open and straight while Tor started,
  and for good when Tor failed. All three are fixed, with tests.
- No finding lets the relay be reached without Tor while the switch is on, or lets a key, a balance, or an address
  leave the app. The proxy of Tor listens on this Mac alone, without a user name: other processes of this Mac can
  use it, which the app cannot forbid; the streams of the app now carry a secret of their own, so that they share
  no circuit with them.

| Severity | App |
|---|---|
| Critical | 0 |
| High | 3 |
| Medium | 5 |
| Low | 5 |
| Total | 13 |

Every finding is fixed but the part of W-04 that lies in the plugin and W-11, which stays as a note, as the tables
say.

## Findings

| ID | Severity | Finding | Fix |
|---|---|---|---|
| W-01 | High | The field of the proxy in Settings, out of sight while the switch is on, held the proxy that was in use: the address of Tor built into the app while it was on, or nothing while it started or failed; "Save node" saved it as the proxy of the user. A user with a Tor of their own at 127.0.0.1:9050 who turned the switch on, changed the node, and later turned the switch off would have reached the node and the relay with no proxy at all, or through the dead port of Tor built in. | The controller tells the proxy of the user (`userProxy`) apart from the proxy in use; the field shows the first and "Save node" leaves it alone while the switch is on; a proxy typed while the switch is on is kept for later and connects nothing. Tests. |
| W-02 | High | An unlock while Tor built into the app was starting or failed opened the wallet and read its state, which asks wallet2 whether the node is connected. wallet2 throws `wallet_not_initialized` for a wallet that was never connected, and the C interface of monero_c catches nothing, so the app would have stopped. Before this change every open was followed by a connection; the guard of the engine covered only a proxy that wallet2 refused. On a warm cache Tor is on before the password is typed, which hides it. | The engine of the wallet keeps whether the open wallet has a node (`_hasNode`): false until its first connection succeeded and again after it left the node; while false, the state read asks wallet2 nothing about the node and a payment is refused. The new request `LeaveNode` takes the wallet off its node. |
| W-03 | High | The switch turned on blocked the relay at once, but wallet2 kept its connection to the node, its scan every 20 seconds, and the poll of the app, all straight, until Tor was on; when Tor failed, the straight connection stayed for good while the home said that the wallet waits. | The wallet leaves its node (`LeaveNode`: the scan pauses, wallet2 goes offline) before Tor starts, and whenever Tor goes off or fails while the switch is on; the connection comes back through Tor once it is on. Tests. |
| W-04 | Medium | The plugin picks the port of its proxy by binding 0.0.0.0:0 for a moment, bootstraps for seconds or minutes, and binds the proxy only then, without reading the result: a port taken meanwhile leaves Tor "on" with no proxy, or with the proxy of another process of this Mac. The app trusted the port and never looked at it again; a proxy that died later left the state on, with no way to start again but the switch. | The service marks Tor on only once the proxy answered the greeting of the app, and a look of the app that finds the proxy of Tor built in not answering marks Tor failed, which offers "Try again" and takes the wallet off its node. The window during the bootstrap lies in the plugin: a bind before the bootstrap, on 127.0.0.1:0 with the port read back, would close it, which this report notes for a change of the plugin. The app cannot tell the proxy of arti from another SOCKS5 proxy at the same port; a process of this Mac that takes the port first is a process with the rights of the user. |
| W-05 | Medium | A stop waited for a start in flight, which cannot be cut short: a quit of the app during the bootstrap, or the switch turned off then, waited for the bootstrap to end, which on a network that blocks Tor is a long time. | A stop turns the state off at once, and the engine stops right after its start returns; a start takes at most two minutes before it counts as failed; the quit waits three seconds at most. Tests. |
| W-06 | Medium | Two changes of the switch in a row could end with the switch on, Tor off, and nothing starting it again: the stop waited for the start, the start that came after joined the same future, and the stop ran last. | The calls of the service run one after the other and read the last wish: a stop after a start that the engine has not heard of starts nothing, and a start after a stop leaves the engine running, so that the last change of the switch wins. The switch takes no change while one runs, and the quit of the app, the one stop that comes while the switch is on, starts nothing again. Tests. |
| W-07 | Medium | wallet2 resolves the name of the node with the resolver of this Mac, proxy or not, before it connects through the proxy: the default node is a name, so every connection told the network which node the wallet uses, while the privacy check said that the node sees a Tor exit and not the IP address of the user. Older than this change, with a proxy of the user, and now on the default path. | Through Tor built into the app the name of the node is resolved through Tor as well, with RESOLVE, the command of the extensions of SOCKS of Tor, which arti answers (`CHECKED` 13 Oct 2026 against the real network), and wallet2 gets the address; a name that Tor cannot resolve keeps the wallet away from the node, with its words on the home. An address of an onion service goes as a name. With a proxy of the user the name still goes to wallet2, as before. Tests. |
| W-08 | Medium | Only a node on this Mac went without the proxy; a node on the user's own network, such as 192.168.1.5, went through Tor, which refuses private addresses, and the words of the trouble told the user to turn Tor off. | A node of the own network, as the privacy check reads one (this Mac, a private address, a link-local one, a unique local address of IPv6, a name of mDNS), takes no proxy. A test. |
| W-09 | Low | The proxy of Tor built in takes a connection without a user name, like a Tor of the user's own, so another process of this Mac could share circuits with the app, and the app's own streams shared none deliberately. | The SOCKS client of the app offers a user name and a password as well (RFC 1929), one random secret for the life of the process, which Tor and arti read as a key of isolation; a proxy that picks the connection without a user name gets none, as before. Tests, and the greeting through the real arti. |
| W-10 | Low | The reason of a failed start of Tor was kept and shown nowhere: a wrong clock, a refused folder, a censored network, all read "Tor could not connect". | The settings page shows the reason under the chip, as one line cut short. |
| W-11 | Low | A controller built without the service of Tor, as a tool or a test harness may do, reads a settings file with the switch on and reaches the node straight, since the switch counts as off without the service. | A note: the app wires the service at its start, the switch of Settings takes no change without it, and the tests and the picture tools pass a service of their own; a tool that opens a real wallet must pass one too. The documentation of the field says so. |
| W-12 | Low | The entitlements of the debug profile declared the key of a listening socket twice (the profile had it already for the debugger of Flutter). | The copy is gone. The key is the only one that lets a process of the sandbox listen, and the proxy listens on this Mac alone. |
| W-13 | Low | The notices of the disk image named every crate of the plugin, those of its build and tests too, with the text of two licenses only, through a pipe whose failure the script would not see, and the check of the two architectures left out the framework of Tor. | The script fails on a failure in a pipe, lists the crates that the app ships (the normal dependencies on the two macOS targets, from the lock file) with the text of the license files of each from its sources, and checks the framework of Tor for both architectures. |

## What the scan did not cover

- wallet2 and arti themselves, beyond the calls the app makes.
- The hidden window of W-04 inside the plugin, which a change of the plugin closes.
- A node reached as an onion service, and a relay at an onion address, which the app does not offer yet.

## Checks

The analyzer and the formatter pass; 256 unit and widget tests pass; the app builds for release with Tor in it; and
the test against the real Tor network on this Mac passed: arti started inside the app in 12 seconds, answered the
greeting of the app, resolved the name of the relay with RESOLVE, opened a connection to the relay, and carried a
call of its health through Tor with the signature of the relay checked.
