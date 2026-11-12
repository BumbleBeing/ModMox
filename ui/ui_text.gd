class_name UiText
extends RefCounted
## The interface's own text, set in Linux Libertine (the project's default font; cards keep
## CardFonts). Libertine reads smaller than the font the sizes were first chosen for, so a
## helper that is handed a size raises it by RAISE.

## How many points a size chosen for the old font is raised by.
const RAISE: int = 2
