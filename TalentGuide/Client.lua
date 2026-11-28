local _, A = ...
A.overlays = setmetatable({}, { __mode = 'k' })

function A.TalentFrame()
    return PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
end

function A.ReadClient(frame)
    if not C_Traits or not C_ClassTalents then
        return nil, 'Forever talent APIs are unavailable.'
    end
    -- Other locales are matched by tree position instead; see Localization.lua.
    if GetLocale() ~= 'enUS' and GetLocale() ~= 'enGB'
        and not (A.CanLocalize and A.CanLocalize()) then
        return nil, 'This guide pack has no talent table for your class in this language.'
    end
    if frame:IsInspecting() then
        return nil, 'Inspecting another player: guidance paused.'
    end
    if frame.IsLocked and frame:IsLocked() then
        return nil, 'Select your active talent tab for guidance.'
    end
    local config = frame:GetConfigID()
    if not config then
        return nil, 'Open your talent tree to load its data.'
    end
    local info = C_Traits.GetConfigInfo(config)
    if not info or not info.treeIDs then
        return nil, 'Waiting for talent data.'
    end
    local nodes, total, seen = {}, 0, {}
    local unspent, currencies = nil, {}
    local positions = A.BuildNodePositions and A.BuildNodePositions(config, info) or nil
    for _, tree in ipairs(info.treeIDs) do
        if C_Traits.GetTreeCurrencyInfo then
            for _, currency in ipairs(C_Traits.GetTreeCurrencyInfo(config, tree, false) or {}) do
                if not currencies[currency.traitCurrencyID] then
                    currencies[currency.traitCurrencyID] = true
                    unspent = (unspent or 0) + currency.quantity
                end
            end
        end
        local groups, icons = {}, {}
        local groupOrder = {}
        for index, group in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(tree) or {}) do
            groups[group.groupID], groupOrder[group.groupID] = group.displayName, index
            icons[group.groupID] = group.icon
        end
        for _, id in ipairs(C_Traits.GetTreeNodes(tree) or {}) do
            local node = C_Traits.GetNodeInfo(config, id)
            if node and not seen[id] then
                seen[id] = true
                total = total + (node.ranksPurchased or 0)
                for _, entryID in ipairs(node.entryIDs or {}) do
                    local entry = C_Traits.GetEntryInfo(config, entryID)
                    local def = entry
                        and entry.definitionID
                        and C_Traits.GetDefinitionInfo(entry.definitionID)
                    local spell = def and def.spellID
                    local name = def and (def.overrideName or (spell and C_Spell.GetSpellName(spell)))
                    -- The client names talents in its own language while the
                    -- routes are English, so swap in the English name when the
                    -- node's position identifies it.
                    local localizedName = name
                    local english = positions and A.EnglishTalentName(positions[id], node.maxRanks)
                    if english then
                        name = english
                    end
                    if name and name ~= '' then
                        local rank = (node.activeEntry and node.activeEntry.entryID == entryID)
                                and (node.ranksPurchased or 0)
                            or 0
                        local button = frame:GetTalentButtonByNodeID(id)
                        local canBuy = node.isVisible
                            and node.isAvailable
                            and C_Traits.CanPurchaseRank(config, id, entryID)
                            and button
                            and button.CanPurchaseRank
                            and button:CanPurchaseRank()
                        local previous = nodes[name]
                        nodes[name] = {
                            id = id,
                            entryID = entryID,
                            spell = spell,
                            rank = rank,
                            max = node.maxRanks,
                            canBuy = not not canBuy,
                            y = node.posY or 0,
                            group = groups[(node.groupIDs or {})[1]],
                            groupIndex = groupOrder[(node.groupIDs or {})[1]],
                            groupIcon = icons[(node.groupIDs or {})[1]],
                            ambiguous = previous ~= nil,
                            localizedName = localizedName,
                        }
                    end
                end
            end
        end
    end
    return nodes, nil, config, total, unspent
end

function A.ClearHighlights()
    for _, overlay in pairs(A.overlays) do
        overlay:Hide()
    end
end

local function AddTooltip(button)
    if not A.current or A.current.error or not A.nodes or not A.guide then
        return
    end
    local id = button:GetNodeID()
    for name, node in pairs(A.nodes) do
        local target = A.current.targets[name]
        if node.id == id then
            target = target or 0
            GameTooltip:AddLine(' ')
            GameTooltip:AddLine('Talent Guide | ' .. A.guide.spec, 0.4, 0.85, 1)
            GameTooltip:AddLine(
                node.rank > target and 'Not recommended for this build (not universally bad).'
                    or 'Good: included in this build.',
                node.rank > target and 1 or 0.3,
                node.rank > target and 0.25 or 1,
                0.3,
                true
            )
            GameTooltip:AddLine(
                ('Build target: %d/%d | Purchased: %d'):format(target, node.max, node.rank),
                1,
                1,
                1
            )
            local step = { name = name }
            GameTooltip:AddLine(A.Reason(A.guide, step), 0.8, 0.85, 0.9, true)
            GameTooltip:AddLine('Source: ' .. A.guide.publisher .. ' | ' .. A.guide.status, 1, 0.7, 0.3, true)
            GameTooltip:Show()
            return
        end
    end
end

function A.PaintHighlights(frame)
    A.ClearHighlights()
    if not A.current or A.current.error then
        return
    end
    for name, node in pairs(A.nodes) do
        local target = A.current.targets[name] or 0
        local bad = node.rank > target
        local good = node.rank > 0 and node.rank <= target
        if target > 0 or bad then
            local button = frame:GetTalentButtonByNodeID(node.id)
            if button and button:IsShown() then
                local overlay = A.overlays[button]
                if not overlay then
                    overlay = CreateFrame('Frame', nil, button, 'BackdropTemplate')
                    overlay:SetPoint('TOPLEFT', button, 'TOPLEFT', -4, 4)
                    overlay:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', 4, -4)
                    overlay:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 2 })
                    overlay:EnableMouse(false)
                    -- A separate badge layer stays above neighboring talent icons
                    -- and the animated glow; all labels belong above their icon.
                    overlay.badge = CreateFrame('Frame', nil, overlay)
                    overlay.badge:EnableMouse(false)
                    overlay.badge:SetPoint('BOTTOM', button, 'TOP', 0, 3)
                    overlay.badge:SetHeight(14)
                    local background = overlay.badge:CreateTexture(nil, 'BACKGROUND')
                    overlay.badgeBackground = background
                    background:SetAllPoints()
                    background:SetColorTexture(0.035, 0.027, 0.018, 0.94)
                    overlay.label = overlay.badge:CreateFontString(nil, 'OVERLAY')
                    overlay.label:SetPoint('CENTER')
                    overlay.label:SetJustifyH('CENTER')
                    overlay.label:SetWordWrap(false)
                    overlay.arrows = CreateFrame('Frame', nil, overlay)
                    overlay.arrows:EnableMouse(false)
                    overlay.leftArrow = overlay.arrows:CreateFontString(nil, 'OVERLAY')
                    overlay.rightArrow = overlay.arrows:CreateFontString(nil, 'OVERLAY')
                    for _, arrow in ipairs({ overlay.leftArrow, overlay.rightArrow }) do
                        arrow:SetFont(STANDARD_TEXT_FONT, 26, 'OUTLINE')
                        arrow:SetTextColor(1, 0.82, 0.18)
                    end
                    overlay.leftArrow:SetText('>')
                    overlay.rightArrow:SetText('<')
                    overlay.glow = CreateFrame('Frame', nil, overlay, 'BackdropTemplate')
                    overlay.glow:SetPoint('TOPLEFT', -4, 4)
                    overlay.glow:SetPoint('BOTTOMRIGHT', 4, -4)
                    overlay.glow:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 5 })
                    overlay.glow:SetBackdropBorderColor(1, 0.68, 0.08, 0.75)
                    overlay.glow:EnableMouse(false)
                    overlay.phase = 0
                    overlay.pulse = function(self, elapsed)
                        if not self.isNext or A.db.animate == false then
                            return
                        end
                        self.phase = self.phase + elapsed * 3
                        self.glow:SetAlpha(0.3 + 0.7 * (0.5 + 0.5 * math.sin(self.phase)))
                        local offset = 3 + 3 * (0.5 + 0.5 * math.sin(self.phase))
                        self.leftArrow:SetPoint('RIGHT', button, 'LEFT', -offset, 0)
                        self.rightArrow:SetPoint('LEFT', button, 'RIGHT', offset, 0)
                    end
                    A.overlays[button] = overlay
                    button:HookScript('OnEnter', AddTooltip)
                end
                overlay:SetFrameLevel(button:GetFrameLevel() + 5)
                local isNext = A.current.next and A.current.next.name == name
                overlay.badge:SetFrameLevel(frame:GetFrameLevel() + (isNext and 2002 or 2000))
                overlay.arrows:SetFrameLevel(frame:GetFrameLevel() + 2001)
                overlay.arrows:Hide()
                overlay.leftArrow:SetPoint('RIGHT', button, 'LEFT', -3, 0)
                overlay.rightArrow:SetPoint('LEFT', button, 'RIGHT', 3, 0)
                local badgeWidth = isNext and 88 or (bad and 100 or 44)
                overlay.badge:SetWidth(badgeWidth)
                overlay.badge:SetHeight(isNext and 18 or 14)
                overlay.badgeBackground:SetColorTexture(0.035, 0.027, 0.018, 0.94)
                overlay.label:SetFont(
                    STANDARD_TEXT_FONT,
                    isNext and 12 or (bad and 8 or 10),
                    isNext and '' or 'OUTLINE'
                )
                overlay.label:SetWidth(badgeWidth - 4)
                overlay.label:SetHeight(isNext and 18 or 14)
                overlay.badge:Hide()
                overlay.isNext = isNext
                overlay:SetScript('OnUpdate', isNext and A.db.animate ~= false and overlay.pulse or nil)
                overlay.glow:SetAlpha(1)
                overlay.glow:Hide()
                overlay.label:SetText(isNext and 'NEXT PICK' or '')
                if isNext then
                    overlay.badge:Show()
                    overlay.arrows:Show()
                    overlay.badgeBackground:SetColorTexture(1, 0.76, 0.12, 1)
                    overlay.glow:Show()
                    overlay:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 4 })
                    overlay:SetBackdropBorderColor(1, 0.82, 0.18, 1)
                    overlay.label:SetTextColor(0.08, 0.035, 0.005)
                elseif bad or good then
                    overlay.badge:Show()
                    overlay:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 2 })
                    overlay:SetBackdropBorderColor(bad and 1 or 0.2, bad and 0.15 or 1, 0.2, 1)
                    overlay.label:SetText(bad and 'Not recommended' or 'Good')
                    overlay.label:SetTextColor(bad and 1 or 0.3, bad and 0.25 or 1, 0.3)
                else
                    overlay:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 })
                    overlay:SetBackdropBorderColor(0.3, 0.65, 1, 0.65)
                end
                if isNext or ((bad or good) and A.db.showRatings ~= false) or A.db.showBuild then
                    overlay:Show()
                else
                    overlay:Hide()
                end
            end
        end
    end
end

function A.AttachTalentHooks()
    local frame = A.TalentFrame()
    if not frame or A.hookedFrame == frame then
        return
    end
    A.hookedFrame = frame
    frame:HookScript('OnShow', function()
        A.dismissed = false
        A.Refresh()
    end)
    frame:HookScript('OnHide', function()
        A.ClearHighlights()
        A.current, A.nodes = nil, nil
        if A.panel then
            A.panel:Hide()
            A.panel.menu:Hide()
        end
    end)
end

function A.Refresh()
    A.AttachTalentHooks()
    local frame = A.TalentFrame()
    if
        not A.db
        or not A.db.enabled
        or A.dismissed
        or not frame
        or not frame:IsVisible()
        or frame:IsInspecting()
        or InCombatLockdown()
    then
        A.ClearHighlights()
        A.current, A.nodes = nil, nil
        if A.panel then
            A.panel:Hide()
        end
        return
    end
    if not A.panel then
        A.CreateUI()
    end
    local nodes, errorText, config, total, unspent = A.ReadClient(frame)
    A.nodes = nodes
    A.config = config
    A.unspent, A.total = unspent, total
    local _, class = UnitClass('player')
    A.profiles = A.Profiles(class)
    local key = tostring(config or 'default')
    local saved = A.db.selections[key]
    -- Version 0.1 stored an index: one leveling guide followed by three PvE guides.
    if type(saved) == 'number' then
        local old = {}
        old[1] = A.profiles[1]
        for _, guide in ipairs(A.profiles) do
            if guide.mode == 'PvE' then
                old[#old + 1] = guide
            end
        end
        saved = old[saved] and A.ProfileKey(old[saved]) or nil
        A.db.selections[key] = saved
    end
    local selection = 1
    for index, guide in ipairs(A.profiles) do
        if A.ProfileKey(guide) == saved then
            selection = index
        end
    end
    A.selection = selection
    A.guide = A.profiles[selection]
    A.current = nodes
            and A.guide
            and A.Evaluate(A.guide, nodes, { adaptive = A.db.adaptive, bias = A.db.bias })
        or nil
    A.Draw(errorText or (not A.guide and 'No guide available for this class.'))
    A.PositionPanel()
    A.panel:Show()
    A.PaintHighlights(frame)
end

local events = CreateFrame('Frame')
A.events = events
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent', function(_, event, addon)
    if event == 'ADDON_LOADED' and addon == 'TalentGuide' then
        TalentGuideDB = type(TalentGuideDB) == 'table' and TalentGuideDB or {}
        A.db = TalentGuideDB
        -- Version 0.1 persisted the close button as a full disable. Recover that
        -- legacy state once; only an explicit /tg off is persistent now.
        if A.db.visibilityVersion ~= 1 then
            A.db.enabled = not A.db.explicitOff
            A.db.visibilityVersion = 1
        end
        if A.db.enabled == nil then
            A.db.enabled = true
        end
        A.db.selections = type(A.db.selections) == 'table' and A.db.selections or {}
        A.db.firstLevel = math.max(5, math.min(10, tonumber(A.db.firstLevel) or 10))
        if A.db.layoutVersion ~= 2 then
            A.db.position = nil
            A.db.layoutVersion = 2
        end
        if A.db.scale == nil then
            A.db.scale = 1
        end
        if A.db.bias == nil then
            A.db.bias = 'Balanced'
        end
        if A.BuildSettings then
            A.BuildSettings()
        end
        A.Refresh()
    elseif event == 'PLAYER_LOGIN' then
        A.AttachTalentHooks()
        A.Refresh()
    elseif A.db then
        A.AttachTalentHooks()
        -- Let Blizzard update its button cache before checking affordability.
        if C_Timer and C_Timer.After then
            if not A.refreshPending then
                A.refreshPending = true
                C_Timer.After(0, function()
                    A.refreshPending = false
                    A.Refresh()
                end)
            end
        else
            A.Refresh()
        end
    end
end)
for _, event in ipairs({
    'TRAIT_CONFIG_UPDATED',
    'TRAIT_NODE_CHANGED',
    'TRAIT_NODE_CHANGED_PARTIAL',
    'TRAIT_TREE_CHANGED',
    'PLAYER_TALENT_UPDATE',
    'PLAYER_LEVEL_UP',
    'PLAYER_REGEN_ENABLED',
    'PLAYER_REGEN_DISABLED',
}) do
    events:RegisterEvent(event)
end

SLASH_TALENTGUIDE1 = '/tg'
-- Small optional bridge for the shared Raynna settings page. Neither addon
-- requires the other to load, and callbacks read the current saved state.
RaynnaTalentGuide = {
    IsEnabled = function()
        return A.db and A.db.enabled or false
    end,
    SetEnabled = function(enabled)
        if not A.db then
            return
        end
        A.db.enabled, A.db.explicitOff, A.dismissed = enabled, not enabled, false
        A.Refresh()
    end,
    Open = function()
        SlashCmdList.TALENTGUIDE('')
    end,
    Reset = function()
        SlashCmdList.TALENTGUIDE('reset')
        SlashCmdList.TALENTGUIDE('')
    end,
    ApplyAppearance = function()
        if A.ApplyAppearance then
            A.ApplyAppearance()
        end
    end,
}
SLASH_TALENTGUIDE2 = '/talentguide'
SlashCmdList.TALENTGUIDE = function(message)
    if not A.db then
        return
    end
    message = (message or ''):lower():match('^%s*(.-)%s*$')
    if message == 'settings' then
        RaynnaModsSettingsRegistry:Open('talentguide')
        return
    elseif message == 'off' then
        A.db.enabled = false
        A.db.explicitOff = true
    elseif message == 'reset' then
        A.db.enabled, A.db.explicitOff, A.dismissed = true, nil, false
        A.db.position = nil
        if A.panel then
            A.PositionPanel()
        end
    else
        A.db.enabled = true
        A.db.explicitOff = nil
        A.dismissed = false
        if not InCombatLockdown() then
            if C_AddOns then
                C_AddOns.LoadAddOn('Blizzard_PlayerSpells')
            end
            if PlayerSpellsUtil and PlayerSpellsUtil.OpenToClassTalentsTab then
                PlayerSpellsUtil.OpenToClassTalentsTab()
            elseif PlayerSpellsUtil and PlayerSpellsUtil.TogglePlayerSpellsFrame then
                local f = A.TalentFrame()
                if not f or not f:IsVisible() then
                    PlayerSpellsUtil.TogglePlayerSpellsFrame(2)
                end
            end
        end
    end
    A.Refresh()
end
