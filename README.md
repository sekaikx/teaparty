# Tea Party

**Murder at Teatime**: an Among Us-style party game at a tea table, for 4 to 8 friends. One of
you is secretly the **POISONER**. Every round the lights go out and everyone pours something into
someone's cup; you only glimpse one pour. The toast: somebody falls. Then the meeting: *"Where
did YOU pour?" "I saw Clara pour into Ada's cup!" "That's a lie, I poured sugar into Baron's!"*
Vote someone out and find out if you were right. Chunky ragdoll guests, cake throwing, clip
banners. Made in **Godot 4.7** (Forward+).

## Quick start

1. Install **Godot 4.7** (standard, not .NET).
2. In Godot, **Import** and choose `project.godot`, then press **F5**.
3. Click **PLAY NOW!** You're at a table with 5 bots within about 3 seconds.

During a match, the **coach** banner at the top always says what to do next, and a bouncing arrow
points at what to click. **HOW TO PLAY** (title screen or pause menu) has the full rules. After a
match, **PLAY AGAIN!** starts the next one right away.

## How it plays

**Roles.** One guest is the secret **Poisoner** (two with 8 guests; they know each other). Everyone
else is an innocent **Guest**. Guests win when every poisoner has been voted out (or poisoned).
Poisoners win when there are as many poisoners as guests left.

| Step | What happens |
|---|---|
| **1 SERVE (lights out)** | Click **your teapot**, click **any other guest's cup**, then **drag one card** from your secret tray into it. The poisoner holds **Poison**. Guests hold **Plain** and **Sugar**, and one guest gets the **Antidote** (it cancels a poison in the same cup). Nobody can see where anyone pours. |
| **The glimpse** | When the lights come back, most guests learn ONE true thing: *"In the dark you SAW Baron pour into Ada's cup."* (Sometimes the candle flickers and you saw nothing.) It's in your **WHAT YOU KNOW** panel. |
| **2 ITEMS** | Everyone picks at once: **Sniff** a cup (is it poisoned right now? sugar hides it), **Watch** a guest (you learn whose cup they poured into), **Swap** two cups (everyone sees it). Or pass. |
| **3 TOAST** | Everyone raises their cup for 5 seconds. Think yours is poisoned? Press **F** to throw a cake at it and it spills. Hit a face and they drop their cup. Then everyone drinks. The poisoned fall, and **the game doesn't say who poured it**. You only see what was in the deadly cup. |
| **4 MEETING** | Talk (Discord, or hold **V**). Say where you poured and what you saw. Players without voice use the **SAY** bar (quick buttons for the truth, or build a lie). The **TALK ABOUT THIS** box suggests questions. Press **READY TO VOTE**. |
| **5 VOTE** | Click who you think it is, or **SKIP**. Most votes gets **thrown out** (ragdoll-yeeted), and everyone sees if they were the poisoner. A tie, or most skipping, throws nobody out. |

### A round on a Discord call (6 friends: Ada, Baron, Clara, Dev, Eli, Finn; Finn is the poisoner)

1. **Serve.** Finn pours POISON into Ada's cup. Baron pours sugar into Clara's. Clara pours plain into
   Dev's. Dev pours the ANTIDOTE into Eli's. Eli pours plain into Ada's. Ada pours sugar into Finn's.
2. **Glimpses.** Baron saw *Eli pour into Ada's cup*. Dev saw *Finn pour into Ada's cup*. Clara saw
   nothing. Eli saw *Baron pour into Clara's*.
3. **Items.** Clara WATCHES Finn: *Finn poured into Ada's cup*. Now two people know.
4. **Toast.** Ada drinks and falls. The reveal: *Ada's cup had POISON + PLAIN*. Ada's a ghost
   now and has to stay quiet.
5. **Meeting.**
   - **Baron:** "I saw ELI pour into Ada's cup!"
   - **Eli:** "Yeah, I did, but it was PLAIN. There was plain in there, check the reveal. So someone else put the poison in."
   - **Finn (lying):** "I poured sugar into Baron's cup."
   - **Baron:** "No you didn't, nobody poured into mine... or did they?"
   - **Dev:** "I SAW Finn pour into ADA's cup."
   - **Clara:** "I WATCHED Finn. Ada's cup. Finn is lying."
   - **Finn:** "Dev and Clara are working together!"
6. **Vote.** Four votes on Finn: **FINN WAS THE POISONER!** Guests win.

That's the game: everyone has an alibi (where they poured), some people have a witness (the
glimpse), and the poisoner has to invent a story that fits. Swaps, the antidote and cakes make
the story messier. And if the poisoner had poured into Baron's cup, Baron would be dead and Dev's
word would be the only evidence.

**Ghosts** (the dead and the thrown-out) keep playing for chaos: they rattle cups and throw ghost
cakes. Among Us rules: **ghosts don't talk to the living** (mute yourself on Discord).

**Clip moments.** Big banners for the funny beats: *CAUGHT THE POISONER!*, *WRONG GUEST!*,
*DOUBLE KILL*, *ANTIDOTE SAVE*, *CAKE SAVE*, *OWN GOAL* (the poisoner drank their own poison
after a swap), *SELF-SWAP*. The results screen gives out awards (Master Poisoner, Detective,
Sharpshooter, Guardian Angel, Cake Magnet...) that pay extra coins. Rooms: **the Parlour**,
**Garden Party** and **Royal Banquet** (8 seats).

## Playing online with Steam (Spacewar, App ID 480)

The game uses Steam's free test app **Spacewar**, so nothing has to be published. Games run on
Valve's relay network, so nobody needs to forward ports.

One-time setup (everyone who plays):
1. Have the **Steam** app running and log in.
2. Nothing to install: **GodotSteam 4.22.1** is already in `addons/godotsteam`. It's the only Steam
   addon the game needs. The game's traffic runs through GodotSteam's own P2P functions
   (`scripts/net/steam_peer.gd`), so there's exactly one `steam_api64.dll`.
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
| Left click | Teapot, any cup, item cards, targets, vote buttons. As a ghost: rattle a cup |
| Drag a card | Pour an ingredient into the cup you served |
| Tab (hold) | Uncover your secret tray |
| V (hold) | Push to talk |
| Q / middle mouse (hold) | Emote wheel |
| F | Throw a cupcake at the point under the mouse (hit your raised cup at the toast to spill it) |
| Enter | Ready to vote (in the meeting) |
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
godot --headless --script res://tools/test_rules.gd                    # rules + 1500 bot matches (prints win balance)
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
