local _, A = ...

-- Pure recommendation engine. No talent spending or game UI mutations.
function A.Expand(guide)
    local steps, ranks = {}, {}
    for _, chunk in ipairs(guide.chunks) do
        for rank = (ranks[chunk.name] or 0) + 1, chunk.rank do
            steps[#steps + 1] = { name = chunk.name, rank = rank, max = chunk.max }
        end
        ranks[chunk.name] = chunk.rank
    end
    return steps, ranks
end

local survival = {
    ['Thick Hide'] = true,
    ['Natural Reaction'] = true,
    ['Feral Instinct'] = true,
    ['Feral Charge'] = true,
    ['Lacerate'] = true,
    ['Primal Bite'] = true,
}
local damage = {
    ['Shredding Attacks'] = true,
    ['Blood Frenzy'] = true,
    ['Predatory Discipline'] = true,
    ['Rend and Tear'] = true,
    ['Shifting Power'] = true,
    ['Savage Fury'] = true,
}

function A.Evaluate(guide, nodes, options)
    options = options or {}
    local steps, targets = A.Expand(guide)
    local result = { steps = steps, targets = targets, pending = {}, completed = 0, offBuild = 0 }
    -- Fail closed if the guide's identity/rank assumptions no longer match the client.
    for _, step in ipairs(steps) do
        local node = nodes[step.name]
        if not node or node.ambiguous or node.max ~= step.max then
            result.error = 'Guide mismatch: ' .. step.name .. '. Highlights paused; check the source.'
            return result
        end
    end
    for name, node in pairs(nodes) do
        result.offBuild = result.offBuild + math.max(0, (node.rank or 0) - (targets[name] or 0))
    end
    for index, step in ipairs(steps) do
        step.index = index
        if nodes[step.name].rank >= step.rank then
            result.completed = result.completed + 1
        else
            result.pending[#result.pending + 1] = step
        end
    end
    result.next = result.pending[1]
    result.adaptive = options.adaptive or guide.hybrid or false
    result.remainingBudget = math.max(0, 51 - result.completed - result.offBuild)
    result.respecNeeded = result.offBuild > 0
    if result.adaptive then
        local candidates, seen = {}, {}
        for _, step in ipairs(result.pending) do
            local node = nodes[step.name]
            if not seen[step.name] then
                local score = 1000 - step.index
                if guide.hybrid then
                    if options.bias == 'Survival' and survival[step.name] then
                        score = score + 200
                    end
                    if options.bias == 'Damage' and damage[step.name] then
                        score = score + 200
                    end
                end
                if node.rank > 0 then
                    score = score + 5
                end
                candidates[#candidates + 1] = { step = step, score = score, legal = node.canBuy }
            end
            seen[step.name] = true
        end
        table.sort(candidates, function(a, b)
            if a.legal ~= b.legal then
                return a.legal
            end
            if a.score ~= b.score then
                return a.score > b.score
            end
            return a.step.index < b.step.index
        end)
        result.next = candidates[1] and candidates[1].step
        if result.next then
            local original = result.pending[1]
            result.advice = result.respecNeeded
                    and (result.offBuild .. ' target rank(s) will not fit. Keep current talents; exact build needs a respec.')
                or 'Keeps your current talents. Rechecks available picks after each point.'
            if original and original.name ~= result.next.name then
                result.tradeoff = 'Taking this first delays '
                    .. original.name
                    .. ' (rank '
                    .. original.rank
                    .. ').'
            elseif guide.hybrid then
                result.tradeoff = options.bias == 'Survival'
                        and 'Bear utility first; Cat damage talents may arrive later.'
                    or options.bias == 'Damage' and 'Cat damage first; Bear defenses may arrive later.'
                    or 'Balances Cat damage and Bear utility; not a pure-role optimum.'
            end
        end
        -- Only the next rank is validated against current client requirements.
        -- The rest is a priority preview, not a simulated legal leveling route.
        local preview = {}
        if result.next then
            preview[1] = result.next
        end
        for _, step in ipairs(result.pending) do
            if step ~= result.next then
                preview[#preview + 1] = step
            end
        end
        result.omitted = math.max(0, #preview - result.remainingBudget)
        while #preview > result.remainingBudget do
            table.remove(preview)
        end
        result.pending = preview
        if result.remainingBudget == 0 then
            result.next = nil
            result.exhausted = result.omitted > 0
        end
    end
    if not guide.ordered and not result.adaptive then
        -- Target builds have no published leveling order. Prefer the main tree,
        -- then shallow nodes, but only recommend a rank the client allows now.
        local candidates, seen = {}, {}
        for _, step in ipairs(result.pending) do
            local node = nodes[step.name]
            if not seen[step.name] and node.canBuy then
                candidates[#candidates + 1] = step
            end
            seen[step.name] = true
        end
        table.sort(candidates, function(a, b)
            local na, nb = nodes[a.name], nodes[b.name]
            local pa, pb = na.group == guide.spec, nb.group == guide.spec
            if pa ~= pb then
                return pa
            end
            if na.y ~= nb.y then
                return na.y < nb.y
            end
            return a.index < b.index
        end)
        result.next = candidates[1] or result.next
    end
    result.canBuy = result.next and nodes[result.next.name].canBuy or false
    return result
end

function A.Profiles(classToken)
    local result = {}
    for _, guide in ipairs(A.guides) do
        if guide.classToken == classToken then
            result[#result + 1] = guide
        end
    end
    return result
end

function A.ProfileKey(guide)
    return guide.spec .. ':' .. guide.mode
end

function A.NextPickText(result, level, firstLevel, unspent)
    if result and result.exhausted then
        return {
            heading = 'NO POINTS LEFT - RESPEC FOR TARGET',
            badge = '',
            detail = 'Current talents preserved. Exact target needs a respec.',
        }
    end
    if not result or not result.next then
        return { heading = 'BUILD COMPLETE', badge = '', detail = '' }
    end
    local milestone = firstLevel + result.next.index - 1
    local text = { detail = 'Route level ' .. milestone .. ' | point ' .. result.next.index .. '/51' }
    if result.canBuy then
        text.heading, text.badge = 'PICK THIS NOW - LEVEL ' .. level, 'NEXT - PICK NOW'
    elseif unspent == 0 and level < 60 and (result.completed + result.offBuild) < 51 then
        local nextLevel = math.max(firstLevel, level + 1)
        text.heading, text.badge = 'NEXT POINT - LEVEL ' .. nextLevel, 'NEXT - LV ' .. nextLevel
        text.detail = 'No unspent points. ' .. text.detail
    elseif unspent == 0 then
        text.heading, text.badge = 'NO POINTS LEFT - REVIEW YOUR BUILD', 'NEXT - RESPEC'
    else
        text.heading, text.badge = 'NEXT PICK - REQUIREMENTS NOT MET', 'NEXT - LOCKED'
    end
    if milestone < level and not result.canBuy then
        text.detail = text.detail .. ' (catch-up pick)'
    end
    return text
end

A.notes = {
    ['Pathfinding'] = 'Travel speed helps between pulls and quests, not just during combat.',
    ['Improved Revive Pet'] = 'Recover your pet quickly after a difficult pull.',
    ['Bestial Wrath'] = 'A major pet damage cooldown. Plan it around tough enemies.',
    ['Intimidation'] = 'Pet control helps stop a dangerous enemy or protect you.',
    ['Precision'] = 'Reliable hits reduce wasted casts or attacks; check the tooltip for this class.',
    ['Frostbite'] = 'Roots help control solo enemies; unpredictable roots can change group pulling.',
    ['Ice Barrier'] = 'An absorb gives you more room to cast safely under pressure.',
    ['Cold Snap'] = 'Reset defensive or offensive Frost cooldowns when a fight demands it.',
    ['Spirit Tap'] = 'Plan around killing blows to make use of the mana recovery.',
    ['Wand Specialization'] = 'Wand damage provides a low-mana way to finish enemies.',
    ['Improved Corruption'] = 'Makes applying your core damage-over-time spell easier while moving.',
    ['Feral Swiftness'] = 'Movement helps you reach the next target and reposition.',
    ['Blade Flurry'] = 'Useful when fighting nearby enemies together; watch crowd-controlled targets.',
    ['Adrenaline Rush'] = 'Extra Energy supports a burst window; avoid wasting it at full Energy.',
    ['Piercing Howl'] = 'A control tool for creating space when a pull becomes dangerous.',
    ['Flurry'] = 'Critical strikes feed attack-speed uptime; benefits depend on your gear.',
    ['Arcane Power'] = 'Budget mana for this damage window and its increased spell costs.',
    ["Nature's Swiftness"] = 'Keep an instant cast available for a dangerous moment.',
}

function A.Reason(guide, step)
    if A.current and A.current.adaptive and A.current.next == step then
        return (A.current.tradeoff or A.current.advice or '')
    end
    return A.notes[step.name]
        or (
            guide.ordered
                and 'This rank advances the published leveling route. Read the live tooltip for its effect and requirements.'
            or 'This rank is part of the selected PvE target build. Its position here is suggested by the addon, not a published leveling priority.'
        )
end
