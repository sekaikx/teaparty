# Tea Party

A poisoned tea party for 3 to 8 friends. You're wobbly jelly beans with googly eyes: you pour
tea for your neighbour, slip something into it, lie about it, throw cake at each other, and then
everyone drinks at once. Someone turns green, shakes, and ragdolls out of their chair. The dead
come back as ghosts. Made in **Godot 4.7** (Forward+).

## Quick start

1. Install **Godot 4.7** (standard, not .NET).
2. In Godot, **Import** and choose `project.godot`, then press **F5**.
3. Click **PLAY WITH BOTS**, then **START THE PARTY!**

The first time you play, a 5-card tutorial explains everything. You can open it again with
**HOW TO PLAY** on the title screen or in the pause menu. During a match, the yellow **coach** banner at the top
always says what to do next, and a bouncing arrow points at what to click.

## How it plays

| Step | What you do |
|---|---|
| **1 POUR** | Click **your teapot**, then click the **glowing cup** of the guest on your left. Then **drag one card** from your secret tray (bottom left; hover it or hold Tab to see it) into that cup. |
| **2 ITEMS** | On your turn, click an item card (bottom right), then click its target(s). **Swap** two cups, **Sniff** a cup for poison (sugar hides it), **Force a Toast** (that guest drinks right now), **Peek** at a guest's cards. Or **PASS**. |
| **3 TALK** | Hold **V** to talk, **Q** for emotes, **F** to throw a cupcake at someone's face. Then press **READY TO DRINK**. |
| **4 DRINK** | Everyone stands and drinks. More poison than antidote in your cup means you're dead. |

Cards: **Poison** kills. **Antidote** cancels one poison in the same cup. **Sugar** makes a sniff
useless. **Plain** does nothing. Every round has more poison, and from round 5 the pot itself is laced.
**Ghosts** can see inside every cup and can rattle cups to warn or trick the living. Only other
ghosts can hear them. The **last guest alive wins**.

Modes: **Classic**, **Teams** (Earl Grey vs Darjeeling), and **The Butler** (a hidden player who
can secretly spike any cup). Rooms: **the Parlour**, **Garden Party** and **Royal Banquet** (8 seats).

## Playing online with Steam (Spacewar, App ID 480)

The game uses Steam's free test app **Spacewar**, so nothing has to be published. Games run on
Valve's relay network, so nobody needs to forward ports.

One-time setup (everyone who plays):
1. Have the **Steam** app running and log in.
2. In the Godot editor, open the **AssetLib** tab, search **GodotSteam**, and install
   **"GodotSteam GDExtension 4.4+"** (it installs into `addons/godotsteam`). Restart the editor.
   The other half, `addons/steam-multiplayer-peer`, is already in the project.
3. Run the game. Under **PLAY ONLINE** you should see **STEAM: CONNECTED AS <your name>**.

Then:
- **HOST FOR FRIENDS**, then press **INVITE FRIENDS** in the lobby (the Steam overlay opens), or
  send your friends the **party code** (use the COPY button).
- Friends accept the invite in Steam, or paste the code into **JOIN**.
- **HOST PUBLIC** lists your party under **FIND PUBLIC PARTIES** for anyone running Tea Party.

`steam_appid.txt` (containing `480`) sits in the project root for editor runs. If you export the
game, put a copy next to the executable. Steam will show you as "playing Spacewar".

Not on Steam? **SAME WI-FI / DIRECT IP** still works (UDP port 24565).

## Controls

| Input | Action |
|---|---|
| Left click | Teapot, cups, item cards, targets. As a ghost: rattle a cup |
| Drag a card | Drop an ingredient (or the butler's vial) into a cup |
| Tab (hold) | Uncover your secret tray |
| V (hold) | Push to talk |
| Q / middle mouse (hold) | Emote wheel |
| F | Throw a cupcake at the point under the mouse |
| Enter | Ready to drink |
| Right-drag / wheel | Look around / lean in |
| Esc | Pause menu (also cancels an item) |

## Friendslop features

- **Bean guests.** Everything is procedural: googly eyes whose pupils slosh around under
  physics, a mouth that flaps when you talk on voice chat, eyebrows that show mood, white gloves,
  hats and face accessories that always fit.
- **Real ragdolls.** On a death, every body part becomes a rigid body pinned to its
  neighbours. Chairs get knocked over, hats pop off, cups fly off the table, and bodies stay on the
  floor for the rest of the match. There are 8 death styles, including *Face in the Cake*,
  *Pirouette*, *Confetti Pop*, *Ascension* and *The Yeet*.
- **Cupcakes.** Throw them at anyone (6 per round). A hit makes their head snap back, spins
  their eyes and leaves frosting on their face. Bots throw them too.
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
scripts/core/  defs.gd, rules.gd (TeaRules: the game as data), bot_brain.gd, cosmetics.gd
scripts/world/ guest.gd (bean characters, poses, googly eyes, ragdolls, ghosts), cake.gd,
               tea_cup.gd, teapot.gd, tableware.gd, hats.gd, room_builder.gd (rooms + colliders), mats.gd
scripts/game/  table_view.gd (camera, coach arrow, picking, events -> animation, slow-mo)
scripts/ui/    ui.gd (the style), game_hud.gd, tutorial.gd, main_menu.gd, online_panel.gd,
               lobby_screen.gd, wardrobe.gd, settings_panel.gd, results_screen.gd, tray_card.gd,
               emote_wheel.gd, icon.gd, doodle.gd, timer_pie.gd, coin_icon.gd, menu_backdrop.gd
addons/steam-multiplayer-peer/   SteamMultiplayerPeer GDExtension (MIT, expressobits)
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
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --solo --shots=/tmp/shots          # every phase
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/bean_test.gd    # beans, cakes, ragdolls, ghosts
xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/ui_shots.gd     # menus
python3 tools/audio/synth_tea_audio.py                                 # regenerate sounds (numpy, scipy, soundfile)
```

## Credits

- Room models from the **Woods** project: KayKit Furniture Bits and Medieval Hexagon (Kay
  Lousberg, CC0), and the Quaternius Stylized Nature MegaKit (CC0). Ambience and music loops come
  from Woods too (made in-house).
- Fonts: **Lilita One** and **Fredoka**, SIL Open Font License (`assets/fonts/OFL_*.txt`).
- `addons/steam-multiplayer-peer`: Expresso Steam Multiplayer Peer, MIT, with Valve's
  redistributable `steam_api` libraries.
- Guests, hats, faces, cups, teapots, cakes, icons, the UI style and the tea sounds are made
  procedurally in this repo.

## Known limitations

- The Steam path has not been tested end to end here, because this build machine has no Steam client. The code
  checks for GodotSteam at runtime and falls back to LAN / solo if it's missing. If something
  on Steam misbehaves, the lobby / invite code is in `autoload/steamworks.gd`.
- The Steam peer only carries channel 0, so voice uses channel 0 too. Voice is basic
  mu-law audio with no echo cancellation.
- Physics (ragdolls, flying cups, cakes) runs locally on every client. Everyone sees the same
  deaths and throws, but the bodies can land in slightly different places for each player.
- Progression is saved locally and trusted.
