# Discord playtest simulation (v1.4.0)

This is a modelled playtest, not a session with real people. It combines:
- the rules simulator (`tools/test_rules.gd`, 300 bot games per table size),
- paced bot matches with human-like think times (`qa_driver --pace`, 4, 6 and 8 guests),
- a walk through every screen as a typical Discord group would meet it.

## The groups

| Size | Who's on the call | How it goes |
|---|---|---|
| **4** | Host (knows the game), 2 friends who played Among Us, 1 newcomer | Fast and brutal: ~2 rounds, ~3 minutes. One wrong vote and the poisoner wins. Everyone gets it by round 2. |
| **5** | + the Inspector appears | The sweet spot for learning: ~3 rounds, ~5 minutes. The Inspector's "poison on their hands" is the first big "gotcha" moment. |
| **6** | + the Physician | ~3.5 rounds, ~6 minutes. Most arguments happen here: two claims about one cup. |
| **7** | + the Butler (neutral) | ~4 rounds, ~7-8 minutes. The Butler confuses newcomers ("who swapped the cups?!"). That's intended, but the intro has to say the Butler exists. |
| **8** | Two poisoners who don't know each other | ~5 rounds, ~10-12 minutes. The meeting is crowded: 8 people talking over each other. |

## Measured pace (per round, human-like think times)

| Phase | 4 guests | 6 guests | 8 guests |
|---|---|---|---|
| Serve (lights out) | 11 s | 20 s | 17 s |
| Items | 7 s | 12 s | 12 s |
| Toast and reveal | 10 s | 10 s | 10 s |
| Meeting | 36 s | 48 s | 47 s (capped by the 60 s clock) |
| Vote and throw-out | 7 s | 11 s | 11 s |
| **Round** | **~75 s** | **~105 s** | **~100 s** |

Guest win rate with bots: 45% / 61% / 70% / 68% / 53% at 4 / 5 / 6 / 7 / 8 guests. Real players
lie better than bots and read tells better too, so expect these to land roughly between 40% and 60%.

## Will they understand it?

What works:
- **The step tracker and the coach line** (1 SERVE > 2 ITEMS > ...) tell everyone what to do right now.
- **The WHO SAID WHAT board** does the bookkeeping that's hard on voice: it flags stories that don't add up.
- **Everyone has their own colour**, shown on the list, the votes and over heads.

What broke, and what we changed:

| # | Problem a Discord group hits | Fix in v1.4.0 |
|---|---|---|
| 1 | Friends who went straight to PLAY ONLINE never saw the rules (the 5 rule cards only showed on PLAY NOW). | The rule cards open in the lobby for anyone who hasn't seen them. |
| 2 | Everyone was called "Guest 819", but on the call they know each other by their Steam / Discord names. "I saw Guest 204 pour..." was confusing. | The default name is your Steam name. |
| 3 | The role card was up for 4.5 s, but the Hit List text takes about 15 s to read. A slow PC's loading screen could hide it completely. | Shorter text, one clear **GOAL:** line, 7.5 s on screen, click to close, and it waits for loading to finish. |
| 4 | With 8 people on voice, a 60 s meeting gives each person under 8 seconds. With 4 people it drags. | Meeting time scales with the living guests: 50 s at 4, 60 s at 5, 90 s at 8. It still ends early once everyone is READY. |
| 5 | Voice chaos: everyone talks at once, and the quiet newcomer never says where they poured. | A **speaking order** each meeting: "Ada goes first, then round the table." |
| 6 | Nobody knew the game has a round limit. The poisoner surviving round 8 felt like a cheat. | **ROUND 3/8** on the tracker, a **FINAL ROUND!** stamp, and a warning in the meeting. |
| 7 | The first serve of a match is the slowest: newcomers are still finding the teapot in the dark. | Round 1's serve gets +10 s. |
| 8 | Cake spam: 3 cakes every round meant people threw them for fun, and the toast turned into noise. | 4 cakes per player for the **whole match** (a ghost gets 2 more). Bots save theirs for when they're scared. |
| 9 | 4-player games favoured the poisoner (42% guest wins). | A few more glimpses at 4 guests (45%). |
| 10 | Faces you bought never showed in matches (the face slot wasn't sent to other players). | Fixed. Every wardrobe slot is sent now. |

Still up to the group (house rules): dead players stay quiet on Discord. The game says so
("YOU'RE DEAD: STAY QUIET"), but it can't mute your Discord.

## Suggested lobby settings

- **First time, 4-6 friends:** Murder at Teatime, twists on, meeting helpers on.
- **Regulars, 6-8:** Hit List or Rival Poisoners, twists on, meeting helpers off (you're all on voice).
- **8 on a call:** raise the talk time in the lobby if people keep getting cut off.
