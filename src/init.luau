--!strict

type BezierImpl = {
	__index: BezierImpl,
	new: (points: { Vector3 }, samples: number?) -> Bezier,
	position: (self: Bezier, t: number) -> Vector3,
	derivative: (self: Bezier, t: number) -> Vector3,
	tangent: (self: Bezier, t: number) -> Vector3,
	length: (self: Bezier) -> number,
	parameterAtDistance: (self: Bezier, distance: number) -> number,
	positionAtDistance: (self: Bezier, distance: number) -> Vector3,
	positionAtProgress: (self: Bezier, progress: number) -> Vector3,
	split: (self: Bezier, t: number) -> (Bezier, Bezier),
}

type BezierData = {
	read points: { Vector3 },
	read derivatives: { Vector3 },
	read samples: number,
	read distances: { number },
}

export type Bezier = setmetatable<BezierData, BezierImpl>

local DEFAULT_SAMPLES = 100

local function evaluate(points: { Vector3 }, t: number): Vector3
	local count = #points
	local u = 1 - t

	if count == 1 then
		return points[1]
	end

	if count == 2 then
		return points[1] * u + points[2] * t
	end

	if count == 3 then
		return points[1] * (u * u) + points[2] * (2 * u * t) + points[3] * (t * t)
	end

	if count == 4 then
		return points[1] * (u * u * u)
			+ points[2] * (3 * u * u * t)
			+ points[3] * (3 * u * t * t)
			+ points[4] * (t * t * t)
	end

	local work = table.clone(points)
	for level = count - 1, 1, -1 do
		for index = 1, level do
			work[index] = work[index] * u + work[index + 1] * t
		end
	end
	return work[1]
end

local function assertParameter(t: number, caller: string): ()
	assert(type(t) == "number", `Bezier:{caller} expects t to be a number, got {typeof(t)}`)
	assert(t >= 0 and t <= 1, `Bezier:{caller} expects t from 0 to 1, got {t}`)
end

local Bezier = {} :: BezierImpl
Bezier.__index = Bezier

function Bezier.new(points: { Vector3 }, samples: number?): Bezier
	assert(type(points) == "table", `Bezier.new expects a table of points, got {typeof(points)}`)
	assert(#points >= 2, `Bezier.new needs at least 2 points, got {#points}`)

	local sampleCount = samples or DEFAULT_SAMPLES
	assert(
		type(sampleCount) == "number" and sampleCount >= 1 and sampleCount % 1 == 0,
		`Bezier.new needs a whole number of samples of at least 1, got {sampleCount}`
	)

	local copied = table.clone(points)
	local degree = #copied - 1

	local derivatives: { Vector3 } = {}
	for index = 1, degree do
		derivatives[index] = (copied[index + 1] - copied[index]) * degree
	end

	local distances: { number } = { 0 }
	local previous = copied[1]
	for sample = 1, sampleCount do
		local current = evaluate(copied, sample / sampleCount)
		distances[sample + 1] = distances[sample] + (current - previous).Magnitude
		previous = current
	end

	local self: BezierData = {
		points = copied,
		derivatives = derivatives,
		samples = sampleCount,
		distances = distances,
	}
	return setmetatable(self, Bezier)
end

function Bezier.position(self: Bezier, t: number): Vector3
	assertParameter(t, "position")
	return evaluate(self.points, t)
end

function Bezier.derivative(self: Bezier, t: number): Vector3
	assertParameter(t, "derivative")
	return evaluate(self.derivatives, t)
end

function Bezier.tangent(self: Bezier, t: number): Vector3
	assertParameter(t, "tangent")

	local derivative = evaluate(self.derivatives, t)
	local speed = derivative.Magnitude
	if speed == 0 then
		return derivative
	end

	return derivative / speed
end

function Bezier.length(self: Bezier): number
	return self.distances[self.samples + 1]
end

function Bezier.parameterAtDistance(self: Bezier, distance: number): number
	local distances = self.distances
	local length = distances[self.samples + 1]
	assert(type(distance) == "number", `Bezier:parameterAtDistance expects a number, got {typeof(distance)}`)
	assert(
		distance >= 0 and distance <= length,
		`Bezier:parameterAtDistance expects a distance from 0 to {length}, got {distance}`
	)

	local low = 1
	local high = self.samples + 1
	while high - low > 1 do
		local middle = (low + high) // 2
		if distances[middle] <= distance then
			low = middle
		else
			high = middle
		end
	end

	local chordLength = distances[high] - distances[low]
	if chordLength == 0 then
		return (low - 1) / self.samples
	end

	local along = (distance - distances[low]) / chordLength
	return (low - 1 + along) / self.samples
end

function Bezier.positionAtDistance(self: Bezier, distance: number): Vector3
	local t = self:parameterAtDistance(distance)
	return evaluate(self.points, t)
end

function Bezier.positionAtProgress(self: Bezier, progress: number): Vector3
	assert(type(progress) == "number", `Bezier:positionAtProgress expects a number, got {typeof(progress)}`)
	assert(progress >= 0 and progress <= 1, `Bezier:positionAtProgress expects progress from 0 to 1, got {progress}`)

	local t = self:parameterAtDistance(progress * self:length())
	return evaluate(self.points, t)
end

function Bezier.split(self: Bezier, t: number): (Bezier, Bezier)
	assertParameter(t, "split")

	local u = 1 - t
	local work = table.clone(self.points)
	local count = #work
	local left = { work[1] }
	local right = { work[count] }

	for level = count - 1, 1, -1 do
		for index = 1, level do
			work[index] = work[index] * u + work[index + 1] * t
		end
		table.insert(left, work[1])
		table.insert(right, 1, work[level])
	end

	return Bezier.new(left, self.samples), Bezier.new(right, self.samples)
end

return Bezier
