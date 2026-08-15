# Claude Buddy

A little desktop companion for macOS. He sits on your screen, watches your
cursor, naps when you walk away, perks up when you start a Claude Code session,
and says something when you poke him.

Native Swift + SwiftUI, no dependencies. He is drawn entirely in vectors, so
there are no image assets to lose and the whole character is a few hundred lines
you can edit.

## Requirements

- macOS 13 or later
- Xcode or the Command Line Tools (`xcode-select --install`) for `swift build`

## Build and run

```sh
make run      # build and run straight from SwiftPM (fastest iteration)
make app      # build build/ClaudeBuddy.app
make install  # build and copy to /Applications
```

`make run` is fine for trying him out, but "Launch At Login" only works from a
real app bundle — use `make app` or `make install` for day-to-day use.

For a binary that runs on both Apple silicon and Intel:

```sh
make universal
```

The app is ad-hoc signed, not notarized. That is fine for something you build
yourself; if macOS ever complains, right-click the app and choose Open.

## Using him

He has no Dock icon. Everything lives in the menu bar sparkle, or in the
right-click menu on the character himself.

| Thing | How |
| --- | --- |
| Move him | Drag him anywhere |
| Make him talk | Click him, or **Say Something** |
| Settings | Menu bar sparkle, or right-click him |
| Send him away | **Show Buddy**, or **Quit Claude Buddy** |

Menu options:

- **Watch The Cursor** — his eyes follow the pointer and he leans toward it.
- **Follow The Cursor** — he also walks after it when it gets far away, and
  stops at a polite distance. Off by default.
- **React To Claude Code** — see below.
- **Click Through Him** — he becomes decorative; clicks pass through to whatever
  is behind him. Control him from the menu bar while this is on.
- **Size** — small, medium, large.
- **Layer** — float above your windows, or sit on the desktop behind everything.
- **Reset Position** — bring him back to the bottom-right corner.
- **Edit Quips…** — opens the file described below.
- **Launch At Login** — registers the app as a login item.

His position, size and settings persist across launches.

### Moods

| Mood | Trigger |
| --- | --- |
| Idle | Nothing in particular |
| Curious | The pointer comes within ~170 points |
| Working | A `claude` process is running |
| Thinking | That process is actually burning CPU |
| Sleeping | The pointer has not moved for 3 minutes |

Claude Code detection matches a `claude` process owned by you, including one
running under `node`/`bun`/`deno`. It reads the process list with `sysctl` — no
Accessibility permission, no shelling out, and it deliberately ignores the
Claude desktop app. Turn it off with **React To Claude Code**.

Cursor watching also uses polling rather than a global event monitor,
specifically so the app never has to ask for Accessibility access.

## Customising

**What he says** — **Edit Quips…** creates and opens
`~/Library/Application Support/ClaudeBuddy/quips.json`:

```json
{
  "greeting": ["hi! i live here now"],
  "idle": ["just vibing"],
  "working": ["ooh, we're coding"],
  "done": ["nice work!"],
  "sleepy": ["*yawn*"]
}
```

Save the file and the new lines are picked up on his next remark — no restart.
Delete the file to go back to the defaults.

**How he looks** — `Sources/ClaudeBuddy/Views/Palette.swift` has the colours and
the body, sparkle and mouth shapes. `CharacterView.swift` assembles them; every
offset is in a 132 × 144 box centred on the origin.

**How he behaves** — `Sources/ClaudeBuddy/BuddyController.swift` decides moods,
distances and follow speed. `Mood.swift` holds the per-mood animation constants.

## How it works

| File | Role |
| --- | --- |
| `main.swift` | AppKit entry point, accessory (no Dock icon) |
| `BuddyPanel.swift` | Transparent borderless panel; hit testing masked to his silhouette so the rest of the window does not eat desktop clicks |
| `BuddyController.swift` | Owns the panel and sensors, decides mood, handles dragging and following |
| `StatusItemController.swift` | Menu bar item and the shared menu |
| `Sensors/PointerTracker.swift` | Polls the pointer at 30 Hz |
| `Sensors/ProcessScanner.swift` | `sysctl` process list and per-process CPU time |
| `Sensors/ClaudeActivityMonitor.swift` | Turns that into running/busy, with debouncing |
| `Model/BuddyState.swift` | Observable state the views draw from |
| `Views/` | The character, speech bubble, shapes and layout constants |

The panel is a non-activating `NSPanel`, so clicking him never steals focus from
what you were typing in.

## Notes

- The character is an original drawing made for this app, not Anthropic
  artwork.
- On the desktop layer he sits above the wallpaper but behind every window,
  including under the menu bar and Dock.
- He joins all Spaces, so he is there when you switch desktops.
