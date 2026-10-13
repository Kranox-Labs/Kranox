<p align="center">
  <img src="assets/images/3.0x/logo.png" alt="The Kranox helmet" height="96">
</p>

# Kranox

Kranox is a private Monero wallet for macOS, with a door to Robinhood Chain. Your keys stay on your Mac, locked
with your password. There is no account and no sign-up, and the app sends no analytics and no crash reports.

From your XMR, you can pay any address on Robinhood Chain in ETH or USDG. You can also receive ETH or USDG from
Robinhood Chain as XMR. ChangeNOW handles each exchange.

## Download

- **Kranox 0.2.0** is the current release. Get it from
  [the latest release](https://github.com/Kranox-Labs/Kranox/releases/latest) or from
  [kranox.cash/downloads](https://kranox.cash/downloads).
- **Kranox 0.3.2 beta** holds the privacy check, the menu Privacy, and the fixes of the
  [security reviews](#audit). Get it from
  [its release page](https://github.com/Kranox-Labs/Kranox/releases/tag/v0.3.2), and start with small amounts.

Kranox runs on macOS 12 or later, on Apple Silicon and Intel. Apple has not notarized it yet, so macOS blocks it
the first time. To open it, go to System Settings, then Privacy & Security, and click "Open Anyway" next to the
message about Kranox.

### Check the download

Each release holds `hashes.txt`, the SHA-256 of the disk image, signed with the release key of Kranox Labs. To
check a download, run these commands in the folder of the three files of the release:

```sh
gpg --import kranox-release-key.asc
gpg --verify hashes.txt
grep macos.dmg hashes.txt | shasum -a 256 -c -
```

The fingerprint of the key is `A874 6F51 F58D 8E30 C23B 8158 439F 7602 F0C5 53D1`.

## What it does

- Send and receive XMR, with a new subaddress whenever you want one.
- Pay any address on Robinhood Chain from XMR. At a fixed rate, the recipient gets exactly the quoted amount. A
  floating rate has a lower minimum and can move a little.
- Receive ETH or USDG from Robinhood Chain into your wallet as XMR.
- Follow each payment and swap step by step, also after you close the app.
- From 0.2.1, enter your password before each send. An open wallet locks after 10 minutes without use.
- From 0.3.0, a privacy check on every payment, and a menu Privacy that checks your whole wallet. It can also scan
  an address of yours on Robinhood Chain, or the recipient of a payment, to show what its public history gives
  away.
- From 0.3.1, reach your node through a proxy such as Tor, and scan the code of a deposit from Robinhood Chain as
  a payment link that names the chain, the coin, and the amount.
- From 0.3.2, the proxy covers the relay too, a privacy check runs before each receive from Robinhood Chain and as
  each review opens, each open swap has a page of its own, and the file of your swaps on the Mac is encrypted.
- From 0.3.3, Tor is built into the app: Kranox starts Tor itself and reaches your node and the relay through it,
  so that both see a Tor exit and not your IP address, with no Tor of your own to run. The name of your node is
  resolved through Tor as well. It is on from the first start; the switch in Settings turns it off, for a proxy of
  your own or a straight connection. While Tor starts, the wallet waits rather than connect without it; a node on
  your own network is reached straight, since Tor cannot reach it.

## The relay

The app reaches ChangeNOW through the [Kranox relay](https://github.com/Kranox-Labs/Relay), a small server that
holds the partner key of ChangeNOW, so that the key never sits in the app. The relay keeps no log of a request.
It sees the addresses and the amounts of a swap, as ChangeNOW does, and never your keys or your balance. For a
scan of an address on Robinhood Chain, it sees that address and asks the explorer for you, so the explorer never
sees your IP address. From 0.3.1 the app trusts an answer of the relay only with the signature of its key, and from
0.3.2 that signature also covers the request that it answers. From 0.3.2 the proxy in Settings, such as Tor, covers
the relay as well as the node, so the relay sees the address of the proxy, not yours. From 0.3.3 Tor built into the
app does the same without a proxy of your own.

## Audit

Kranox has two security reviews, each made with the skills of a different firm, and a scan of the code after the
second one. None of them is an audit by a firm.

### First review: Kranox 0.2.0

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 7 Oct 2026, at the commit `10bc27f`
of Kranox 0.2.0. Not an audit by Trail of Bits.

Claude ran the skills in Claude Code on the wallet and on the relay, and wrote every finding. No person at Trail
of Bits or at another firm read the code. The review found 24 issues, and none of them lets a remote attacker take
funds or keys from a wallet.

| Severity | Found | Fixed | Partly fixed | Open |
|---|---|---|---|---|
| High | 3 | 3 | 0 | 0 |
| Medium | 10 | 9 | 1 | 0 |
| Low | 11 | 10 | 1 | 0 |
| Total | 24 | 22 | 2 | 0 |

The three High findings are fixed:

- A payment that left the wallet could show as a failure after a lock or a quit during the send, so a user could
  pay twice.
- A plain send and a payment to Robinhood Chain shared one built payment, so a confirm could send the other one.
- Anyone could get around the rate limit of the relay and use up the budget of the partner key, which stops the
  bridge for every user.

The fixes of the wallet ship in Kranox 0.2.1 beta and 0.3.1 beta, and the relay runs all of its fixes from 8 Oct
2026. Two findings stay partly fixed: the app reaches its node through Tor if you set it, but without SSL,
because the Monero library accepts any certificate; and the relay still lets the apps before 0.3.1 read a swap
without its token, until those apps are gone.

The full report gives every finding with its impact and its fix:
[audit/security-review-0.2.0.md](audit/security-review-0.2.0.md).

### Second review: Kranox 0.3.1

Scanned with [repo-security-review](https://github.com/Consensys/repo-security-review), a skill of Consensys, on
8 Oct 2026, at the commit `56d16b3` of Kranox 0.3.1 beta and the commit `ef0cdc5` of the relay. Not an audit by
Consensys.

Claude ran the skill in Claude Code on the wallet and on the relay, and wrote every finding. No person at Consensys
or at another firm read the code. The skill calls itself experimental, and its repository has no license.

The review found no secret, no package with a known CVE, and nothing Critical or High. Of its 17 findings, 9 are
new. None of them lets an attacker on the internet take funds or keys from a wallet.

| Severity | Found | New | Known |
|---|---|---|---|
| Medium | 9 | 4 | 5 |
| Low | 7 | 5 | 2 |
| No severity | 1 | 0 | 1 |
| Total | 17 | 9 | 8 |

The new Medium findings are fixed:

- The app reached the relay without the proxy of Settings, so Tor hid your IP address from the node only.
- The signature of an answer of the relay did not bind the request that it answered. The review found this gap in
  the wallet and in the relay.
- The file of your swaps on the Mac was not encrypted.

The fixes of the wallet ship in Kranox 0.3.2 beta, and the relay runs its fixes from 9 Oct 2026. Of the 9 new
findings, 8 are fixed and one is partly fixed: a new password needs 12 characters, and more rounds of the key
function wait for more research.

The full report gives every finding with its impact and its fix:
[audit/security-review-consensys-0.3.1.md](audit/security-review-consensys-0.3.1.md).

### Third scan: the code after 0.3.1

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 10 Oct 2026, at the commit `630c1ea`
of the wallet and the commit `c30fc70` of the relay. Not an audit by Trail of Bits.

Claude ran the skill `sharp-edges` in Claude Code on the code that the wallet and the relay gained after the second
review, and wrote every finding. No person at Trail of Bits or at another firm read the code. The skill looks for
designs that make mistakes easy, such as dangerous defaults and silent failures.

The scan found 13 findings: 1 High, 3 Medium, and 9 Low, and nothing Critical. None of them lets an attacker on the
internet take funds or keys from a wallet. Every one is fixed. The fixes of the wallet ship in Kranox 0.3.2 beta,
and the relay runs its fixes from 11 Oct 2026.

- High: a proxy given by its name, such as `localhost:9050`, never reached the node, while the app said it did. The
  proxy is now an IP address and a port, such as `127.0.0.1:9050`, and a proxy that the Monero library refuses
  keeps the wallet away from its node.
- Medium: a privacy check could say "All clear" while the scan behind it failed, and the relay could call a first
  funding sure when the explorer had missed part of it.

The full report gives every finding with its impact and its fix:
[audit/security-review-sharp-edges-2026-10-10.md](audit/security-review-sharp-edges-2026-10-10.md).

### Fourth scan: the web app before its first release

Scanned twice with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 12 Oct 2026: the web app of
Kranox at its commit `bdeb2e8` with the change of the relay that answers it, and later that day the change that
gave the web app its second provider, SimpleSwap, with the relay and the deploy tools for it. Not audits by Trail of
Bits.

Claude ran the skill `sharp-edges` in Claude Code and wrote every finding. No person at Trail of Bits or at another
firm read the code. The first scan found 22 findings, 2 Medium, 13 Low, and 7 Info, and the second 28, 5 Medium,
15 Low, and 8 Info; nothing Critical or High in either, and nothing that lets a swap go to another address, another
amount, or another provider than the one the user saw. Every finding is fixed but a few notes, which each report
names.

The full reports give every finding with its impact and its fix:
[audit/security-review-sharp-edges-2026-10-12.md](audit/security-review-sharp-edges-2026-10-12.md) and
[audit/security-review-sharp-edges-2026-10-12-providers.md](audit/security-review-sharp-edges-2026-10-12-providers.md).

### Fifth scan: the node that does not answer, and the close of a running card

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 13 Oct 2026: the change after the
commit `c241565` that lets the app say why its node or the relay does not answer, such as a proxy that is not
running, and lets the user close the card of a swap that still runs. Not an audit by Trail of Bits.

Claude ran the skill `sharp-edges` in Claude Code and wrote every finding. No person at Trail of Bits or at another
firm read the code. The scan found 22 findings, 1 High, 6 Medium, 9 Low, and 6 Info, and nothing Critical. The High
one was in the close of a card that still runs: the app stopped following such a swap the moment it failed, so a
refund that came later never showed; the card of a closed swap comes back now whenever the swap needs the user.
Nothing touches the keys, the seed, or a payment. Every finding is fixed, with the notes that the report names.

The full report gives every finding with its impact and its fix:
[audit/security-review-sharp-edges-2026-10-13-node-trouble.md](audit/security-review-sharp-edges-2026-10-13-node-trouble.md).

### Sixth scan: Starknet as the second way into the web app

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 13 Oct 2026: the change after the
commit `684f45e` of the web app and the commit `f665e33` of the relay that opened Starknet as the second chain the
coins can come from, through the 1Click API of NEAR Intents and through ChangeNOW. Not an audit by Trail of Bits.

Claude ran the skill `sharp-edges` in Claude Code and wrote every finding. No person at Trail of Bits or at another
firm read the code. The scan found 26 findings, 5 Medium, 8 Low, and 13 Info, and nothing High or Critical. The
Medium ones: an address of an EVM chain, such as the wallet on Robinhood Chain, passed as a Starknet refund address;
a deposit that arrived in part showed as waiting and later as expired while NEAR Intents held the coins; one budget
of calls to 1Click could be spent by reads alone; and a swap with an id of a form the app did not open. Nothing lets a
swap go to another address or amount than the one the user saw. Every finding is fixed, with the notes that the
report names.

The full report gives every finding with its impact and its fix:
[audit/security-review-sharp-edges-2026-10-13-starknet.md](audit/security-review-sharp-edges-2026-10-13-starknet.md).

### Seventh scan: Zcash as the third way into the web app

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 13 Oct 2026: the change after the
commit `f0bed8d` of the web app and the commit `781ce77` of the relay that opened Zcash as the third chain the coins
can come from, through NEAR Intents, ChangeNOW, and SimpleSwap, at transparent addresses. Not an audit by Trail of
Bits.

Claude ran the skill `sharp-edges` in Claude Code and wrote every finding. No person at Trail of Bits or at another
firm read the code. The scan found 15 findings, 2 Medium, 4 Low, and 9 Info, and nothing High or Critical. The
Medium ones: the app said nothing about the transparent side of Zcash, so that "All clear" could stand over a swap
whose deposit pairs the user's own transparent address with the arrival; and the relay read the field of SimpleSwap
that holds the deposit expected as the coin that arrives, which the first real exchange showed. Nothing lets a swap
go to another address or amount than the one the user saw. Every finding is fixed but one note, as the report says.

The full report gives every finding with its impact and its fix:
[audit/security-review-sharp-edges-2026-10-13-zcash.md](audit/security-review-sharp-edges-2026-10-13-zcash.md).

### Eighth scan: the way out of the web app

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 13 Oct 2026: the change after the
commit `02d78bd` of the web app and the commit `64c6d5b` of the relay that opened the way out, USDG or ETH on
Robinhood Chain into Monero, Zcash, or Starknet through the three providers, with the connected wallet sending the
deposit in one transfer. Not an audit by Trail of Bits.

Claude ran the skill `sharp-edges` in Claude Code and wrote every finding. No person at Trail of Bits or at another
firm read the code. The scan found 10 findings, 1 High, 1 Medium, and 8 Low, and nothing Critical. The High one: the
transfer the button asked of the wallet named no chain, and the page checked the address of the wallet but not its
network, so a wallet switched to another network could have sent the coins of that network to an address only
Robinhood Chain knows; the transfer now names Robinhood Chain and the page shows the switch instead of the button. The
Medium one: a wallet that answers no hash after sending was taken as not having sent, with the button offered again.
Nothing lets the amount the wallet transfers differ from the amount of the swap, or the deposit address come from
anywhere but a checked answer of the relay. Every finding is fixed, as the report says.

The full report gives every finding with its impact and its fix:
[audit/security-review-sharp-edges-2026-10-13-out.md](audit/security-review-sharp-edges-2026-10-13-out.md).

### Ninth scan: Tor built into the app

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 13 Oct 2026: the change after the
commit `3b5571e` of the app that built Tor into it, arti through the plugin `tor` of Foundation Devices, with the
wallet and the relay reached through it. Not an audit by Trail of Bits.

Claude ran the skill `sharp-edges` in Claude Code and wrote every finding. No person at Trail of Bits or at another
firm read the code. The scan found 13 findings, 3 High, 5 Medium, and 5 Low, and nothing Critical. The High ones:
the proxy of the user could be overwritten by "Save node" while Tor built in was on; an unlock while Tor was still
starting would have stopped the app, since wallet2 answers a question about a node it was never connected to with
an exception; and the connection of wallet2 to the node stayed straight while Tor started. All three are fixed,
with tests, and so are the rest but a window inside the plugin and a note. Nothing lets the relay be reached
without Tor while the switch is on.

The full report gives every finding with its impact and its fix:
[audit/security-review-sharp-edges-2026-10-13-tor.md](audit/security-review-sharp-edges-2026-10-13-tor.md).

## Build from source

You need macOS with Xcode, [fvm](https://fvm.app), and [rustup](https://rustup.rs): the Tor built into the app is
arti, a Rust library, which the build compiles on your Mac through the plugin `tor` and its pinned Rust toolchain.
The file `.fvmrc` pins Flutter 3.47.6. In the root of this repository, run:

```sh
fvm install
sh tool/fetch_monero_c.sh
fvm flutter run -d macos
```

The script `tool/fetch_monero_c.sh` downloads the Monero library of
[monero_c](https://github.com/MrCyjaneK/monero_c) `v0.18.4.6-RC2` and checks its SHA-256. It then writes one
universal file to `macos/Libraries/`. Run it once before the first build.

To run the checks and the unit tests:

```sh
fvm flutter analyze
fvm flutter test
```

## Licenses

Kranox is free software under the GNU General Public License, version 3. `LICENSE` in this repository holds the
text. You can run it, study it, change it, and share it under that license; a copy that you share must come with its
source under the same license.

The Monero library inside the app is `monero_c` under the LGPL-3.0. It ships as a separate file, so you can
replace it with your own build. The Tor client inside the app is [arti](https://gitlab.torproject.org/tpo/core/arti)
of the Tor Project, under the MIT and Apache-2.0 licenses, through the plugin
[tor](https://github.com/Foundation-Devices/tor) of Foundation Devices under the MIT license.
`THIRD-PARTY-NOTICES.txt` in the disk image lists every license.

## Links

- Site: [kranox.cash](https://kranox.cash)
- Docs: [kranox.cash/docs](https://kranox.cash/docs)
- X: [@kranoxlabs](https://x.com/kranoxlabs)
