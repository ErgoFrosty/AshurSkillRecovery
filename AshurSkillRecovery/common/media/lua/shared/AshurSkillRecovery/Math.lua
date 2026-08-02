local RecoveryMath = {}

function RecoveryMath.clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function RecoveryMath.earned(currentXP, baselineXP)
    currentXP = tonumber(currentXP) or 0
    baselineXP = tonumber(baselineXP) or 0
    return math.max(0, currentXP - baselineXP)
end

function RecoveryMath.target(baselineXP, savedEarnedXP, recoveryFraction, maximumXP)
    baselineXP = math.max(0, tonumber(baselineXP) or 0)
    savedEarnedXP = math.max(0, tonumber(savedEarnedXP) or 0)
    recoveryFraction = RecoveryMath.clamp(tonumber(recoveryFraction) or 0, 0, 1)

    local targetXP = baselineXP + savedEarnedXP * recoveryFraction
    if maximumXP ~= nil then
        targetXP = math.min(targetXP, math.max(0, tonumber(maximumXP) or 0))
    end
    return targetXP
end

function RecoveryMath.grant(currentXP, targetXP)
    currentXP = math.max(0, tonumber(currentXP) or 0)
    targetXP = math.max(0, tonumber(targetXP) or 0)
    return math.max(0, targetXP - currentXP)
end

function RecoveryMath.mergeMaximum(existing, candidate)
    existing = math.max(0, tonumber(existing) or 0)
    candidate = math.max(0, tonumber(candidate) or 0)
    return math.max(existing, candidate)
end

return RecoveryMath

