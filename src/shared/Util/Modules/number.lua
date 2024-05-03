local number = {}

number.shrink = function(n)
    return n ~= 0 and math.ceil(math.log(n)/math.log(1.0000001)) or 0
end

number.grow = function(n)
    return n ~= 0 and (1.0000001^n) or 0
end

--taken from: https://gist.github.com/efrederickson/4080372
local map = {
    I = 1,
    V = 5,
    X = 10,
    L = 50,
    C = 100,
    D = 500,
    M = 1000,
}
local numbers = { 1, 5, 10, 50, 100, 500, 1000 }
local chars = { "I", "V", "X", "L", "C", "D", "M" }

number.toRomanNumerals = function(s)
    s = tonumber(s)
    if not s or s ~= s then error"Unable to convert to number" end
    if s == math.huge then error"Unable to convert infinity" end
    s = math.floor(s)
    if s <= 0 then return s end

    local ret = ""

    for i = #numbers, 1, -1 do
        local num = numbers[i]

        while s - num >= 0 and s > 0 do
            ret = ret .. chars[i]
            s = s - num
        end

        for j = 1, i - 1 do
            local n2 = numbers[j]
            if s - (num - n2) >= 0 and s < num and s > 0 and num - n2 ~= n2 then
                ret = ret .. chars[j] .. chars[i]
                s = s - (num - n2)
                break
            end
        end
    end

    return ret
end

number.fromRomanNumerals = function(s)
    s = s:upper()
    local ret = 0
    local i = 1

    while i <= s:len() do
        local c = s:sub(i, i)

        if c ~= " " then -- allow spaces
            local m = map[c] or error("Unknown Roman Numeral '" .. c .. "'")

            local next = s:sub(i + 1, i + 1)
            local nextm = map[next]

            if next and nextm then
                if nextm > m then
                    -- if string[i] < string[i + 1] then result += string[i + 1] - string[i]
                    -- This is used instead of programming in IV = 4, IX = 9, etc, because it is
                    -- more flexible and possibly more efficient
                    ret = ret + (nextm - m)
                    i = i + 1
                else
                    ret = ret + m
                end
            else
                ret = ret + m
            end
        end

        i = i + 1
    end

    return ret
end

number.getRandomDecimal = function(lower: number, upper: number, precision: number): number
    precision = precision or 100
    return math.random(lower, upper) / precision
end

number.isWithinPercent = function(value: number, max: number, threshold: number): boolean
    local percent = (value / max) * 100
    return 100 - percent <= threshold
end

--from: https://gist.github.com/Hexcede/f6afbac3d3946fc003020749c8eefa3a
number.readableFormat = function(num: number, decimals: number)
    -- If the number is whole, just round and convert to a string that way
    if math.abs(num)%1 < 1e-9 then
        return tostring(math.round(num))
    end
    -- Format as a float to the number of decimals (e.g. %.2f = 2 decimals)
    local formatted = string.format(string.format("%%.%df", math.round(decimals)), num)
    -- Find the decimal point
    local point = string.find(formatted, "%.")
    -- Find as many zeros on the end as possible (the $ anchor matches the end of the string)
    local endZeros = string.find(formatted, "0+$", point)
    -- If the zeros start 1 character after the decimal point, remove them and the decimal
    if endZeros and endZeros - point == 1 then
        return string.sub(formatted, 1, point - 1)
    end

    return string.sub(formatted, 1, endZeros and endZeros - 1 or #formatted) -- Remove the zeros
end

return number