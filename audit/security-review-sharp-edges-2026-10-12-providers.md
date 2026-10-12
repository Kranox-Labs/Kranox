# Security scan of the second provider of the Kranox web app and of the relay for it

Scanned with [Trail of Bits Skills](https://github.com/trailofbits/skills) on 12 Oct 2026, on the change after the
commit [`ab6c1e2`](https://github.com/Kranox-Labs/App-Web/tree/ab6c1e2) of the web app and the commit
[`7a30027`](https://github.com/Kranox-Labs/Relay/tree/7a30027) of the relay, with the deploy tools of the relay.
Not an audit by Trail of Bits.

This report covers a quick scan of the change that gave the web app of Kranox its second provider, SimpleSwap,
beside ChangeNOW, took the sample mode out of the app, and let the dev server of the app talk to the live relay.
Claude ran the skill in Claude Code and wrote every finding. No person at Trail of Bits or at another firm read the
code.

After you read this report, you know what the scan covered, what it found, and how each finding was fixed. The
reports of the earlier reviews are [security-review-0.2.0.md](security-review-0.2.0.md),
[security-review-consensys-0.3.1.md](security-review-consensys-0.3.1.md),
[security-review-sharp-edges-2026-10-10.md](security-review-sharp-edges-2026-10-10.md), and
[security-review-sharp-edges-2026-10-12.md](security-review-sharp-edges-2026-10-12.md), the first scan of the web
app, which was named the door then.

## Scope

| Part | What the scan read | Version |
|---|---|---|
| Relay | The change to [Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay): the new `src/exchanger.mts` (the shapes that the exchangers share) and `src/simpleswap.mts` (the client of SimpleSwap v3), the provider in the routes of pay of `src/server.mts`, the limiter with a window in `src/limiter.mts`, the optional key in `src/config.mts` and `src/main.mts`, and the deploy tools `scripts/deploy/relay.mts`, `server/relay.sh`, `server/nginx-relay.conf`, and `deploy/config.mts` of the workspace, which carry the key and add the origin of the dev server to the live relay. | After `7a30027` |
| Web app | The change to [Kranox-Labs/App-Web](https://github.com/Kranox-Labs/App-Web): the end of the sample mode, the provider in `src/gate/` and in the pages of receive, the page of a swap, the records of swaps, the settings of the dev server, and the marks of the chains as SVG. | After `ab6c1e2` |

The web app runs in the browser of a phone or of a desktop. The user connects the wallet that receives, and receive
walks through the chain the coins come from, the amount, the provider with its quote, the privacy review, and the
transaction: the user sends XMR from their own Monero wallet to the deposit address of the provider, and the coins
arrive in the wallet they connected. From this change the user picks one of two providers, ChangeNOW or SimpleSwap,
each with its own quote, and the relay holds the key of each.

The scan left out the code that the earlier reviews read and that did not change, the Mac app, the site, the
exchangers themselves, and the wallets of the user.

## Method

The scan used the skill `sharp-edges` 1.1.3 of the marketplace `trailofbits/skills`, at the commit `82fe822` of
28 Sep 2026, under the license CC-BY-SA-4.0. Claude Code ran it with the model Claude Fable 5.1.

The skill looks for designs that make mistakes easy: dangerous defaults, silent failures, settings that fail with one
wrong value, and values of one kind that pass for another. Two agents of the skill read the two parts, each with the
diff and the full sources around it, and wrote their findings with a scenario and a fix each. Claude then read each
finding against the code, fixed it with a test where a test fits, and ran the checks of each part: the type check,
the linter, the formatter, the tests, and, for the web app, the build and a walk through the steps in headless Chrome
against a relay on the machine with the real keys.

## Summary

The scan found 28 findings: 5 Medium, 15 Low, and 8 Info. Nothing is High or Critical.

- No finding lets a swap go to another address, another amount, or another provider than the one the user saw: the
  relay refuses every mix that the agents found, and the web app checks the provider of every answer against its
  request.
- The Medium findings are about availability and about the way of the user: one client could spend the whole budget
  of SimpleSwap for everyone, a quote of one rate could stand for the other on the provider step, the words "Getting
  the quote" could stick, a quote that ran out on the last step had no way back, and a stored swap of an earlier build
  was dropped instead of carried over.

| Severity | Web app | Relay | Total |
|---|---|---|---|
| Critical | 0 | 0 | 0 |
| High | 0 | 0 | 0 |
| Medium | 4 | 1 | 5 |
| Low | 8 | 7 | 15 |
| Info | 4 | 4 | 8 |
| Total | 16 | 12 | 28 |

Every finding but four is fixed, with tests where a test fits. The four that stay are notes: a state of SimpleSwap
that the relay does not know still stops a read, on purpose; the order of the arguments of the limiter; the default
provider written in an effect; and the origin of the dev server on the live relay, kept on its own port with its
caveat written down. The fixes of the web app are in its commit
[`5bce371`](https://github.com/Kranox-Labs/App-Web/commit/5bce371), together with the change that the scan read, and
the fixes of the relay in its commit [`f665e33`](https://github.com/Kranox-Labs/Relay/commit/f665e33), the same way.

## Findings

| ID | Part | Severity | Finding | Status |
|---|---|---|---|---|
| R-01 | Relay | Medium | One client could spend the whole budget of SimpleSwap and keep it spent | Fixed |
| R-02 | Relay | Low | The bucket of the relay could send twice the budget of SimpleSwap into one window | Fixed |
| R-03 | Relay | Low | The read token of a swap named its id and not its exchanger | Fixed |
| R-04 | Relay | Low | An empty or null provider meant ChangeNOW, and a provider in the query of a creation was ignored | Fixed |
| R-05 | Relay | Low | The check of the pair passed when SimpleSwap left the names out | Fixed |
| R-06 | Relay | Low | The same key for ChangeNOW and SimpleSwap passed every check | Fixed |
| R-07 | Relay | Low | A refusal whose range held the amount became "above" | Fixed |
| R-08 | Relay | Low | A created exchange with an id the relay cannot read back got a token | Fixed |
| R-09 | Relay | Info | A state of SimpleSwap that the relay does not know stops a read | Kept on purpose |
| R-10 | Relay | Info | The clock sits between the two numbers of the limiter | Kept |
| R-11 | Relay | Info | The deploy checked the key of ChangeNOW only | Fixed |
| R-12 | Relay | Info | The origin of the dev server on the live relay | Kept, on its own port |
| D-01 | Web app | Medium | A quote of one rate could stand for the other | Fixed |
| D-02 | Web app | Medium | "Getting the quote…" could stick | Fixed |
| D-03 | Web app | Medium | A quote that ran out on the last step had no way back after a failed refresh | Fixed |
| D-04 | Web app | Medium | A stored swap of an earlier build was dropped instead of carried over | Fixed |
| D-05 | Web app | Low | A return to the provider step showed empty cards | Fixed |
| D-06 | Web app | Low | "Best rate" and the button ignored a quote that ran out | Fixed |
| D-07 | Web app | Low | An amount that one provider takes and the other does not left the user without a word | Fixed |
| D-08 | Web app | Low | The request mixed the quote and the draft | Fixed |
| D-09 | Web app | Low | A failed quote of the chosen provider could not be asked again | Fixed |
| D-10 | Web app | Low | The dev server shared the default port of Vite on the live relay | Fixed |
| D-11 | Web app | Low | A dev build looked like the production build | Fixed |
| D-12 | Web app | Low | A local settings file could shape the build that goes to the server | Fixed |
| D-13 | Web app | Info | Three lists of providers | Fixed |
| D-14 | Web app | Info | A read that fails stayed silent on the page of a swap | Fixed |
| D-15 | Web app | Info | The key in the settings of the dev server lacked its last character | Fixed |
| D-16 | Web app | Info | The rule of the address named ChangeNOW for every swap | Fixed in part |

## Details of each finding

Paths of the web app point at [Kranox-Labs/App-Web](https://github.com/Kranox-Labs/App-Web). Paths of the relay
point at [Kranox-Labs/Relay](https://github.com/Kranox-Labs/Relay). Paths under `scripts/` are the deploy tools of
the workspace, which are not public.

### R-01: one client could spend the whole budget of SimpleSwap and keep it spent

- **Severity:** Medium. **Part:** relay. **Status:** fixed.
- **What happened:** the key of SimpleSwap allows 50 calls a minute for everyone together, and the relay kept them
  under one bucket. nginx let one client make five requests a second, so one client could empty the bucket in ten
  seconds and keep it empty, and every other user saw SimpleSwap as busy. Nothing was at risk but the second
  provider; the app offered ChangeNOW on.
- **Fix:** nginx counts the ranges and the quotes that name SimpleSwap in a zone of their own, by client, at twelve a
  minute with a burst of six (`server/nginx-relay.conf`, `deploy/config.mts`); the relay keeps a quote of SimpleSwap
  for ten seconds for the same coin, rate, and amount, so that the pages of the app, which ask the same quote again as
  they load, spend one call (`src/simpleswap.mts`). Test: `test/simpleswap.test.mts`.

### R-02: the bucket of the relay could send twice the budget of SimpleSwap into one window

- **Severity:** Low. **Part:** relay. **Status:** fixed.
- **What happened:** the bucket started full at 50 and refilled 50 a minute, so one window of SimpleSwap could see a
  burst and a refill together, up to 100 calls, and the second half came back refused.
- **Fix:** the budget of the relay is 25 a minute (`SIMPLESWAP_CALLS_PER_MINUTE` in `src/config.mts`), with the
  arithmetic in its comment.

### R-03: the read token of a swap named its id and not its exchanger

- **Severity:** Low. **Part:** relay. **Status:** fixed.
- **What happened:** the token of a swap was a signature over its id alone, and the read route took the exchanger from
  the query, so the holder of a token for an id at one exchanger passed the check for the same id at the other.
- **Fix:** the token of a swap at SimpleSwap signs the exchanger and the id (`src/tokens.mts`); the tokens of
  ChangeNOW keep their first form, so that the apps that hold one go on reading. A read with a token of the other
  exchanger answers 403. Tests: `test/tokens.test.mts`, `test/server.test.mts`.

### R-04: an empty or null provider meant ChangeNOW, and a provider in the query of a creation was ignored

- **Severity:** Low. **Part:** relay. **Status:** fixed.
- **What happened:** the relay took `null` and `""` as "no provider" and served ChangeNOW, which no client sends on
  purpose; a creation with the provider in its query and not in its body went to ChangeNOW without a word.
- **Fix:** only a request without the field at all means ChangeNOW, as the Mac app sends it; an empty or null
  provider gets 400 with the names; a creation with a provider in its query gets 400 (`src/server.mts`). Test:
  `test/server.test.mts`.

### R-05: the check of the pair passed when SimpleSwap left the names out

- **Severity:** Low. **Part:** relay. **Status:** fixed.
- **What happened:** the check of a created exchange lets a name that the exchanger left out pass, which is right for
  ChangeNOW, whose answer is not checked for them; the client of SimpleSwap read its names as optional too, so an
  answer under other names would have passed for any pair.
- **Fix:** the client of SimpleSwap requires the five names of a created exchange and answers 502 with the id of the
  exchange without them (`src/simpleswap.mts`). Test: `test/simpleswap.test.mts`.

### R-06: the same key for ChangeNOW and SimpleSwap passed every check

- **Severity:** Low. **Part:** relay. **Status:** fixed.
- **What happened:** a settings file that named the key file of ChangeNOW for SimpleSwap too started the relay, which
  then sent the key of ChangeNOW to SimpleSwap in every call.
- **Fix:** the relay refuses to start when the two keys are the same text (`src/config.mts`), and the deploy refuses
  to upload them (`scripts/deploy/relay.mts`).

### R-07: a refusal whose range held the amount became "above"

- **Severity:** Low. **Part:** relay. **Status:** fixed.
- **What happened:** a refusal of SimpleSwap with a range in its text became a range answer, with the side decided by
  the minimum alone, so an amount inside the range, or a floating rate without a top, read as "above".
- **Fix:** the side comes from the facts of the range; a refusal whose range holds the amount stays a refusal with its
  text (`src/simpleswap.mts`). Test: `test/simpleswap.test.mts`.

### R-08: a created exchange with an id the relay cannot read back got a token

- **Severity:** Low. **Part:** relay. **Status:** fixed.
- **What happened:** the relay checked the form of an id on a read and not on a creation, so an id with a character
  outside its pattern would have given the app a swap it could never read again.
- **Fix:** the pattern of an id takes `_` and `-` too, and a created exchange with an id of another form is refused
  with its id before a token is issued (`src/server.mts`). Test: `test/server.test.mts`.

### R-09: a state of SimpleSwap that the relay does not know stops a read

- **Severity:** Info. **Part:** relay. **Status:** kept on purpose.
- **What happened:** the client knows the nine states of the app and answers 502 for any other, so a state that
  SimpleSwap adds would stop the reads of a swap while it stays in it. The app would refuse the word too.
- **Plan:** the relay fails closed here, and the first real exchanges at SimpleSwap will show its states; the list in
  `src/simpleswap.mts` grows with them.

### R-10: the clock sits between the two numbers of the limiter

- **Severity:** Info. **Part:** relay. **Status:** kept.
- **What happened:** `CallLimiter` takes the calls, the clock, and the window in that order, so a window passed in the
  place of the clock stops at once, and a clock passed in the place of the window quietly means a tiny window. One
  call site uses the window, and it is right.

### R-11: the deploy checked the key of ChangeNOW only

- **Severity:** Info. **Part:** relay. **Status:** fixed.
- **What happened:** `/ready` made one call to ChangeNOW, so a wrong key of SimpleSwap passed the deploy and users
  found it.
- **Fix:** `/ready` asks SimpleSwap for one range too when the relay has its key (`src/server.mts`), and the deploy
  warns as it does for ChangeNOW. Test: `test/server.test.mts`.

### R-12: the origin of the dev server on the live relay

- **Severity:** Info. **Part:** relay. **Status:** kept, on its own port.
- **What happened:** the deploy adds the origin of the dev server of the web app to the origins that the live relay
  answers from a browser, so that the app runs on real data on the machine of a developer. The agent found no gain
  for another site in it: the relay holds no cookie, no session, and no right of one origin over another, a page at
  that origin already runs on the machine of the user, and the read tokens live in the storage of the live app, which
  such a page cannot read.
- **Plan:** the origin stays, on a port of its own (D-10), and the comment next to it says that the entry must go the
  moment the relay trusts an origin for anything.

### D-01: a quote of one rate could stand for the other

- **Severity:** Medium. **Part:** web app. **Status:** fixed.
- **What happened:** a tap on a provider card adopted the last quote of that provider from the cache of the step, and
  a change of the rate did not clear the cache, so a tap in the moment after a change wrote a quote of the old rate
  into the draft; the relay then refused the creation with a line about the rate id.
- **Fix:** a quote counts only when it answers the draft as it stands, by provider, coin, rate, and amount
  (`src/gate/quote.ts`); the guard of the steps, the button of the provider step, and the card tap all ask that; a
  change of the rate clears the cache (`src/ui/pages/receive/ProviderStep.tsx`, `steps.ts`). Test:
  `test/quote.test.ts`, and the walk in headless Chrome: a change of the rate with a tap on the other card in the same
  moment left the button off until the new quotes came.

### D-02: "Getting the quote…" could stick

- **Severity:** Medium. **Part:** web app. **Status:** fixed.
- **What happened:** the flag of a batch of quotes was set when the batch started and cleared only when the step still
  wanted it, so a change in between left the words up and the button off for good.
- **Fix:** the step counts the batches in flight, and a batch counts itself out when it ends, wanted or not
  (`ProviderStep.tsx`).

### D-03: a quote that ran out on the last step had no way back after a failed refresh

- **Severity:** Medium. **Part:** web app. **Status:** fixed.
- **What happened:** when a fixed rate ran out on the transaction step, the step asked for a new quote once; when that
  failed, the page showed the failure next to "Getting a new one…", with the button off and nothing to tap.
- **Fix:** the failure shows with a button "Try again", which asks once more (`TransactionStep.tsx`).

### D-04: a stored swap of an earlier build was dropped instead of carried over

- **Severity:** Medium. **Part:** web app. **Status:** fixed.
- **What happened:** a record of a swap needs its provider now, and a record of the build before had none, so the
  list dropped it and the next write forgot it for good. No user held such a record yet, since the app is not
  deployed, but the pattern would turn every future field into a loss of the history of the user.
- **Fix:** a record without a provider names ChangeNOW, the only provider of that time, before the check
  (`src/gate/store.ts`).

### D-05: a return to the provider step showed empty cards

- **Severity:** Low. **Part:** web app. **Status:** fixed.
- **What happened:** the quotes lived in the state of the step, so a return from a later step showed two empty cards
  while the button stayed on for a quote the user could no longer see.
- **Fix:** the quote of the draft seeds the cards when it still answers the draft, and the other providers are asked
  again (`ProviderStep.tsx`).

### D-06: "Best rate" and the button ignored a quote that ran out

- **Severity:** Low. **Part:** web app. **Status:** fixed.
- **What happened:** a fixed quote whose time ran out kept its tag and kept the button on.
- **Fix:** a quote counts for the tag and for the button only while it holds, and the step asks all providers again
  when the chosen quote ran out (`src/gate/quote.ts`, `ProviderStep.tsx`).

### D-07: an amount that one provider takes and the other does not left the user without a word

- **Severity:** Low. **Part:** web app. **Status:** fixed.
- **What happened:** the amount step shows the widest range over the providers, so an amount inside it could be
  outside the range of the chosen provider; the button stayed off and nothing said which card to tap.
- **Fix:** a line under the button names the provider that takes the amount, or says that none does, with a link back
  to the amount (`ProviderStep.tsx`, `src/copy.ts`).

### D-08: the request mixed the quote and the draft

- **Severity:** Low. **Part:** web app. **Status:** fixed.
- **What happened:** the creation took the provider and the rate id from the quote and the coin, the rate, and the
  amount from the draft; they agreed only through the discipline of the provider step.
- **Fix:** the request is the quote the user saw, with the address of the wallet and the refund address, and the
  guard of the steps asks the quote to answer the draft (`TransactionStep.tsx`, `steps.ts`).

### D-09: a failed quote of the chosen provider could not be asked again

- **Severity:** Low. **Part:** web app. **Status:** fixed.
- **What happened:** when the quote of the chosen provider failed, a tap on its card changed nothing, and a 503 of
  the relay, such as a missing key of a provider, showed as a fixed line.
- **Fix:** each tap on a card asks once more when the quotes are missing, and a 503 of the relay shows with its own
  text (`ProviderStep.tsx`, `src/gate/relay-client.ts`).

### D-10: the dev server shared the default port of Vite on the live relay

- **Severity:** Low. **Part:** web app. **Status:** fixed.
- **What happened:** the live relay answered the origin `http://localhost:5173`, the default port of Vite, which any
  other dev server on a machine may hold.
- **Fix:** the dev server of the web app runs on a port of its own, 5181, and stops instead of moving when the port is
  taken (`vite.config.ts`); the live relay answers that origin alone (`scripts/deploy/config.mts`).

### D-11: a dev build looked like the production build

- **Severity:** Low. **Part:** web app. **Status:** fixed.
- **What happened:** with the sample mode gone, the dev server and the live app showed the same sidebar, and a click
  through the dev server opens a real swap.
- **Fix:** the card of the relay carries the tag "Development" on the dev server (`src/ui/shell/Sidebar.tsx`). The
  swaps of a developer are real on purpose: the owner wants no made-up data anywhere.

### D-12: a local settings file could shape the build that goes to the server

- **Severity:** Low. **Part:** web app. **Status:** fixed.
- **What happened:** Vite reads `.env.production.local` and `.env.local` above `.env.production`, and git ignores
  them, so a stray file could ship a build that talks to another relay or trusts another key.
- **Fix:** the deploy of the web app refuses to run while either file exists (`scripts/deploy/app-web.mts`).

### D-13: three lists of providers

- **Severity:** Info. **Part:** web app. **Status:** fixed.
- **Fix:** the client of the relay reads the one list of `src/gate/types.ts`.

### D-14: a read that fails stayed silent on the page of a swap

- **Severity:** Info. **Part:** web app. **Status:** fixed.
- **Fix:** the page says that the last check did not come through while the swap moves (`src/ui/pages/SwapPage.tsx`).
  The relay side is R-03.

### D-15: the key in the settings of the dev server lacked its last character

- **Severity:** Info. **Part:** web app. **Status:** fixed.
- **Fix:** `.env.development` holds the key as `.env.production` does, to the last character.

### D-16: the rule of the address named ChangeNOW for every swap

- **Severity:** Info. **Part:** web app. **Status:** fixed in part.
- **Fix:** the rule says "the records of the provider" (`src/gate/privacy.ts`). The default provider is still
  written in an effect of the provider step; it costs one render and nothing else.

## What the scan ruled out

The agents refuted their own candidates before they reported:

- A request cannot pick an exchanger it should not: the provider is compared with a list of two names, and any other
  value, of any type, gets 400; the receive route of the Mac app never reads a provider.
- A creation replayed under its key with another provider is refused as another request; a creation refused by the
  limiter is forgotten, so the retry runs.
- The refund address of a swap at SimpleSwap must come back exactly; a deposit address must be one of Monero; the
  amount of XMR must be the one of the request; the coin, the rate, and the provider of every answer must be the
  ones of the request, and the signature of the relay covers the query that names them.
- The key of SimpleSwap goes in one header, never in a URL or a log; a redirect and a timeout end without the body
  going anywhere; the text of a refused key never reaches the app.
- The marks of the chains are static SVG without script, style, or outside reference, shown through an image element.
- The sample mode is gone without a trace in the sources; the build for the server takes `.env.production` alone.
