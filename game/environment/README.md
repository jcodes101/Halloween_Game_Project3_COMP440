# Escape / Environment prototype

The active prototype scene is `escape_environment.tscn`. It implements the GDD's compact-house objective: collect the basement key, unlock the basement door, and reach the exit. The generated blockout deliberately stays independent of the later multi-floor house proposal in `handoff/HOUSE_REQUIREMENTS.md`.

## Controls

- WASD: move
- Shift + movement: run
- Mouse: look
- E: interact, enter a hiding place, or leave one
- Escape: release or recapture the mouse
- R: restart after escape or capture

## Environment-owned seam

`escape_environment.gd` is the sole owner of:

- `door_state`: dictionary keyed by door ID; values currently use `locked` and `open`.
- `player_location`: `living_room`, `hallway`, or `basement`.
- `escape_progress`: `FIND_KEY`, `BASEMENT_READY`, `BASEMENT_ENTERED`, `ESCAPED`, or `CAPTURED`.
- `is_hidden`: whether the player is currently concealed.
- `player_is_still`: becomes true after three uninterrupted seconds in a hiding place.

Read these values from the environment node. `environment_state_changed` publishes changes; `basement_reveal_requested` fires when the keyed door opens; `escape_completed` and `player_captured` report terminal outcomes. Monster logic should subscribe/read these values and must not write them. `mark_player_captured()` is the entry point for a future capture system.

Hiding uses a reusable per-spot configuration with an entry point, waypoint path, crawl height, camera height, and exit orientation. The bed spot lowers the first-person camera and crawls through the frame's open underside; the raised frame legs leave a collision checked crawl space. The couch spot crouches and follows a waypoint around the couch end before settling behind it. The crate spot uses the same crouch transition with its own destination. Exiting reverses the route, checks standing clearance, and smoothly raises the camera. Player input is locked during both transitions, and invalid paths are rejected without changing the hidden state.

Walking and running use a speed responsive, procedural camera bob with a small vertical offset and roll. The effect smoothly fades when movement stops and stays disabled during hiding and transitions. The project is first person and has no visible player body or animation rig, so hiding is conveyed through the camera's crouch, crawl movement, orientation, and the configured positions.

Movement exits cover and resets the stillness timer. The current prototype has no monster implementation, so the concealment seam is exposed and stateful, but no pursuit/search behavior consumes it yet.
