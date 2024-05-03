local table = require(script.Parent.table)

return function(parent: Instance): Instance
    return table.Sample(parent:GetChildren(), 1)[1]
end