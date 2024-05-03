return function(parent: Instance, classes: {string})
    for _, child in parent:GetChildren() do
        for _, class in classes do
            if not child:IsA(class) then
                child:Destroy()
                break
            end
        end
    end
end