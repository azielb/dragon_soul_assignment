local BAD_ARG_ERROR = "%s is not a valid %s"

local function WaitForChild(target, path, maxWait)
    assert(typeof(target) == "Instance", BAD_ARG_ERROR:format("Argument 1","Instance"))
    assert(typeof(path) == "string", BAD_ARG_ERROR:format("Argument 2","string"))
    assert(typeof(maxWait) == "number" or typeof(maxWait) == "nil", BAD_ARG_ERROR:format("Argument 3","number or nil"))

    local segments = string.split(path,".")
    local latest
    local start = tick()
    maxWait = maxWait or 10

    for _, segment in ipairs(segments) do
        latest = target:WaitForChild(segment, math.max(1, (start + maxWait) - tick()))

        if latest then
            target = latest
        else
            return warn(`'{segment}' does not exist, retuning nil`)
        end
    end

    return latest
end

return WaitForChild