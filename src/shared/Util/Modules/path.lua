local module = {}

module.set = function(dictionary: {}, path: {string}, value: any): boolean
    for i = 1, #path - 1 do
        local key = path[i]
        if dictionary[key] ~= nil then
            dictionary = dictionary[key]
        else
            return false
        end
    end
    dictionary[path[#path]] = value
    return true
end

module.get = function(dictionary: {}, path: {string}): any?
    for _, key in ipairs(path) do
        if dictionary[key] ~= nil then
            dictionary = dictionary[key]
        else
            return
        end
    end
    return dictionary
end

return module