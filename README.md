<h1 align="left">Bezier</h1>

<p align="left">
  <img src="https://img.shields.io/badge/Roblox-181717?style=for-the-badge&logo=roblox&logoColor=white" />
  <img src="https://img.shields.io/badge/Luau-181717?style=for-the-badge&logo=luau&logoColor=00A2FF" />
  <img src="https://img.shields.io/badge/Types-Strict-181717?style=for-the-badge" />
</p>

Bezier curves over `Vector3` of any degree, with an arc length table so things can move along them at an even speed.

---

### About

A Bezier curve's parameter `t` runs from 0 to 1, but equal steps of `t` are not equal steps along the curve. Points bunch up where the control points do. This module keeps a table of distances along the curve so you can ask for a point by distance or by progress instead.

- **Any degree.** Two points make a line, three a quadratic, four a cubic, and so on.
- **Closed forms.** Quadratic and cubic curves are worked out directly. Every other degree uses De Casteljau.
- **Arc length table.** Built once in `new` from straight chords between samples, then searched with a binary search.
- **Even speed.** `positionAtDistance` and `positionAtProgress` move the same distance for the same step.
- **Split.** Cut a curve at any `t` into two curves that trace the same path.
- **Checked input.** At least two points, `t` and `progress` from 0 to 1, and a distance from 0 to the length. Anything else throws.

---

### Usage

```luau
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bezier = require(ReplicatedStorage.Bezier)

local arch = Bezier.new({
	Vector3.new(0, 0, 0),
	Vector3.new(5, 10, 0),
	Vector3.new(10, 0, 0),
})

print(arch:position(0.5)) -- 5, 5, 0
print(arch:tangent(0.5)) -- 1, 0, 0
print(arch:length()) -- about 14.79

print(arch:position(0.25)) -- 2.5, 3.75, 0
print(arch:positionAtProgress(0.25)) -- about 1.95, 3.14, 0

local left, right = arch:split(0.5)
print(left:position(1), right:position(0)) -- 5, 5, 0  5, 5, 0
```

Moving a part along the curve at an even speed:

```luau
local RunService = game:GetService("RunService")

local SPEED = 8

local part = workspace:WaitForChild("Mover") :: BasePart
local travelled = 0

RunService.Heartbeat:Connect(function(deltaTime: number)
	travelled = math.min(travelled + SPEED * deltaTime, arch:length())
	part.Position = arch:positionAtDistance(travelled)
end)
```

---

### API

| Function | Returns | Purpose |
| --- | --- | --- |
| `Bezier.new(points, samples?)` | `Bezier` | A curve from two or more control points. The points are copied |
| `position(t)` | `Vector3` | The point at `t` |
| `derivative(t)` | `Vector3` | How fast and which way the point moves as `t` grows |
| `tangent(t)` | `Vector3` | The direction at `t` with length 1, or zero where the curve has no direction |
| `length()` | `number` | The length of the curve, from the table |
| `parameterAtDistance(distance)` | `number` | The `t` that lies `distance` along the curve |
| `positionAtDistance(distance)` | `Vector3` | The point `distance` along the curve |
| `positionAtProgress(progress)` | `Vector3` | The point at a fraction of the length, from 0 to 1 |
| `split(t)` | `Bezier, Bezier` | Two curves that meet at `t` and trace the original |

`tangent` is zero where the derivative is zero, such as at `t = 0` when the first two points are the same.

---

### Configuration

| Argument | Default | Purpose |
| --- | --- | --- |
| `samples` | `100` | Chords in the arc length table. More is closer to the true length and costs more in `new` |

Chords always fall slightly short of the curve. For the arch above, under the `luau` CLI with doubles, 100 samples measure 14.78913 and 1000 samples measure 14.78943.

---

### Install

- **Rojo.** Sync `src` with the included `default.project.json`; it builds a ModuleScript named `Bezier`.
- **By hand.** Copy `src/init.luau` into a ModuleScript named `Bezier`.

---

### Tests

From the repo root:

```bash
luau tests/Bezier.test.luau
```

The standalone `luau` CLI has no Roblox `Vector3`, so the tests build points with the small stand-in in `tests/Vector3.luau`. The closed forms are checked against a plain De Casteljau, the general path against degree elevated cubics, and `derivative` against finite differences. The test file throws when a test fails, so the process exits with an error code.
