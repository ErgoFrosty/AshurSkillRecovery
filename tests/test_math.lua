package.path = "AshurSkillRecovery/common/media/lua/shared/?.lua;" .. package.path

local Math = require "AshurSkillRecovery/Math"

local function close(actual, expected, label)
    assert(math.abs(actual - expected) < 0.000001,
        label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

close(Math.earned(1275, 225), 1050, "starting +2 is excluded")
close(Math.earned(225, 225), 0, "starting XP alone is not earned")
close(Math.earned(100, 225), 0, "earned XP cannot be negative")

close(Math.target(0, 1050, 1, 32775), 1050, "recipient without a bonus")
close(Math.target(225, 1050, 1, 32775), 1275, "recipient keeps own +2 baseline")
close(Math.target(0, 1050, 0.5, 32775), 525, "partial recovery")
close(Math.target(225, 40000, 1, 32775), 32775, "level-ten cap")

close(Math.grant(0, 1050), 1050, "fresh recipient receives deficit")
close(Math.grant(1050, 1050), 0, "second read is idempotent")
close(Math.grant(1300, 1050), 0, "recovery never removes XP")

close(Math.mergeMaximum(1050, 500), 1050, "weaker writer cannot overwrite")
close(Math.mergeMaximum(1050, 1400), 1400, "stronger writer updates")

print("recovery math: all tests passed")
