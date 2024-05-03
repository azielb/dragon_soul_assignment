local HS = game:GetService("HttpService")

return function(wrapInCurlyBraces: boolean?)
    return HS:GenerateGUID(wrapInCurlyBraces)
end