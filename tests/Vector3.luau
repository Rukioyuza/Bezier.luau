--!strict

type Fake = {
	X: number,
	Y: number,
	Z: number,
}

local Vector3 = {}

local METATABLE = {}

local function make(x: number, y: number, z: number): Fake
	local vector: Fake = { X = x, Y = y, Z = z }
	return setmetatable(vector, METATABLE) :: any
end

local function scale(vector: Fake, factor: number): Fake
	return make(vector.X * factor, vector.Y * factor, vector.Z * factor)
end

function METATABLE.__add(left: Fake, right: Fake): Fake
	return make(left.X + right.X, left.Y + right.Y, left.Z + right.Z)
end

function METATABLE.__sub(left: Fake, right: Fake): Fake
	return make(left.X - right.X, left.Y - right.Y, left.Z - right.Z)
end

function METATABLE.__mul(left: Fake | number, right: Fake | number): Fake
	if type(left) == "number" then
		return scale(right :: Fake, left)
	end
	return scale(left, right :: number)
end

function METATABLE.__div(left: Fake, right: number): Fake
	return make(left.X / right, left.Y / right, left.Z / right)
end

function METATABLE.__unm(vector: Fake): Fake
	return scale(vector, -1)
end

function METATABLE.__index(vector: Fake, key: string): number
	if key == "Magnitude" then
		return math.sqrt(vector.X * vector.X + vector.Y * vector.Y + vector.Z * vector.Z)
	end
	error(`the Vector3 stand-in has no member {key}`, 2)
end

function METATABLE.__tostring(vector: Fake): string
	return `{vector.X}, {vector.Y}, {vector.Z}`
end

function Vector3.new(x: number, y: number, z: number): Vector3
	return make(x, y, z) :: any
end

return Vector3
