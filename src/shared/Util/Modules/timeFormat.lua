local MIN = 60
local HOUR = MIN ^ 2
local DAY_HOURS = 24
local DAY = HOUR * DAY_HOURS

local module = {}

module.toHMS = function(sec: number, letters: boolean?): string
    local hour = sec / HOUR
    local min = sec / MIN % MIN
    sec = sec % MIN

    local format = letters and "%02ih %02im %02is" or "%02i:%02i:%02i"
    if hour < 1 then
        format = letters and "%02im %02is" or "%02i:%02i"
        return string.format(format, min, sec)
    end
    return string.format(format, hour, min, sec)
end

module.toDHMS = function(sec: number, letters: boolean?): string
    local day = sec / DAY
    if day < 1 then
        return module.toHMS(sec, letters)
    end

    local hour = sec / HOUR % DAY_HOURS
    local min = sec / MIN % MIN
    sec = sec % MIN
    local format = letters and "%02id %02ih %02im %02is" or "%02i:%02i:%02i:%02i"
    return string.format(format, day, hour, min, sec)
end

return module
