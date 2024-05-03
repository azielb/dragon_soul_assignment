local function debounce(cooldown, func)
    assert(type(func) == "function")

    local running = false

    return function(...)
        if not running then
            running = true
            func(...)
            task.wait(cooldown)
            running = false
        end
    end
end

return debounce