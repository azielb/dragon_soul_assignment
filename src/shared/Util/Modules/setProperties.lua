return function(instance: Instance, props: {[string]: any})
    for prop, value in props do
        instance[prop] = value
    end
end