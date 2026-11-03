# ELI VR 0.9.8 — sharper, smoother, and a desktop you can use

**The desktop can be used from the headset.** Point at it and its pointer goes there; the trigger clicks; on the right hand, pressing the stick in right-clicks and pushing it up or down scrolls. This goes through the screen-sharing portal: on Linux under Wayland the sharing dialog now also asks to let ELI VR use the pointer, once, and it is remembered; without that permission the desktop is shown and not touched. Holding the grip on it now holds it: with Rift CV1 controllers on Monado the grip let go the moment it was taken, so the desktop could not be moved.

**The desktop is sharp.** It comes at your monitor's own width (it was 1280 pixels across), straight onto its panel with mipmaps instead of through a second resampling, and the panel takes the screen's own shape.

**Changing rooms no longer stalls.** Every room let go of its models when it was taken down, and the next one read them from disk again: a room change froze for up to a second. The models now load once, in the background from the start, and are kept; a room builds in a tenth of a second.

**Everything is sharper.** 4x multisampling on every edge, 16x filtering on every texture, a higher headset render scale (1.15 at `high`, 1.3 at `ultra`), every scanned surface at 2K, and every piece of furniture you see up close at 2K.

ELI VR is larger for it: the 2K art adds about 190 MB.
