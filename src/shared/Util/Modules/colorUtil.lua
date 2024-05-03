local Math = require(script.Parent.math)
local epsilon = 0.001

local color = {}

color.darken = function(color, amount)
    return Color3.fromRGB(
        math.clamp((Math.round((255 * color.r) - amount)), 0, 255),
        math.clamp((Math.round((255 * color.g) - amount)), 0, 255),
        math.clamp((Math.round((255 * color.b) - amount)), 0, 255)
    )
end

color.lighten = function(color, amount)
    return Color3.fromRGB(
        math.clamp((Math.round((255 * color.r) + amount)), 0, 255),
        math.clamp((Math.round((255 * color.g) + amount)), 0, 255),
        math.clamp((Math.round((255 * color.b) + amount)), 0, 255)
    )
end

color.invert = function(color)
    local h, s, v = color:ToHSV()
    return Color3.fromHSV((h + 0.5) % 1, s, v)
end

color.compare = function(colorA, colorB)
    if math.abs(colorA.R - colorB.R) > epsilon then
        return false
    end
    if math.abs(colorA.G - colorB.G) > epsilon then
        return false
    end
    if math.abs(colorA.B - colorB.B) > epsilon then
        return false
    end

    return true
end

color.map = function(min, max, amount)
    local hue = Math.map(amount, min, max, 0, 1)
    hue = math.clamp(hue, 0, 1)
    return Color3.fromHSV(hue, 1, 1)
end

color.mapSin = function(amount)
    local hue = math.abs(math.sin(Math.toRadians(amount)))
    return Color3.fromHSV(hue, 1, 1)
end

return color