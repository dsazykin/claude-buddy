# Claude Buddy

A little desktop companion for macOS. He loiters around the edges of your
screen — along the menu bar, above the Dock, leaning on a window border — walks
off to a new spot every so often, watches your cursor, naps when you walk away,
perks up when you start a Claude Code session, and says something when you poke
him.

He is a chunky coral pixel character in the style of the Claude Code mascot.

Native Swift + SwiftUI, no dependencies. There are no image assets: his sprite
frames are written as text in `Sources/ClaudeBuddy/Views/Sprite.swift`, so you
can redraw him in a text editor.

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
- **Hang Around The Edges** — every 25–70 seconds he ambles off to a new perch
  along the menu bar, above the Dock, or against a side border. On by default;
  turning on **Follow The Cursor** takes precedence over it.
- **React To Claude Code** — see below.
- **Click Through Him** — he becomes decorative; clicks pass through to whatever
  is behind him. Control him from the menu bar while this is on.
- **Size** — small, medium, large.
- **Layer** — float above your windows, or sit on the desktop behind everything.
- **Reset Position** — bring him back to the bottom-right corner.
- **Edit Quips…** — opens the file described below.
- **Launch At Login** — registers the app as a login item.

His position, size and settings persist across launches. He is deliberately
small — at **Medium** he is about 66 × 44 points — so he reads as something
living at the edge of the screen rather than a window. His speech bubble is *not* scaled
with him, so it stays readable at any size, and it flips to hang below him when
he is perched too high for it to fit overhead.

### Idle animations

Standing around, he does something unprompted every 7–18 seconds: a hop (feet
tucked up mid-air), a stretch, a shimmy, a glance to one side and back, a double
blink, or a yawn with his eyes shut and his mouth wide open. He also hops when a
Claude Code session starts or finishes. Walking alternates two sprite frames so
his feet actually move, and his eyes turn the way he is heading.

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

**How he looks** — `Sources/ClaudeBuddy/Views/Sprite.swift` is the character
itself, as text on a 12 × 8 grid. `X` is body, `o` is ink, `.` is empty:

```
"..XXXXXXXX..",
"..XXXXXXXX..",
"XXXXXXXXXXXX",
"XXXXXXXXXXXX",
"..XXXXXXXX..",
"..XXXXXXXX..",
"..X.X..X.X..",
"..X.X..X.X.."
```

Edit a frame and rebuild. Every frame must stay 12 × 8 or he will jump between
them. Eyes and mouth are separate layers over the body, so blinking and glancing
do not need their own body frames. Colours live in `Palette.swift`;
`CharacterView.swift` picks which frame to show.

**How big he is** — `BuddySize.scale` in `Preferences.swift`.

**How he behaves** — `Sources/ClaudeBuddy/BuddyController.swift` decides moods,
where he perches, how fast he walks, and when he does something idle.
`Mood.swift` holds the per-mood animation constants, and `BuddyState.Gesture`
holds the idle animations and their durations.

## How it works

| File | Role |
| --- | --- |
| `main.swift` | AppKit entry point, accessory (no Dock icon) |
| `BuddyPanel.swift` | Transparent borderless panel; hit testing masked to his silhouette so the rest of the window does not eat desktop clicks |
| `BuddyController.swift` | Owns the panel and sensors, decides mood, picks perches, walks him there, handles dragging and following |
| `Views/Layout.swift` | Panel geometry: the character scales, the bubble does not |
| `StatusItemController.swift` | Menu bar item and the shared menu |
| `Sensors/PointerTracker.swift` | Polls the pointer at 30 Hz |
| `Sensors/ProcessScanner.swift` | `sysctl` process list and per-process CPU time |
| `Sensors/ClaudeActivityMonitor.swift` | Turns that into running/busy, with debouncing |
| `Model/BuddyState.swift` | Observable state the views draw from |
| `Views/Sprite.swift` | His pixel frames, written as text |
| `Views/` | The character, speech bubble, shapes and layout constants |

The panel is a non-activating `NSPanel`, so clicking him never steals focus from
what you were typing in.

## Notes

- The character is an original sprite drawn for this app, in the spirit of the
  Claude Code mascot. It is not Anthropic artwork.
- On the desktop layer he sits above the wallpaper but behind every window,
  including under the menu bar and Dock.
- He joins all Spaces, so he is there when you switch desktops.
