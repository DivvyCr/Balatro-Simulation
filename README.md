<h1 align="center">Divvy's Simulation for Balatro</h1>

<p align="center">A library for simulating Balatro scoring.</p>

> [!CAUTION]
> This is NOT a standalone mod for Balatro &mdash; it is a tool for mod developers.
> If you are looking for a way to preview scores as you play Balatro, use my preview mod:
> [Divvy's Preview](https://github.com/DivvyCr/Balatro-Preview)

## How to Add into Your Mod

This is for mod developers only!

### The Best Way

 0. You (and your players) must have [Lovely](https://github.com/ethangreen-dev/lovely-injector)
 1. Add this repository as a **Git submodule** to your mod directory:
   - `git submodule add https://github.com/DivvyCr/Balatro-Simulation /FOLDER/IN/YOUR/MOD/DIRECTORY`
   - This will ensure that whenever I update this library, your 'copy' will be automatically updated whenever you do `git pull`

### The Easy Way

 0. You (and your players) must have [Lovely](https://github.com/ethangreen-dev/lovely-injector)
 1. Copy the contents of `src/` into some directory within your mod.

## How to Use within Your Mod

First of all, it's important to check whether the library is loaded.
You can do that by checking that `DV.SIM` exists:

```lua
if not DV or not DV.SIM then
  error("Could not find Divvy's Simulation library, which is required for YOUR MOD NAME")
end
```

Then, it's as easy as using `DV.SIM.run()`.
This will simulate the score on the hand currently highlighted by the player, returning the following table:

```lua
{
  score = {
    min = 0,
    exact = 0,
    max = 0
  },
  dollars = {
    min = 0,
    exact = 0,
    max = 0
  }
}
```

For instance, you may have:

```lua
local simulation = DV.SIM.run()
if simulation.score.exact > special_threshold then
  -- Do something!
end
```

For more intricate use of this library, see how I use it in [DVPreview.lua](https://github.com/DivvyCr/Balatro-Preview/blob/main/Mods/DVPreview.lua).
The most important tip I can give is to limit the number of times you have to run the simulation.
I can't imagine any scenario where you would want to run it more than I do in `DVPreview.lua`, so feel free to use my approaches from there!
