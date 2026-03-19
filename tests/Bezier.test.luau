--!strict

local Bezier = require("../src")
local Vector3 = require("./Vector3")

type Bezier = Bezier.Bezier

local QUARTER_CIRCLE_HANDLE = 0.5522847498

local passed = 0
local failed = 0

local function test(name: string, body: () -> ()): ()
	local finished, problem = pcall(body)
	if finished then
		passed += 1
	else
		failed += 1
		print(`FAIL {name}: {problem}`)
	end
end

local function expect(condition: boolean, message: string): ()
	if not condition then
		error(message, 2)
	end
end

local function expectNear(got: Vector3, wanted: Vector3, tolerance: number, message: string): ()
	local gap = (got - wanted).Magnitude
	if gap > tolerance then
		error(`{message}: got {got}, wanted {wanted}`, 2)
	end
end

local function expectError(body: () -> (), message: string): ()
	local finished = pcall(body)
	if finished then
		error(message, 2)
	end
end

local function deCasteljau(points: { Vector3 }, t: number): Vector3
	local work = table.clone(points)
	for level = #work - 1, 1, -1 do
		for index = 1, level do
			work[index] = work[index] + (work[index + 1] - work[index]) * t
		end
	end
	return work[1]
end

local function elevate(points: { Vector3 }): { Vector3 }
	local degree = #points - 1
	local elevated = { points[1] }
	for index = 1, degree do
		local weight = index / (degree + 1)
		elevated[index + 1] = points[index] * weight + points[index + 1] * (1 - weight)
	end
	table.insert(elevated, points[degree + 1])
	return elevated
end

local LINE = { Vector3.new(0, 0, 0), Vector3.new(4, 2, 0) }

local QUADRATIC = { Vector3.new(0, 0, 0), Vector3.new(5, 10, 0), Vector3.new(10, 0, 3) }

local CUBIC = { Vector3.new(0, 0, 0), Vector3.new(2, 8, 1), Vector3.new(7, -3, 2), Vector3.new(10, 4, 0) }

local QUINTIC = {
	Vector3.new(0, 0, 0),
	Vector3.new(1, 5, 0),
	Vector3.new(3, -2, 4),
	Vector3.new(6, 6, -1),
	Vector3.new(8, 1, 2),
	Vector3.new(10, 3, 0),
}

local QUARTER_CIRCLE = {
	Vector3.new(1, 0, 0),
	Vector3.new(1, QUARTER_CIRCLE_HANDLE, 0),
	Vector3.new(QUARTER_CIRCLE_HANDLE, 1, 0),
	Vector3.new(0, 1, 0),
}

local SHAPES: { [string]: { Vector3 } } = {
	line = LINE,
	quadratic = QUADRATIC,
	cubic = CUBIC,
	quintic = QUINTIC,
}

test("New refuses fewer than two points", function()
	expectError(function(): ()
		Bezier.new({})
	end, "no points should be refused")
	expectError(function(): ()
		Bezier.new({ Vector3.new(1, 2, 3) })
	end, "one point should be refused")
end)

test("New refuses a sample count that is not a whole number of at least 1", function()
	expectError(function(): ()
		Bezier.new(LINE, 0)
	end, "zero samples should be refused")
	expectError(function(): ()
		Bezier.new(LINE, 2.5)
	end, "a fraction of a sample should be refused")
	expectError(function(): ()
		Bezier.new(LINE, 0 / 0)
	end, "NaN samples should be refused")
end)

test("Position starts on the first point and ends on the last for every degree", function()
	for name, points in SHAPES do
		local curve = Bezier.new(points)
		expectNear(curve:position(0), points[1], 0, `{name} should start on its first point`)
		expectNear(curve:position(1), points[#points], 1e-12, `{name} should end on its last point`)
	end
end)

test("The quadratic and cubic closed forms match De Casteljau", function()
	local quadratic = Bezier.new(QUADRATIC)
	local cubic = Bezier.new(CUBIC)

	for step = 0, 20 do
		local t = step / 20
		expectNear(quadratic:position(t), deCasteljau(QUADRATIC, t), 1e-9, `quadratic at {t}`)
		expectNear(cubic:position(t), deCasteljau(CUBIC, t), 1e-9, `cubic at {t}`)
	end
end)

test("A degree elevated cubic traces the same curve through the general path", function()
	local cubic = Bezier.new(CUBIC)
	local quartic = Bezier.new(elevate(CUBIC))
	local quintic = Bezier.new(elevate(elevate(CUBIC)))

	for step = 0, 20 do
		local t = step / 20
		expectNear(quartic:position(t), cubic:position(t), 1e-9, `quartic at {t}`)
		expectNear(quintic:position(t), cubic:position(t), 1e-9, `quintic at {t}`)
	end
end)

test("Position refuses T outside 0 to 1 and NaN", function()
	local curve = Bezier.new(CUBIC)

	expectError(function(): ()
		curve:position(-0.01)
	end, "a negative T should be refused")
	expectError(function(): ()
		curve:position(1.01)
	end, "a T past 1 should be refused")
	expectError(function(): ()
		curve:position(0 / 0)
	end, "NaN should be refused")
end)

test("Derivative matches a finite difference for every degree", function()
	local step = 1e-6

	for name, points in SHAPES do
		local curve = Bezier.new(points)
		for index = 1, 9 do
			local t = index / 10
			local estimate = (curve:position(t + step) - curve:position(t - step)) / (2 * step)
			expectNear(curve:derivative(t), estimate, 1e-4, `{name} derivative at {t}`)
		end
	end
end)

test("Tangent has length 1, or is zero where the curve has no direction", function()
	local curve = Bezier.new(CUBIC)
	for step = 0, 10 do
		local length = curve:tangent(step / 10).Magnitude
		expect(math.abs(length - 1) < 1e-12, `tangent at {step / 10} should have length 1, got {length}`)
	end

	local pinched = Bezier.new({ Vector3.new(0, 0, 0), Vector3.new(0, 0, 0), Vector3.new(5, 5, 0) })
	expectNear(pinched:tangent(0), Vector3.new(0, 0, 0), 0, "the pinched start should have a zero tangent")
end)

test("Length of a straight line is its distance", function()
	local curve = Bezier.new(LINE)
	expect(math.abs(curve:length() - (LINE[2] - LINE[1]).Magnitude) < 1e-12, "the line length should be exact")
end)

test("Length of the quarter circle cubic is close to a quarter of the circumference", function()
	local curve = Bezier.new(QUARTER_CIRCLE)
	local gap = math.abs(curve:length() - math.pi / 2)
	expect(gap < 1e-3, `the length should be within 0.001 of pi / 2, was off by {gap}`)
end)

test("More samples give a longer and closer length", function()
	local coarse = Bezier.new(QUINTIC, 8)
	local fine = Bezier.new(QUINTIC, 400)
	expect(fine:length() > coarse:length(), "chords can only fall short, so more samples should be longer")
end)

test("PositionAtDistance moves at an even speed on an unevenly timed line", function()
	local bunched = { Vector3.new(0, 0, 0), Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 0, 0) }
	local curve = Bezier.new(bunched)

	expect(math.abs(curve:position(0.1).X - 1) > 0.5, "T alone should not move evenly on this line")

	for distance = 0, 10 do
		expectNear(curve:positionAtDistance(distance), Vector3.new(distance, 0, 0), 1e-3, `at distance {distance}`)
	end
end)

test("PositionAtProgress takes even steps along a curve", function()
	local curve = Bezier.new(CUBIC, 200)
	local steps = 50
	local shortest: number? = nil
	local longest: number? = nil

	local previous = curve:positionAtProgress(0)
	for step = 1, steps do
		local current = curve:positionAtProgress(step / steps)
		local chord = (current - previous).Magnitude
		if shortest == nil or chord < shortest then
			shortest = chord
		end
		if longest == nil or chord > longest then
			longest = chord
		end
		previous = current
	end

	local ratio = (longest :: number) / (shortest :: number)
	expect(ratio < 1.01, `steps should be within 1% of each other, longest over shortest was {ratio}`)
	expectNear(previous, CUBIC[4], 1e-12, "progress 1 should land on the last point")
end)

test("Distance and progress lookups refuse values outside the curve", function()
	local curve = Bezier.new(CUBIC)

	expectError(function(): ()
		curve:positionAtDistance(-1)
	end, "a negative distance should be refused")
	expectError(function(): ()
		curve:positionAtDistance(curve:length() + 1)
	end, "a distance past the end should be refused")
	expectError(function(): ()
		curve:positionAtProgress(1.5)
	end, "progress past 1 should be refused")
end)

test("A curve of one repeated point has no length and stays on it", function()
	local point = Vector3.new(3, 3, 3)
	local curve = Bezier.new({ point, point, point })

	expect(curve:length() < 1e-9, `the length should be 0, got {curve:length()}`)
	expectNear(curve:positionAtProgress(0.5), point, 1e-9, "the position should be the point")
end)

test("Split gives two curves that trace the two parts of the original", function()
	for name, points in SHAPES do
		local curve = Bezier.new(points)
		local splitAt = 0.3
		local left, right = curve:split(splitAt)

		for step = 0, 10 do
			local along = step / 10
			expectNear(left:position(along), curve:position(along * splitAt), 1e-9, `{name} left half at {along}`)
			expectNear(
				right:position(along),
				curve:position(splitAt + along * (1 - splitAt)),
				1e-9,
				`{name} right half at {along}`
			)
		end

		local sum = left:length() + right:length()
		expect(math.abs(sum - curve:length()) < 1e-3, `{name} halves should add up to the whole length`)
	end
end)

test("Changing the points table after New does not change the curve", function()
	local points = table.clone(CUBIC)
	local curve = Bezier.new(points)
	local before = curve:position(0.5)

	points[2] = Vector3.new(100, 100, 100)

	expectNear(curve:position(0.5), before, 0, "the curve should keep its own copy")
end)

print(`{passed} passed, {failed} failed`)

if failed > 0 then
	error(`{failed} Bezier tests failed`)
end
