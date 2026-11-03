# ELI VR 0.9.9 — a desktop shown the way VR desktops do it

**The headset's own compositor shows it.** The desktop is handed to the VR runtime as a layer of its own, a curved cylinder or a flat quad, as dedicated VR desktop apps do. Its pixels are sampled once, through the lenses, instead of being drawn into the room first and resampled again. Where a runtime has no such layer the same shape is drawn in the room, and in the flat window too.

**As sharp as the display allows, from the start.** Its size is measured against the headset: one desktop pixel to one pixel of the display, curved round you. That is large, which is what makes small text readable. Hold it with the grip to change it: move the hand to move it round you, pull the hand in or push it out to bring it nearer or send it further, stick up or down to make it larger or smaller, left or right to flatten or curve it. ELI VR remembers where you left it, and it goes with you as you walk and turn. Made smaller, it is averaged down rather than shimmering.

**Nothing in the room hides it.** The room is cleared where the screen is. Your hands, the pointer, the console and ELI are drawn over it.

**Clicking reaches the desktop on every system.** Pointing moves the desktop's pointer, the trigger clicks, and on the right hand pressing the stick in right-clicks and pushing it scrolls. This works on Wayland through GNOME's or KDE's screen-sharing portal, on X11, on macOS (which asks for Accessibility permission the first time) and on Windows (the main display). `ELI_VR_DESKTOP_INPUT=0` shows the desktop and never touches it.

**Lossless, and only what changed.** The helpers send the screen without JPEG, whole once and then only the parts that change, with nothing while it is still. ELI VR reads it on a thread of its own and uploads only the changed parts.

**Only ELI VR, run by you.** Each time it starts, the helper makes a new key and keeps it where only your account can read it. Anything that connects to it without the key is closed, so another account on the computer can neither watch your screen nor move your pointer.

Not covered yet: on Wayland desktops whose portal cannot share the pointer (Sway and other wlroots ones), the screen is shown but not clicked. There is no keyboard in the headset yet; your own keyboard types into whatever you clicked.
