local function safeCancel(thread: thread)
    if typeof(thread) ~= "thread" or coroutine.status(thread) == "normal" then
        return
    end
    task.cancel(thread)
end

local function safeDisconnect(connection: RBXScriptConnection | {[string]: ()->()})
    local t = typeof(connection)
    local hasDisconnect = (t == "RBXScriptConnection") or (t == "table" and typeof(connection.Disconnect) == "function")
    if not hasDisconnect then
        return
    end
    connection:Disconnect()
end

local function retry(callback: ()->(any?), default: any?, maxTries: number?, ...: any?): any?
    maxTries = maxTries or 5
    local tries = 1
    local ok, result = pcall(callback)
    while not ok and tries < maxTries do
        ok, result = pcall(callback, ...)
        tries += 1
    end
    return if ok then result else default
end

return {
    Retry = retry,
    Cancel = safeCancel,
    Disconnect = safeDisconnect,
}