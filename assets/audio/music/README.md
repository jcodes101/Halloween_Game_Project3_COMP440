# Dynamic horror music

The music manager discovers tracks here by filename, case-insensitively, and supports `.mp3`, `.wav`, and `.ogg`:

| Filename stem | Use | Playback |
| --- | --- | --- |
| `exploration` | Unaware Familiar / routine | Loop, AI-state crossfade |
| `investigation` | Suspicion, search, or investigation | Loop, AI-state crossfade |
| `chase` | Active pursuit | Loop, AI-state crossfade |
| `hiding` | Player hidden while the Familiar searches nearby | Loop, conditional crossfade |
| `qte_sting` | Start of a capture QTE | One-shot |
| `escape_ending` | Successful house escape | One-shot, ending priority |
| `capture_ending` | Failed QTE / capture ending | One-shot, ending priority |

The current seven files are provided in this folder. The manager routes them through the `Music` bus, which is controlled by the saved Music and Master volume settings. Missing or unloadable files are reported and skipped. Music pauses with the game tree; restart and return-to-menu replace or free the scene-local manager.

The audio files do not currently have accompanying source or license/attribution documentation in this folder. Confirm that the project has permission to redistribute each track and add the provider, license, and required attribution here before publishing the repository or a build. The existing `assets/audio/Kenney_*.txt` files cover other Kenney sound effects and do not document these seven music tracks.

Music loops are enabled by the manager. Seamless loop quality still depends on the loop points and source edit; listen for seams in Godot before release. QTE and ending tracks are explicitly non-looping.
