# ELI VR 0.9.24 — the same rooms from less code

Nothing you see should change. This release takes out what ELI VR no longer used: the old generated room code with its shaders and pictures, an old controller model, settings nothing read, and checks that ran twice. The rooms, ELI's things and the bookcases now build their shapes through one shared kit, and the room shaders share one noise function.

Every room was compared piece by piece with 0.9.23 and is the same, and every shader was compiled on a real graphics driver. Not yet checked in a headset: if a room looks different (Deep Space, Workshop, Debug Bunker, Simulation Lab and Ocean are the ones whose shaders changed), that is a fault to report.

An environment name ELI VR does not know now opens the Orbital Core as it is today, not the retired first version of it.
