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
- **Kranox 0.3.1 beta** holds the privacy check, the menu Privacy, and the fixes of the
  [security review](#audit). Get it from
  [its release page](https://github.com/Kranox-Labs/Kranox/releases/tag/v0.3.1), and start with small amounts.

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

## The relay

The app reaches ChangeNOW through the [Kranox relay](https://github.com/Kranox-Labs/Relay), a small server that
holds the partner key of ChangeNOW, so that the key never sits in the app. The relay keeps no log of a request.
It sees the addresses and the amounts of a swap, as ChangeNOW does, and never your keys or your balance. For a
scan of an address on Robinhood Chain, it sees that address and asks the explorer for you, so the explorer never
sees your IP address. From 0.3.1 the app trusts an answer of the relay only with the signature of its key.

## Audit

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

## Build from source

You need macOS with Xcode and [fvm](https://fvm.app). The file `.fvmrc` pins Flutter 3.47.6. In the root of this
repository, run:

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

The Monero library inside the app is `monero_c` under the LGPL-3.0. It ships as a separate file, so you can
replace it with your own build. `THIRD-PARTY-NOTICES.txt` in the disk image lists every license.

## Links

- Site: [kranox.cash](https://kranox.cash)
- Docs: [kranox.cash/docs](https://kranox.cash/docs)
- X: [@kranoxlabs](https://x.com/kranoxlabs)
