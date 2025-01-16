<h1 align="center">Divvy's Simulation for Balatro</h1>

<p align="center">A library for simulating Balatro scoring.</p>

> [!CAUTION]
> This is NOT a standalone mod for Balatro &mdash; it is a tool for mod developers.
> If you are looking for a way to preview scores as you play Balatro, use my preview mod:
> [Divvy's Preview](https://github.com/DivvyCr/Balatro-Preview)

## How to Add into Your Mod

This is for mod developers only:

 0. You (and your players) must have [Lovely](https://github.com/ethangreen-dev/lovely-injector)
 1. Copy the contents of `src/` into a directory within your mod.
 
> [!TIP]
> Ideally, your mod and this library should be in separate folders on the user's computer, like this:<br>
> `.../AppData/Roaming/Balatro/Mods/DVSimulate/`<br>
> `.../AppData/Roaming/Balatro/Mods/YOUR_MOD/`<br>
> If you can, separate your mod and this library in your release.
> An example of this is shown in the releases of 
> [Divvy's Preview](https://github.com/DivvyCr/Balatro-Preview/releases)
> (download the release to see its structure)

## How to Use within Your Mod

First of all, it's important to check whether the library is loaded.
I am not entirely sure in what order Lovely loads Steamodded (compared to this library), so this may cause errors.
At the end of the day, this is just good practice and not mandatory.
You can do that by checking that `DV.SIM` exists:

```lua
if not DV or not DV.SIM then
  error("Could not find Divvy's Simulation library, which is required for YOUR MOD NAME")
end
```

Then, it's as easy as running `DV.SIM.run()`.
This will simulate the score on the hand currently highlighted by the player.
In the near future, I should make it possible to give arguments to the simulation, such as custom hands, jokers, etc.

```lua
-- DV.SIM.run() returns the following table:
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

### Examples

The simplest use could look like:

```lua
local simulation = DV.SIM.run()
if simulation.score.exact > special_threshold then
  -- Do something!
end
```

For more intricate use of this library, see how I use it in [DVPreview.lua](https://github.com/DivvyCr/Balatro-Preview/blob/main/Mods/DVPreview.lua).
The most important tip I can give is to limit the number of times you have to run the simulation.
I can't imagine any scenario where you would want to run it more than I do in `DVPreview.lua`, so feel free to use my approaches from there!

