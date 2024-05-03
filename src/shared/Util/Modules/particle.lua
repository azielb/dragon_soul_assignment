local t = require(script.Parent.table)

local function filterParticles(particle: BasePart): {ParticleEmitter}
    return t.Filter(t.Extend(particle:GetDescendants(), {particle}), function(instance: Instance)
        return instance:IsA("ParticleEmitter")
    end)
end

local function toggle(particles: BasePart | ParticleEmitter | {ParticleEmitter}, state: boolean)
    particles = typeof(particles) == "table" and particles or filterParticles(particles)
    t.Apply(particles, function(particle: ParticleEmitter)
        particle.Enabled = state
    end)
end

local function emit(particles: BasePart | ParticleEmitter | {ParticleEmitter}, particleCount: number?)
    particles = typeof(particles) == "table" and particles or filterParticles(particles)
    toggle(particles, false)
    t.Apply(particles, function(particle: ParticleEmitter)
        particle:Emit(particleCount or particle:GetAttribute("EmitCount") or 1)
    end)
end

local function insert(particle: BasePart | ParticleEmitter, parent: Instance): (ParticleEmitter | {ParticleEmitter}, ()->())
    if particle:IsA("ParticleEmitter") then
        particle = particle:Clone()
        particle.Parent = parent
        return particle, function()
            particle:Destroy()
        end
    else
        local particles = {}
        local children = {}
        for _, child in particle:GetChildren() do
            child = child:Clone()
            if child:IsA("Attachment") then
                particles = t.Extend(particles, filterParticles(child))
            elseif child:IsA("ParticleEmitter") then
                table.insert(particles, child)
            end
            table.insert(children, child)
            child.Parent = parent
        end
        return particles, function()
            t.Apply(children, function(child: Instance)
                child:Destroy()
            end)
            children = t.Clear(children)
            particles = t.Clear(particles)
        end
    end
end

local function getLifetime(particles: BasePart | ParticleEmitter | {ParticleEmitter}): number
    particles = typeof(particles) == "table" and particles or filterParticles(particles)
    return t.Reduce(particles, function(acc: number, particle: ParticleEmitter)
        local max = particle.Lifetime.Max
        return if max > acc then max else acc
    end, -math.huge)
end

local function emitAndDestroyAfter(particle: BasePart | ParticleEmitter, parent: Instance, amount: number?, fn: (particle: ParticleEmitter)->()?)
    local particle, destroy = insert(particle, parent)
    if fn then
        if typeof(particle) == "Instance" and particle:IsA("ParticleEmitter") then
            fn(particle)
        elseif typeof(particle) == "table" then
            t.Apply(particle, fn)
        end
    end
    local lifetime = getLifetime(particle)
    emit(particle, amount)
    task.delay(lifetime, destroy)
end

return {
    emitAndDestroyAfter = emitAndDestroyAfter,
    getLifetime = getLifetime,
    filterParticles = filterParticles,
    toggle = toggle,
    emit = emit,
    insert = insert,
}