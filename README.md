# Tea Party

A poisoned tea party for 3 to 8 friends. You're chunky, floppy little aristocrats with googly
eyes. You pour tea for your neighbour, slip something into it, and lie about it. Then everyone
raises their cup for the toast, and that's when the cakes fly: **hit a raised cup and it spills**
(that could save a life or waste an antidote), **hit a face and they ragdoll off their chair**.
Then everyone drinks. Someone turns green and collapses, and the game says who poisoned them. The dead
come back as ghosts with cakes of their own. Made in **Godot 4.7** (Forward+).

## Quick start

1. Install **Godot 4.7** (standard, not .NET).
2. In Godot, **Import** and choose `project.godot`, then press **F5**.
3. Click **PLAY NOW!** You're at a table with 5 bots within about 3 seconds.

During a match, the **coach** banner at the top always says what to do next, and a bouncing arrow
points at what to click. **HOW TO PLAY** (title screen or pause menu) has the full rules. After a
match, **PLAY AGAIN!** starts the next one right away.

## How it plays

| Step | What you do |
|---|---|
| **1 POUR** | Click **your teapot**, then click the **glowing cup** of the guest on your left. Then **drag one card** from your secret tray (bottom left; hover it or hold Tab to see it) into that cup. |
| **2 ITEMS** | **Everyone picks at the same time.** Click an item card (bottom right), then its target(s). **Swap** two cups, **Sniff** a cup for poison (sugar hides it), **Force a Toast** (that guest drinks right now), **Peek** at a guest's cards. Or **PASS**. Then the items go off one by one: sniffs and peeks first, then swaps, then toasts. |
| **3 TALK** | Hold **V** to talk, **Q** for emotes. The coach reminds you who poured your cup and what you put in. Press **READY TO DRINK**. |
| **4 TOAST** | Everyone stands and raises their cup for 5 seconds. **F** throws a cake at the point under your mouse: hitting a **cup** spills it (nobody drinks it), hitting a **face** knocks that guest down and makes them drop their cup. Then everyone drinks. More poison than antidote means you're dead, and a sign over your body names the poisoner. |

### Playing on a Discord call

Just talk in Discord; you don't need the in-game voice (V). Everyone hears everyone, the dead included,
and that's on purpose. **Ghosts see inside every cup, and every ghost gets a secret GRUDGE**: a
living guest they're paid to get killed. So when your dead friend shouts "Don't drink it!", they might
be saving you or they might be getting their revenge. In the talk phase, the **TALK ABOUT THIS** box
turns what everyone saw into prompts ("Baron SNIFFED Ada's cup. Make him say what he smelled.").

**Clip moments.** The game puts a big banner over the funny beats: *DOUBLE KILL*, *BLOODBATH*,
*OWN GOAL* (you drank your own poison), *SELF-SWAP* (you swapped the deadly cup to yourself),
*CAKE SAVE* / *GHOST SAVE*, *OOPS! SAVED THEIR GRUDGE*, and *REVENGE FROM BEYOND*. The poisoned
drop one at a time, and a sign over each body names the killer.

Cards: **Poison** kills. **Antidote** cancels one poison in the same cup. **Sugar** makes a sniff
useless. **Plain** does nothing. Every round has more poison, and from round 5 the pot itself is laced.
**Ghosts** can see inside every cup. They can rattle cups to warn or trick the living, and they get
2 cakes per round of their own, so during the toast a ghost can save a friend or knock the antidote out of an
enemy's hand. Only other ghosts can hear them. The **last guest alive wins**, and the results screen
gives out awards (Master Poisoner, Vengeful Spirit, Sharpshooter, Guardian Angel, Butterfingers, Cake Magnet...)
that pay extra coins.

Modes: **Classic**, **Teams** (Earl Grey vs Darjeeling), and **The Butler** (a hidden player who
can secretly spike any cup). Rooms: **the Parlour**, **Garden Party** and **Royal Banquet** (8 seats).

## Playing online with Steam (Spacewar, App ID 480)

The game uses Steam's free test app **Spacewar**, so nothing has to be published. Games run on
Valve's relay network, so nobody needs to forward ports.

One-time setup (everyone who plays):
1. Have the **Steam** app running and log in.
2. In the Godot editor, open the **AssetLib** tab, search **GodotSteam**, and install
   **"GodotSteam GDExtension 4.4+"** (it installs into `addons/godotsteam`). Restart the editor.
   That's the only Steam addon the game needs. The game's traffic runs through GodotSteam's own
   P2P functions (`scripts/net/steam_peer.gd`), so there's exactly one `steam_api64.dll`.
3. Run the game. Under **PLAY ONLINE** you should see **STEAM: CONNECTED AS <your name>**.

Then:
- **HOST FOR FRIENDS**, then press **INVITE FRIENDS** in the lobby (the Steam overlay opens), or
  send your friends the **party code** (use the COPY button).
- Friends accept the invite in Steam, or paste the code into **JOIN**.
- **HOST PUBLIC** lists your party under **FIND PUBLIC PARTIES** for anyone running Tea Party.

`steam_appid.txt` (containing `480`) sits in the project root for editor runs. An exported game
writes its own copy next to the .exe on first launch (or copy it there yourself if that folder is
read-only). Steam will show you as "playing Spacewar".

### Making the .exe

1. **Editor > Manage Export Templates > Download and Install** (once).
2. **Project > Export**. The **Windows Desktop** preset is already set up, so click **Export Project**.
   It writes `export/TeaParty.exe` and `export/TeaParty.pck`. Keep them together, they're one game.
3. Check that `steam_api64.dll` and `libgodotsteam.windows.template_release.x86_64.dll` ended up in
   `export/`. If not, copy them from `addons/godotsteam/win64/`.
4. Zip the whole `export` folder for your friends. Everyone needs Steam open and logged in.

**Testing online needs two different Steam accounts** (two PCs, or you and a friend). Steam can't
connect an account to itself, so two copies on one PC with one account won't see each other.
The **PLAY ONLINE** screen always says what's wrong with Steam if it isn't connected.

**"Can't open dynamic library ... Error 127"?** That's two different `steam_api64.dll` files
clashing. Older versions of this project bundled a second Steam addon, `addons/steam-multiplayer-peer`.
Delete that folder (and the hidden `.godot` folder, so Godot forgets it), keep `addons/godotsteam`,
and reopen the project.

Not on Steam? **SAME WI-FI / DIRECT IP** still works (UDP port 24565).

## Controls

| Input | Action |
|---|---|
| Left click | Teapot, cups, item cards, targets. As a ghost: rattle a cup |
| Drag a card | Drop an ingredient (or the butler's vial) into a cup |
| Tab (hold) | Uncover your secret tray |
| V (hold) | Push to talk |
| Q / middle mouse (hold) | Emote wheel |
| F | Throw a cupcake at the point under the mouse (hit raised cups during the toast!) |
| Enter | Ready to drink |
| Right-drag / wheel | Look around / lean in |
| Esc | Pause menu (also cancels an item) |

## Friendslop features

- **Chunky guests.** Procedural, jointed humanoids: a big soft head, neck, barrel chest, belt,
  upper and lower arms, oversized mitts, shorts, legs and boots, all made of pillowy rounded blocks.
  Skin and hair colour come from the player's name. The googly pupils slosh around, the mouth flaps
  when you talk on voice chat, and the eyebrows show mood. Hats and face accessories always fit.
- **Ragdolls you cause.** A cake to the face turns the guest into a ragdoll (11 rigid bodies
  joined with cone-twist limits). They flop off the chair, drop what they're holding, and 2 seconds later
  snap back upright and say "I'M FINE". Deaths use the same ragdoll but stay down for the rest of the
  match, with the chair tipping, the hat popping off and the cup flying. There are 8 death styles
  (*Face in the Cake*, *Pirouette*, *Confetti Pop*, *Ascension*, *The Yeet*...).
- **Cakes that matter.** 3 per round (2 for ghosts). The host decides what each cake hits, so everyone
  sees the same outcome online.
- **Slow-mo reveal.** The camera turns to whoever is collapsing, time slows down, and the screen shows
  POISONED!. If you're the one dying, a death cam shows your own collapse.
- **Helium voices** lobby toggle: squeaky voice chat.
- Slide whistle, bonk, splat and a kazoo fanfare for the winner.

## Progression

Matches pay XP and coins. Levels unlock rooms, modes and **custom lobby rules** (level 6). The
**Wardrobe** sells hats, faces, bean colours, teacups and death animations, and you can try any
of them on the turntable (including a ragdoll preview of your death). **Titles** come from
lifetime stats (*Poisoner*, *Nose of the Year*, *Poltergeist*, *The Butler Did It*...).

## Project layout

```
autoload/      Keys, Sfx (buses, helium), Profile (save / levels / cosmetics), Steamworks (GodotSteam
               bridge: init, lobbies, invites, browser), Net (solo / LAN / Steam, lobby), Session
               (host-authoritative match, RPCs, bots, cakes), Voice (push-to-talk)
scripts/net/   steam_peer.gd (Godot multiplayer over GodotSteam P2P, host relays)
scripts/core/  defs.gd, rules.gd (TeaRules: the game as data), bot_brain.gd, cosmetics.gd
scripts/world/ guest.gd (jointed guests, poses, googly eyes, knockdown + death ragdolls, ghosts), cake.gd,
               tea_cup.gd, teapot.gd, tableware.gd, hats.gd, room_builder.gd (rooms + colliders), mats.gd
scripts/game/  table_view.gd (camera, coach arrow, picking, events -> animation, slow-mo)
scripts/ui/    ui.gd (the style), game_hud.gd, tutorial.gd, main_menu.gd, online_panel.gd,
               lobby_screen.gd, wardrobe.gd, settings_panel.gd, results_screen.gd, tray_card.gd,
               emote_wheel.gd, icon.gd, doodle.gd, timer_pie.gd, coin_icon.gd, menu_backdrop.gd
tools/         tests, QA harness, screenshot tools, audio synthesiser
```

## Tests and QA

```
godot --headless --script res://tools/test_rules.gd                    # rules + 1200 bot matches
godot --headless --path . -- --qa --tool=res://tools/input_test.gd     # real mouse input: teapot, drag card, items, ready
godot --headless --path . -- --qa --solo --speed=8                     # a full match, local seat auto-played
godot --headless --path . -- --qa --host --speed=6 &                   # host + client over ENet
godot --headless --path . -- --qa --join=127.0.0.1 --speed=6
godot --headless --path . -- --qa --tool=res://tools/test_voice_codec.gd
godot --headless --path . -- --qa --tool=res://tools/steam_peer_test.gd  # SteamPeer vs a fake Steam: join, RPCs, relay, leave
godot --headless --path . -- --qa --steam-host --fake-steam=1 --speed=6 &   # a full match over SteamPeer (UDP stand-in for Steam)
godot --headless --path . -- --qa --steam-join=1 --fake-steam=2 --speed=6
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --solo --shots=/tmp/shots          # every phase
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/bean_test.gd    # guests, cakes, ragdolls, ghosts
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/char_closeup.gd # studio renders + knockdown/recover
godot --headless --path . -- --qa --tool=res://tools/quickplay_test.gd  # PLAY NOW lands in a 6-seat match
godot --headless --path . -- --qa --solo --pace --speed=8               # real timers: seconds per phase + cake hit stats
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/ui_shots.gd     # menus
python3 tools/audio/synth_tea_audio.py                                 # regenerate sounds (numpy, scipy, soundfile)
```

## Credits

- Room models from the **Woods** project: KayKit Furniture Bits and Medieval Hexagon (Kay
  Lousberg, CC0), and the Quaternius Stylized Nature MegaKit (CC0). Ambience and music loops come
  from Woods too (made in-house).
- Fonts: **Lilita One** and **Fredoka**, SIL Open Font License (`assets/fonts/OFL_*.txt`).
- Guests, hats, faces, cups, teapots, cakes, icons, the UI style and the tea sounds are made
  procedurally in this repo.

## Known limitations

- The Steam path has been tested against a stand-in for Steam (full matches between two processes), but not
  against the real Steam client, because this build machine doesn't have one. The code
  checks for GodotSteam at runtime and falls back to LAN / solo if it's missing. If something
  on Steam misbehaves, the lobby / invite code is in `autoload/steamworks.gd`.
- Voice is basic mu-law audio with no echo cancellation. On a Discord call you don't need it.
- Cake hits are decided by the host, but ragdoll physics runs locally, so bodies can land in
  slightly different places for each player.
- Progression is saved locally and trusted.
