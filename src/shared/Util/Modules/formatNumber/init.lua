local simple = require(script.Simple)
local number = require(script.Parent.number)

local roundingOptions = "rounding-mode-down .00#" -- rounding mode down, 2-3 fraction digits

local function trimZeroes(input: string): string
    local decimal = string.find(input, "%.")
    local startZero = string.find(input, "0+", decimal)
    local value = input

    if startZero and decimal then
        local startLetters, endLetters = string.find(input, "%a+$")
        local abbreviation = string.sub(input, startLetters, endLetters)
        local digitStart, digitEnd = string.find(input, "[1-9]+", decimal) --get significant digits
        local significant = digitStart and digitEnd and string.sub(input, digitStart, digitEnd) or ""
        local _, trailingZeroEnd = string.find(input, "0+", digitEnd) --find any extra zeroes

        if startZero - decimal == 1 and significant == "" then --no significant digits after the zero
            value = string.sub(input, 1, decimal - 1)..abbreviation
        elseif trailingZeroEnd then
            value = string.sub(input, 1, digitEnd)..abbreviation
        end
    end

    return value
end

local function default(amount: number, trim: boolean?, decimals: number?): string
    trim = trim == nil and true or trim
    local value

    if amount > -1000 and amount < 1000 then
        decimals = decimals or 3
        value = number.readableFormat(amount, decimals)
    else
        value = simple.FormatCompact(amount, roundingOptions)
        value = trim and trimZeroes(value) or value
    end

    return value
end

local function custom(amount: number, options: string): string
    return simple.FormatCompact(amount, options)
end

return {
    FormatCompact = simple.FormatCompact,
    FormatStandard = simple.Format,
    FormatDefault = default,
    FormatCustom = custom,
}