return {
    slot = "1",
    displayName = "Counter",
    cooldown = 30, --time before this move can be used again
    castTime = 30, --time before another move can be used
    normalHitDamage = 5, --damage that each regular hit of the counter cutscene does
    bigHitDamage = 10, --damage for big attacks in the cutscene
    victimDistanceFromChar = 10, --distance the victim is placed from the attacker after the cutscene completes
    resetCooldownOnDeath = true, --whether the move's cooldown should reset on death
    trailData = {
        props = {
            Lifetime = 1,
            LightEmission = 1,
        },
        attachmentPositions = {
            A0 = CFrame.new(0, 1, 0),
            A1 = CFrame.new(0, -1, 0),
        }
    },
}