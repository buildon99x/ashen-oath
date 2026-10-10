# Native play and interruption verification — 2026-10-10

The 15 numbered screenshots are retained in a separate private QA attachment and are **not included in this public repository**. Screenshot numbers below identify that attachment; they are not repository links.

## Environment and method

Official Godot 4.7.2 stable, Linux compatibility renderer (llvmpipe), 1178×814 window client. All actions below used normal mouse/keyboard input in the actual native game. The profile was created under isolated HOME and XDG data/config/cache directories; existing player saves were not touched. Other shared-desktop work was paused for each engine window. All four game launches ended normally with exit 0. See `native-play.log`.

The host has no ALSA output device. Godot reports that failure and falls back to its dummy audio driver. Audio playback was therefore **not verified**. There were no gameplay script errors in the native log.

## First journey, actual combat choices

1. Began a new Korean-language provisional journey, acquired Glass Tooth, then chose the pilgrim sacrifice (8 HP from each hero) and Pilgrim Coin.
2. Entered the Bellkeeper battle and read the new combat coach. Mara selected a LOW Parry, spending 5 MP. Ivo allocated 2 Boost against the head.
3. Closed and relaunched the app. Continue restored the active Ivo turn, 2 allocated Boost, EP, MP, and Mara's Parry. This first interruption exposed a UI bug: the selected target reverted to the legs despite the restored Boost allocation. The model checkpoint itself survived; the UI target was not saved yet. Screenshots 03–05 document the defect before correction.
4. Reselected the head and used Ivo's boosted normal attack, leaving the head broken at 1 HP. Sable Defended. The incoming LOW attack was parried for zero damage and offered Mara a free normal counter.
5. Countered the head to 0 HP. It remained present for explicit Sever rather than disappearing automatically. On the next normal turn Mara paid 1 EP to Sever it.
6. Ivo and boosted Sable attacked the legs; the broken legs lowered the remaining arm. The arm still attacked Ivo, correctly demonstrating that Break suppresses only the broken source, not the entire enemy. The old explanatory text was misleading and was corrected.
7. Mara severed the legs. Ivo Defended at 70/80 MP and received the actual capped 10 MP. Sable's boosted skill wounded the arm. Later Sable Defended at 50/70 and received 15 MP.
8. After breaking and wounding the final arm, Mara manually severed it. All three parts severed triggered victory with body HP remaining, followed by the finisher, reward selection and map return. Chose healing, rested at camp, acquired Hollow Bell and entered the Veiled Judge.
9. The second battle began with full restored HP/MP, 2 EP per hero, intact fresh shields, no old Boost/Parry/Guard/counter state, and the correct English UI. This confirms a real repeat-battle route, not merely a standalone model setup.

Screenshots 01–12 record this sequence. File `10-native-victory-reward.jpg` shows the finisher transition; the actual reward menu is screenshot 11.

## Corrected interruption and bilingual UI regression

On the patched source, continued the Veiled Judge, selected the HIGH head and allocated 1 Boost. Closed normally, relaunched and continued. The selected HIGH head, Boost 1, EP 2, current Mara turn and 60 MP were all restored without reselection. Screenshots 13 and 14 show the same plan before and after restart.

The menu now reports the actual next-cycle MP upgrade of +5; map/battle copy uses MP rather than legacy FOCUS. The source-specific Break explanation fits above EP controls in both languages. Switched to Korean using the live L shortcut; screenshot 15 records the saved selection and readable Korean MP/EP controls. Closed normally afterward.

## Fixes arising from play and review

- Persist and validate the optional selected UI target with the combat checkpoint, retaining backwards compatibility when absent.
- Correct MP labels and the next-cycle upgrade amount.
- Explain source-specific Break, including breaks created during a late counter.
- Show PARRY rather than legacy WARD; only actual matching-height targets receive Parry feedback in a multi-target attack.
- Forecast Blood Lantern's existing capped party heal once per action.
- Report the actual number of hits when an early lethal hit cancels the rest of allocated Boost.
- Include JSON rules in exported packs and test Defend against the actual exported resources.

## Limits

This is one actual first-to-second-boss play route plus an interrupted-turn regression. It is not broad human balance/playtesting, proof of replayability, original-game parity, or completion of the growth/exploration plan. The headless campaign strategy and losses are recorded separately. Keyboard/mouse interaction, visual selection, reward transitions and save resume were verified; controller, audio hardware and Windows binaries were not.
