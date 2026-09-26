# Tea Party

A poisoned tea party for 3 to 8 guests, made in **Godot 4.7** (Forward+). Pour tea for your
neighbour, drop something into it, bluff about it, then everyone drinks at once and somebody
collapses. Open `project.godot` and press Play. The main scene is `scenes/main.tscn`.

## How it plays

1. **Deal.** Everyone gets a hidden tray of ingredient cards: **poison**, **antidote**, **sugar**
   (it masks the smell) or **nothing**. The tray shows face-down until you hover it or hold Tab,
   so a stream never shows your hand.
2. **Pour.** Pick up your teapot, pour for the guest on your left (the glowing cup), then drag
   one card from your tray into their cup. If the timer runs out, a card is picked for you.
3. **Items.** One turn each, in seat order. Click an item card, then its targets:
   - **Swap**: two cups trade places. Everyone sees the cups move.
   - **Sniff**: only you learn if a cup smells of poison. Sugar hides everything. Antidotes don't smell.
   - **Force a Toast**: that guest has to drink their cup right now.
   - **Peek**: see what is left in a guest's tray (and their items). That tells you what they poured.
4. **Talk it out.** Hold **V** to talk, **Q** for the emote wheel. Bluff, accuse, beg. Ready up
   when you're done.
5. **Drink.** Everyone stands, raises their cup and drinks together. A cup with more poison than
   antidote kills. Chairs go over, the reveal board shows every cup, and the dead come back as
   **ghosts**. Ghosts see inside every cup and can **rattle** a cup a few times a round (a
   warning, or a lie). Ghosts only hear other ghosts.
6. **Escalation.** Each round deals more poison and fewer antidotes. From the *laced pot* round
   (round 5 by default) every cup starts with poison, so only antidotes save you. The last
   guest alive wins. If the last guests fall together, they share the win.

### Modes

| Mode | Unlocks at | Rules |
|---|---|---|
| Classic | level 1 | Every guest for themselves. |
| Teams | level 2 | Earl Grey vs Darjeeling (alternate seats, names in team colours). A team wins when the other team is gone. |
| The Butler | level 4 | One hidden butler always holds poison, and from round 2 can drop one extra poison into any cup each round (everyone hears a drip). The guests win if the butler dies. The butler wins by reaching the final two (the final one at tables of 3 or 4). |

### Rooms

| Room | Unlocks at | Seats |
|---|---|---|
| The Parlour: firelight, wallpaper, a round table | level 1 | 6 |
| Garden Party: lawn, hedges, bunting, birdsong | level 3 | 6 |
| Royal Banquet: candlelit hall, a long table | level 5 | 8 |

## Controls

| Input | Action |
|---|---|
| Left mouse | Pick up the teapot and click a cup to pour. Click item cards and their targets. Ghosts: click a cup to rattle it |
| Drag a tray card | Drop the ingredient into the cup (the butler's vial works on any cup) |
| Right-drag / wheel | Look around / lean in and out |
| V (hold) | Push to talk |
| Q or middle mouse (hold) | Emote wheel. Point at an emote and let go |
| Tab (hold) | Uncover your tray |
| Enter | Ready to drink |
| Esc | Menu (settings, how to play, leave). Right-click or Esc also cancels item targeting |

You play in first person from your chair. Your own head and hat are hidden from your camera.
When you collapse, the camera cuts out to show your own death, then you float up as a ghost.

## Multiplayer

- **Play with bots**: a private table with 3 bots. In the lobby you can add or remove more.
- **Host a table**: opens ENet on UDP port **24565** (you can change it on the title screen).
  The lobby shows your LAN address. Over the internet the host has to forward that UDP port.
- **Join a table**: type the host's address and click Join.

The host is authoritative. It runs the rules (`TeaRules`) and the bots. Each player only
receives what their seat is allowed to know: their own tray, sniff and peek results, and the
cup contents if they're a ghost. If a player drops mid-match, a bot takes their seat.

**Voice chat** uses the same connection. While V is held, the microphone is captured from a
muted `Mic` bus, mixed to mono, resampled to 16 kHz, mu-law encoded (about 16 kB/s) and sent to
the host on its own ENet channel. The host relays it by the rules: in the lobby everyone hears
everyone; in a match the living are heard by all and ghosts only by ghosts (a lobby rule can let
ghosts talk to the living). Each voice plays from that guest's seat in 3D.

## Progression

Each match pays XP and coins: a base amount, more per round survived and per guest you poisoned,
and a big bonus for winning. Levels unlock rooms, modes, **custom lobby rules** (level 6) and
pricier cosmetics. In the **Wardrobe** you can spend coins on:

- **Hats**: top hat, bowler, party cone, bonnet, fez, flower crown, witch's hat, teacup hat, crown
- **Teacups**: 8 china patterns. Your teapot matches your cup.
- **Death animations**: swoon, keel over, the stagger, last words, pirouette, confetti pop, ascension
- **Guests**: Knight and Stranger models in several tints

**Titles** come from lifetime stats, for example *Poisoner* (5 kills), *Nose of the Year*
(10 sniffs), *Poltergeist* (25 rattles), *The Butler Did It* (win as the butler). Your title
shows on your place card. The profile is saved in `user://teaparty_profile.cfg`.

**Custom lobby rules** (host, level 6): tray size, pour, item and talk timers, items per round,
laced-pot round, last round, poison strength, ghost rattles, whether ghosts see inside cups,
whether ghosts can talk to the living, and which items are in the deck.

## Project layout

```
autoload/      Keys (input map), Sfx (buses, sounds, music), Profile (save, levels, cosmetics),
               Net (ENet + lobby), Session (the match: host loop, RPCs, bots), Voice (push-to-talk)
scripts/core/  defs.gd (constants), rules.gd (TeaRules: the whole game as data),
               bot_brain.gd (bots), cosmetics.gd (catalogue)
scripts/world/ room_builder.gd (rooms, table, seats), guest.gd (characters, animation, deaths,
               ghosts), tea_cup.gd, teapot.gd, tableware.gd, hats.gd, mats.gd
scripts/game/  table_view.gd (the 3D table: events -> animation, mouse picking, camera)
scripts/ui/    game_hud.gd, tray_card.gd, emote_wheel.gd, icon.gd, main_menu.gd, lobby_screen.gd,
               wardrobe.gd, settings_panel.gd, results_screen.gd, menu_backdrop.gd,
               ui_kit.gd, hud_style.gd + key_cap.gd (from Woods)
tools/         tests, QA harness and the audio synthesiser
```

## Tests and QA

```
godot --headless --script res://tools/test_rules.gd                     # rule unit tests + 1200 bot matches
godot --headless --path . -- --qa --tool=res://tools/input_test.gd      # real mouse events: teapot, card drag, items, ready
godot --headless --path . -- --qa --solo --speed=10 --room=garden --mode=butler   # a full match with the local seat auto-played
godot --headless --path . -- --qa --tool=res://tools/test_voice_codec.gd  # voice codec round trip
godot --headless --path . -- --qa --host --speed=6 &                    # two-process network test ...
godot --headless --path . -- --qa --join=127.0.0.1 --speed=6            # ... host + client over ENet
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --solo --shots=/tmp/shots   # screenshots of every phase
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/ui_shots.gd   # wardrobe, settings, results
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/anim_test.gd  # drink / death / ghost poses
python3 tools/audio/synth_tea_audio.py                                  # regenerate the tea sounds (numpy, scipy, soundfile)
```

QA runs pass `--qa`, so the real profile is never touched.

## Credits

Most assets come from the **Woods** project (`sekaikx/woods`):

- Characters: **KayKit Adventurers** (Knight, Rogue Hooded) by Kay Lousberg, CC0. They use the
  Woods retarget import settings, so the **Universal Animation Library** clips that Woods
  retargeted (`assets/animations/ual_library.res`) play on them.
- Furniture: **KayKit Furniture Bits** (chair, rug, shelf, books), CC0.
- Village props: **KayKit Medieval Hexagon** (houses, well, barrels, crates), CC0.
- Garden: **Quaternius Stylized Nature MegaKit** (hedges, bushes, flowers, oak, stone path), CC0.
- Fonts: Fraunces and Nunito, SIL Open Font License (see `assets/fonts/OFL_*.txt`).
- UI textures, the `HudStyle` UI kit and the theme: from Woods.
- Sounds: the UI, ambience and music loops were made in-house for Woods. The tea sounds (pour,
  clink, gulp, gasp, thud, rattle, ghost, heartbeat, drumroll, bell, the music-box waltz) are
  synthesised by `tools/audio/synth_tea_audio.py`.
- Teapots, cups, hats, tables, rooms and the ingredient and item icons are procedural (code only).

Woods' Osaka model (CC BY fan art of a copyrighted character) and the Rowan model (no licence
file in the repo) were left out on purpose.

## Known limitations

- Voice chat is basic. There is no echo cancellation, noise gate or Opus compression, and
  there's no NAT traversal or matchmaking: you join by address on a LAN or through a forwarded port.
  Voice has not been tested with a real microphone yet: the tests only cover the mu-law codec
  (`tools/test_voice_codec.gd`), not capture, relay and playback end to end.
- Progression and cosmetics are stored locally and trusted, so there is no anti-cheat.
- Only two character models (with tints and hats) for up to 8 guests.
- The screenshots and animation checks ran on software OpenGL under xvfb. Play-test on real
  hardware and tune the Forward+ lighting there.
