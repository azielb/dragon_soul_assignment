return function(className: string, properties: {[string]: any}): Instance
    local instance = Instance.new(className)
    local parent = nil

    for propertyName, value in properties do
        if propertyName == "Parent" then
            parent = value
        else
            instance[propertyName] = value
        end
    end

    instance.Parent = parent
    return instance
end