return function(stop: number, callback: (index: number)->())
    for index = 1, stop do
        callback(index)
    end
end