return function(udim2: UDim2, scale: number): UDim2
    return UDim2.new(udim2.X.Scale * scale, udim2.X.Offset, udim2.Y.Scale * scale, udim2.Y.Offset)
end
