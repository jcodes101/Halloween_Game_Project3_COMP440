# Proposed free sound effects

Status: sources approved and implemented in the isolated monster test lab.

| Event | Proposed source and treatment |
| --- | --- |
| Player footsteps | Kenney RPG Audio: varied indoor footfalls, timed to actual movement |
| Mother footsteps | Same pack; spatial playback from her actual position, pace follows movement |
| Wooden doors opening/closing | BigSoundBank apartment door recordings with creak/latch |
| Picking up items | Kenney Impact Sounds: short subdued object contact/handling sound |
| Trying a locked door | Cough-E Door Lock Sounds: handle jiggle / locked latch |

Sources identify their licenses as CC0:

- https://kenney.nl/assets/rpg-audio
- https://kenney.nl/assets/impact-sounds
- https://bigsoundbank.com/apartment-door-opening-1-s1702.html
- https://bigsoundbank.com/porte-d-appartement-fermeture-1-s1704.html
- https://opengameart.org/content/door-lock-sounds

Selected clips and processing are documented in `assets/audio/SOURCES.md`.
Godot checks validate decoded streams and playback events; listening on the
user's speakers/headphones is still needed to tune loudness and realism.

Integrate first into the isolated monster lab and expose reusable event hooks
for the house owner. Play footsteps only for real movement; stop during hiding,
capture, and escape. Keep captions for important monster cues. Play door audio
only on transitions; play locked-attempt audio only on interaction, not every frame.
An isolated pickup sample may demonstrate the sound without implementing the
team's real inventory, crowbar, key, or escape progression.
