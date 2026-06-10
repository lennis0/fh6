# fh6 – Phase 1 Setup Guide

This guide takes you from zero to driving the car in Roblox Studio.  
The workflow is: **write code in this repo → Rojo syncs it into Studio → press Play**.

---

## What you need to install (once)

### 1. Roblox Studio
Download from https://www.roblox.com/create  
Install and log in with your Roblox account.

### 2. Rojo CLI
Rojo is the tool that syncs files from this repo into Studio.

1. Go to https://github.com/rojo-rbx/rojo/releases/latest
2. Download `rojo-windows-x86_64.zip`
3. Unzip it and move `rojo.exe` somewhere on your PATH  
   (e.g. `C:\Windows\System32\` or create a `C:\tools\` folder and add it to PATH)
4. Test: open a terminal and type `rojo --version` – you should see a version number.

### 3. Rojo plugin for Roblox Studio
1. Open Roblox Studio.
2. In the top bar click **Plugins → Manage Plugins**.
3. Search for **Rojo** and install the official plugin by Roblox.
4. A **Rojo** button will now appear in your Plugins toolbar.

---

## Running the project

### Step 1 – Serve the project
Open a terminal in the `fh6` folder and run:

```
rojo serve
```

You should see:
```
Rojo server listening on port 34872
```

Leave this terminal open while you work.

### Step 2 – Connect Studio
1. Open Roblox Studio and create a **New Baseplate** place (or any place).
2. Click the **Rojo** button in the Plugins toolbar.
3. Click **Connect** (it auto-discovers the local server).
4. Your scripts will now appear inside Studio – you can see them in the Explorer.

> **Tip:** Make the Baseplate bigger so you have more room to drive.  
> Select the Baseplate part → Properties → Size → set X and Z to `2048`.

### Step 3 – Play test
Press **F5** (or the Play button) in Studio.  
Your character will spawn, a red car will appear behind you, and you'll be automatically seated.

---

## Controls

| Key | Action |
|-----|--------|
| W / Up arrow | Accelerate |
| S / Down arrow | Brake / Reverse |
| A / Left arrow | Steer left |
| D / Right arrow | Steer right |
| Right mouse button + drag | Orbit camera |

---

## File structure

```
fh6/
├── default.project.json          ← Rojo config (maps src/ into Studio)
├── src/
│   ├── ReplicatedStorage/
│   │   └── CarConfig.luau        ← Tune car feel here (speed, turn, etc.)
│   ├── ServerScriptService/
│   │   └── CarSpawner.server.luau ← Builds car model, seats player
│   └── StarterPlayerScripts/
│       ├── CarController.client.luau  ← Input + BodyVelocity physics
│       ├── CameraController.client.luau ← Spring follow-cam
│       └── SpeedometerGui.client.luau  ← Speed HUD
```

## Tuning the car

Open `src/ReplicatedStorage/CarConfig.luau` and change the numbers:

| Field | Effect |
|-------|--------|
| `MaxSpeed` | Top speed (studs/s). 100 feels like ~80 km/h. |
| `Acceleration` | How quickly you reach top speed. |
| `BrakeForce` | How hard the brakes bite. |
| `TurnSpeed` | Maximum rotation rate (rad/s). Lower = wider turns. |
| `Friction` | How much speed you keep when coasting. 1.0 = no friction. |
| `CameraDistance` | How far behind the car the camera sits. |
| `CameraHeight` | How high above the car the camera sits. |

Save the file – Rojo will instantly sync the change into Studio. Reload the play test to feel the difference.

---

## Troubleshooting

**Car doesn't appear / I'm not seated**  
Make sure `CarSpawner.server.luau` is under `ServerScriptService` in the Studio Explorer.  
Reconnect Rojo if the scripts are missing.

**Camera is stuck / not following**  
Make sure `CameraController.client.luau` is under `StarterPlayer > StarterPlayerScripts`.

**Car flies away or spins uncontrollably**  
This can happen if physics ownership isn't granted. Try pressing Play again.  
If it persists, lower `BrakeForce` in CarConfig.

**`rojo: command not found`**  
You need to add `rojo.exe` to your PATH. See step 2 of "What you need to install".
