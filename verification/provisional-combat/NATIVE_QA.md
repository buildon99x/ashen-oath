# Native play and interruption verification — 2026-10-10

The 23 numbered screenshots are retained in a separate private QA attachment and are **not included in this public repository**. Screenshot numbers below identify that attachment; they are not repository links.

## Environment and method

Official Godot 4.7.2 stable, Linux compatibility renderer (llvmpipe), 1178×814 window client. All actions below used normal mouse/keyboard input in the actual native game. The profile was created under isolated HOME and XDG data/config/cache directories; existing player saves were not touched. Other shared-desktop work was paused for each engine window. All six game launches ended normally with exit 0. See `native-play.log`.

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

## Choice repair: controlled native branches

On the choice-repair candidate, resumed that same journey at the Veiled Judge and Defended through round 1. At the start of round 2 the party had HP 68/62/66, full MP 60/80/70 and EP 4 each; the boss had 310 body HP with all shields intact. Relics were Glass Tooth, Pilgrim Coin and Hollow Bell. The two advertised attacks targeted Ivo: arm MID for 26 and head HIGH for 20. The isolated QA profile was copied at this idle checkpoint to compare two branches. This is a controlled fork of one actual-play save, not two independent campaign playthroughs.

- **Parry-only branch:** Mara and Sable Defended. Ivo selected the arm's MID height and paid 5 MP to Parry. The arm did 0, but the head did 20; Ivo ended at 42/62 HP and 75/80 MP with a free Counter pending. The boss stayed at 310 HP. Before committing, Ivo's Defend card had accurately shown the alternative incoming loss of 23 (13+10); that alternative's resolution is covered by the model oracle, not a third native branch. Screenshots 16–18 show the sources, forecast and actual damage.
- **Break + Parry branch:** Relaunched the copied round-2 profile. Mara used Boost 1 W on the head: 1 EP and 10 MP, 6 body damage and a head Break. Ivo paid 5 MP for MID Parry. Sable used Boost 2 Q on the exposed head: 2 EP, three hits of 19 body damage, head HP 45→0 and boss HP 304→247. The arm was parried and the head attack cancelled. Ivo stayed at 62/62 HP. This demonstrated a zero-damage counterplay that requires an offensive action and resources, rather than forced unavoidable damage. Screenshot 19 shows both resolved plans.
- **Spent-limb escape and payoff:** With the 0-HP head still selected during Ivo's Counter, attack cards were disabled and the guide said to retarget or pass. Space passed the Counter. On round 3 Mara spent 1 EP to Sever: boss HP 247→229, Karma 5→6, and the head was permanently removed. Screenshots 20–21 show the escape and reward; it did not require an invalid attack or editing a save.
- Opened the updated guide and switched languages using normal H/L input. English and Korean text and the close button fit inside the panel without overlap. Screenshots 22–23 record both. Closed the app normally.

These are explicitly Ashen provisional policies. The original game's spent-limb targeting, simultaneous-height schedule and numerical effects have not been established by this comparison. The separate [scripted strategy review](../../docs/porting/CHOICE_REVIEW.md) records broader repeatability and failures.

## Limits

This is one actual first-to-second-boss play route, an interrupted-turn regression and two controlled second-boss choice branches. It is not broad human balance/playtesting, proof of replayability, original-game parity, or completion of the growth/exploration plan. The headless campaign strategy and losses are recorded separately. Keyboard/mouse interaction, visual selection, reward transitions and save resume were verified; controller, audio hardware and Windows binaries were not.
