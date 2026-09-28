# Tea Party

**Murder at Teatime**: a social deduction party game at a tea table, for 4 to 8 friends. One of
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
| **2 ITEMS** | Everyone picks at once: **Sniff** a cup (is it poisoned right now? sugar hides it), **Watch** a guest (you learn whose cup they poured into), **Tea Leaves** (how many guests poured into a cup, not what), **Swap** two cups (everyone sees it), or **Fresh Cup** (the butler replaces a cup, poison and all; everyone sees who rang). Or pass. |
| **Twists** | From round 2 most rounds bring one: **Blackout** (no glimpses), **Full Moon** (everyone glimpses), **Party Favours** (an extra item each), **Gossip** (one true pour told to the whole table), **Sugar Rush** (sugar everywhere, sniffs tell nothing). Lobby toggle. |
| **3 TOAST** | Everyone raises their cup for 5 seconds. Think yours is poisoned? Press **F** to throw a cake at it and it spills. Hit a face and they drop their cup. Then everyone drinks. The poisoned fall, and **the game doesn't say who poured it**. You only see what was in the deadly cup. |
| **4 MEETING** | Talk (Discord, or hold **V**). Say where you poured and what you saw. Players without voice use the **SAY** bar (quick buttons for the truth, or build a lie). Whoever was just poisoned gets **one line of last words** before going silent. The **WHO SAID WHAT** board lists every claim and flags stories that **don't add up** (someone says they poured sugar into the victim's cup but the reveal shows no sugar; three people claim the same cup; a sighting contradicts an alibi). Press **READY TO VOTE**. |
| **Special roles** | With 5+ guests one innocent is secretly **the Inspector** (our detective): each round they **inspect** a guest's hands, and poison leaves a trace on whoever poured it *that round* (a poisoner who lies low comes up clean). With 6+ there's also **the Physician** (our doctor): each round they **watch over** a guest, and if that guest drinks poison, smelling salts bring them round (not the same guest two rounds running, themselves only once). Both play in secret on top of their item, and anyone (the poisoner too) can claim to be them. Two claims for one role show up on the board. Lobby toggles switch them off. |
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
cakes. House rule: **ghosts don't talk to the living** (mute yourself on Discord).

**Clip moments.** Big banners for the funny beats: *CAUGHT THE POISONER!*, *WRONG GUEST!*,
*DOUBLE KILL*, *ANTIDOTE SAVE*, *CAKE SAVE*, *OWN GOAL* (the poisoner drank their own poison
after a swap), *SELF-SWAP*. The results screen gives out awards (Master Poisoner, Detective,
Sharpshooter, Guardian Angel, Cake Magnet...) that pay extra coins. Rooms: **the Parlour**,
**Garden Party** and **Royal Banquet** (8 seats), all open to everyone. Tick **Night party** in the
lobby for moonlight, candles on the table and fireflies in the garden.

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
- **HOST FOR FRIENDS**, then press **INVITE FRIENDS** in the lobby: an in-game list of your Steam
  friends (the ones already in Tea Party at the top) with an **INVITE** button each. No Steam overlay
  needed. Or **COPY** the party code and paste it on Discord.
- If your friend has Tea Party open, a **"<you> INVITED YOU! JOIN"** popup appears in their game. The
  invite also shows up in their Steam chat.
- Anyone with the code can paste it into **JOIN** (friend or not). **HOST PUBLIC** also lists the
  party under **FIND PUBLIC PARTIES**.
- Joining shows what it's doing ("Calling the host..."). If the host doesn't answer within about 20
  seconds you get the reason instead of an endless "Joining...". The **LOG** button shows (and copies)
  the connection log. It's also saved as `net_log.txt` in the game's data folder
  (`%APPDATA%\Godot\app_userdata\Tea Party` on Windows).

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

### Display and controls troubleshooting

- The game starts **fullscreen** at your desktop resolution. **F11** or **Alt+Enter** switches to a
  window (80% of the screen, centred) and back. It's also in Settings.
- **Settings > Low graphics** for laptops (no anti-aliasing, 75% 3D resolution with FSR, smaller shadow
  maps). The game offers it by itself if it runs under 30 FPS.
- **Right-drag to look around**: the cursor hides and locks while you look, then comes back where it
  was, so it can't slide off the window or get stuck at the screen edge.
- Touchpad? Click a card, then click the cup (no dragging needed). Dragging still works too.

## Controls

| Input | Action |
|---|---|
| Left click | Teapot, any cup, item cards, targets, vote buttons. As a ghost: rattle a cup |
| Drag a card | Pour an ingredient into the cup you served |
| Tab (hold) | Uncover your secret tray |
| V (hold) | Push to talk |
| Q / middle mouse (hold) | Emote wheel |
| F | Throw a cupcake at the point under the mouse (hit your raised cup at the toast to spill it) |
| R | Ready to vote (in the meeting) |
| Enter / T | Open text chat (online, in the lobby and the match). Enter sends, Esc closes |
| Right-drag / wheel | Look around / lean in |
| Esc | Pause menu (also cancels an item) |

## Friendslop features

- **Jelly bean guests.** Each guest is one smooth, sculpted vinyl-toy bean (a lathed body whose
  domed top is the head, so turning and nodding slide the face over the surface), with big glossy
  eyes and sloshing pupils, blushing cheeks, a smile that opens when they talk, noodle arms with
  round mitts and stubby legs. They squash and stretch when they gesture, get bonked or climb back
  into their chair. Colour comes from the wardrobe, plus a hair nub, a collar (bow tie, ruffle,
  pearls or scarf), and the hat and face accessories. Ghosts are a clean glowing bean.
- **Lights out for real.** While everyone serves, the room actually goes dark: every lamp and the
  fire go down, the table candles puff out in a wisp of smoke, and you pour by your own little
  candle. The other guests become silhouettes with glowing eyes, and every cup rim glints so you can
  still pick one. A slow heartbeat plays until the lamps stutter back on.
- **Who's who.** Every guest at the table has their own colour (duplicates are repainted at the
  start, bots first). The colour is on the guest list, the vote buttons and the WHO SAID WHAT
  board, and in the meeting and the vote each guest's name floats over their head in it.
- **A HUD that gets out of the way.** Settings > HUD size (default 85%). Settings > Meeting
  helpers: the SAY bar and talking points show when bots are at the table and hide for an
  all-human table (you're on Discord); a SAY BAR button still opens it.
- **Voice that just works.** Hold **V**: the mic is kept open for the whole session, so the
  first word isn't cut off, and the TALK chip shows your live level (or warns *MIC SILENT?*).
  **Settings > TEST MIC** has a level bar, a device picker and *hear myself*.
  `tools/mic_test.gd` checks it end to end: a virtual microphone playing a 440 Hz tone, a host
  and a client over the network, and the host decoding exactly that tone.
- **A real loading screen.** The boot splash and the loading screen are key art rendered from the
  game (`tools/key_art.gd`). The room models load on a background thread behind a progress bar
  and a gameplay tip, and the screen stays up until the first frames are smooth.
- **Text chat for players without a mic.** Press **Enter** (or **T**) online to type up to 140
  characters. Lines show in the chat box and as a speech bubble over your bean. Ghosts chat only with
  other ghosts, so the dead can't tip anyone off.
- **Ragdolls you cause.** A cake to the face knocks the guest off the chair: the bean becomes one
  rolling rigid body with floppy procedural arms and legs (no chain of joints to jitter, tangle or
  explode), drops what they're holding, and 2 seconds later snaps back upright saying "I'M FINE".
  A body that starts inside the table is slid clear first, so nobody gets launched across the room.
  Deaths use the same body but stay down with X'd-out eyes, the chair tipping, the hat popping off
  and the cup flying. There are 8 death styles (*Face in the Cake*, *Pirouette*, *Confetti Pop*,
  *Ascension*, *The Yeet*...). `tools/ragdoll_test.gd` checks every style for launches, falling
  through the floor and jitter.
- **Cakes that matter.** 4 per guest for the whole match (a ghost gets 2 more), so every throw is a decision. The host decides what each cake hits, so everyone
  sees the same outcome online.
- **Slow-mo reveal.** The camera turns to whoever is collapsing, time slows down, and the screen shows
  POISONED!. If you're the one dying, a death cam shows your own collapse.
- **Wardrobe with 12 slots.** Your bean's colour, shape (Classic Bean, Dumpling, String Bean, Teapot,
  Sprout), eyes (lashes, sleepy, starry, beady, suspicious), hair and hair dye, a body pattern (polka
  dots, stripes, tummy patch, a big heart, stars), 19 hats (from a propeller cap to a cake dome),
  13 face items, 8 collars (necktie, medal, villain cape...), cups, deaths and titles. TRY is free;
  SURPRISE ME dresses you from what you own. `tools/look_lineup.gd` renders every item.
- **Built for Discord calls.** A speaking order each meeting, a meeting clock that grows with the
  table, ROUND 3/8 and a FINAL ROUND warning, your Steam name as your in-game name, and the rules for
  friends who join straight into a lobby. See [docs/DISCORD_PLAYTEST.md](docs/DISCORD_PLAYTEST.md).
- **Party modes.** *Hit List*: every poisoner gets a secret target, who is warned and gets an
  extra item each round; poisoning the target (from round 3, round 4 with two poisoners) wins it
  outright, a target voted out spoils the hit. *Rival Poisoners* (6+): two poisoners, each with
  their own vial every round, who are enemies too; the last one standing wins alone.
- **The Butler** (7+ guests) is on nobody's side: each round they may TIDY (secretly swap two
  cups) and they win if they're alive at the end, whoever else wins.
- **Daily challenge.** One a day on the main menu, the same for everyone (Swap Meet, Everyone's a
  Suspect, The Nose Knows, Full Moon Fever, Gossip Night, Sugar Coated, The Big Party, Murder in
  the Glasshouse, Fresh Cups Only), worth +150 coins the first time each day.
- **Dramatic role reveal.** Whoever is thrown out gets a spotlight and a drumroll: "ADA WAS...
  THE POISONER!" (or an innocent guest, the Inspector...).
- **Replay card.** After the match, WHO POURED WHAT? lists every pour, item and death, round by round.
- **Trophies.** 17 achievements (local, and Steam achievements when the app defines them).
- **The Glasshouse.** A moonlit greenhouse room with lanterns and fireflies. 12 emotes with voice lines.
- **Helium voices** lobby toggle: squeaky voice chat.
- Slide whistle, bonk, splat and a kazoo fanfare for the winner.

## Progression

Every room, the night mode and all lobby rules are open to everyone from the first match. Matches
pay XP and coins; levels open up more items in the **Wardrobe** (hats, faces, outfit colours,
teacups and death animations), which you can try on the turntable, including a ragdoll preview of
your death. **Titles** come from lifetime stats (*Cold Blooded*, *Nose of the Year*, *Poltergeist*,
*Mastermind*...).

## Project layout

```
autoload/      Keys, Sfx (buses, helium), Profile (save / levels / cosmetics), Steamworks (GodotSteam
               bridge: init, lobbies, invites, browser), Net (solo / LAN / Steam, lobby), Session
               (host-authoritative match, RPCs, bots, cakes), Voice (push-to-talk)
scripts/net/   steam_peer.gd (Godot multiplayer over GodotSteam P2P, host relays)
scripts/core/  defs.gd, rules.gd (TeaRules: the game as data), bot_brain.gd, cosmetics.gd
scripts/world/ guest.gd (bean mesh, poses, googly eyes, knockdown + death ragdolls, ghosts), cake.gd,
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
godot --headless --path . -- --qa --tool=res://tools/steam_peer_test.gd  # SteamPeer vs fake Steam (P2P and Networking Messages)
godot --headless --path . -- --qa --fake-steam=7 --tool=res://tools/join_timeout_test.gd   # a silent host gives a clear error
xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/os_mouse_test.gd  # real OS clicks (xdotool)
godot --headless --path . -- --qa --steam-host --fake-steam=1 --speed=6 &   # a full match over SteamPeer (UDP stand-in for Steam)
godot --headless --path . -- --qa --steam-join=1 --fake-steam=2 --speed=6
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --solo --shots=/tmp/shots          # every phase
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/bean_test.gd    # guests, cakes, ragdolls, ghosts
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/char_closeup.gd # studio renders + knockdown/recover
godot --headless --path . -- --qa --tool=res://tools/ragdoll_test.gd    # knockdowns + every death style: no launches, jitter or falling through
godot --headless --path . -- --qa --solo --role=inspector --speed=8     # play a match as the Inspector (or physician)
xvfb-run -a godot --path . -- --qa --tool=res://tools/mic_test.gd --mic-host   # + --mic-join: voice end to end (see the file)
xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver vulkan --path . -- --qa --tool=res://tools/key_art.gd  # the splash
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/app_icon.gd     # re-render the app icon, .ico and splash
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
- Icons: glyphs from **Phosphor Icons** (MIT, `assets/icons/src/LICENSE-phosphor.txt`) on our own
  candy badges; `python3 tools/make_icons.py` rebuilds them. The app icon is rendered from the game's
  own character (`tools/app_icon.gd`; the 1024 px master for store pages is in `store/`).
- Music: "Sneaky Snitch" and "Carefree" by **Kevin MacLeod** (incompetech.com), CC BY 4.0.
  Recorded sound effects from **Freesound** contributors and **Kenney**, CC0; every file and
  author is listed in `audio/CREDITS.md` (`tools/audio/import_recorded.py` cuts them).
- Made with **Godot Engine** (MIT) and **GodotSteam** (MIT). The in-game **CREDITS** screen lists
  every notice.
- Guests, hats, faces, cups, teapots, cakes, the UI style and the tea sounds are made
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
