local _, A = ...
local WIDTH, HEIGHT, ROWS = 310, 506, 4

local function Text(parent, size, x, y, width)
    local text = parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    text:SetFont(STANDARD_TEXT_FONT, size)
    text:SetPoint('TOPLEFT', x, y)
    text:SetWidth(width or 282)
    text:SetJustifyH('LEFT')
    text:SetJustifyV('TOP')
    text:SetTextColor(unpack(A.Theme.text))
    return text
end

local function Button(parent, label, x, y, width, callback)
    local button = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    button:SetPoint('TOPLEFT', x, y)
    button:SetSize(width, 22)
    button:SetText(label)
    button:SetScript('OnClick', callback)
    return button
end

local function Icon(parent, x, y, size)
    local icon = parent:CreateTexture(nil, 'ARTWORK')
    icon:SetPoint('TOPLEFT', x, y)
    icon:SetSize(size, size)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    return icon
end

local function SpellIcon(name)
    local node = A.nodes and A.nodes[name]
    return node and node.spell and C_Spell.GetSpellTexture(node.spell) or 134400
end

function A.SpecIcon(spec)
    local treeSpec = spec
    -- Resolve the requested profile, even when another dropdown entry is selected.
    for _, guide in ipairs(A.profiles or {}) do
        if guide.spec == spec then
            treeSpec = guide.treeSpec or spec
            break
        end
    end
    for _, node in pairs(A.nodes or {}) do
        if node.group == treeSpec and node.groupIcon then
            return node.groupIcon
        end
    end
    return 134400
end

function A.Select(index)
    A.db.selections[tostring(A.config or 'default')] = A.ProfileKey(A.profiles[index])
    A.page = 0
    if A.panel then
        A.panel.menu:Hide()
        A.panel.sourceBox:Hide()
    end
    A.Refresh()
end

function A.SelectMode(mode)
    for index, guide in ipairs(A.profiles or {}) do
        if (guide.spec == A.guide.spec or guide.spec == A.guide.treeSpec) and guide.mode == mode then
            A.Select(index)
            return
        end
    end
end

function A.SetScale(value)
    value = math.max(0.4, math.min(1.8, tonumber(value) or 1))
    local effective = math.min(value, math.max(0.4, (UIParent:GetHeight() - 30) / HEIGHT))
    if A.panel and A.panel:IsShown() then
        local x, y = A.panel:GetLeft(), A.panel:GetTop()
        local ratio = A.panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if x and y then
            A.db.position = { 'TOPLEFT', 'BOTTOMLEFT', x * ratio / effective, y * ratio / effective }
        end
    end
    A.db.scale = math.max(0.4, math.min(1.8, value))
    A.PositionPanel()
end

function A.PositionPanel()
    local p = A.panel
    if not p or p.dragging then
        return
    end
    p:SetScale(math.min(A.db.scale or 1, math.max(0.4, (UIParent:GetHeight() - 30) / HEIGHT)))
    p:ClearAllPoints()
    local pos = A.db.position
    if pos then
        p:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
        return
    end
    local frame = A.TalentFrame()
    if not frame then
        p:SetPoint('CENTER', UIParent, 'CENTER')
        return
    end
    -- Dock beside the tree when there is room, otherwise remain inside the
    -- talent window on the opposite side of the selected specialization.
    local right = frame:GetRight()
    local space = right
        and UIParent:GetWidth() - right * frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if space and space >= WIDTH + 8 then
        p:SetPoint('TOPLEFT', frame, 'TOPRIGHT', 6, -32)
    else
        local left = false
        for _, node in pairs(A.nodes or {}) do
            if A.guide and node.group == A.guide.spec and node.groupIndex == 3 then
                left = true
            end
        end
        p:SetPoint(
            left and 'TOPLEFT' or 'TOPRIGHT',
            frame,
            left and 'TOPLEFT' or 'TOPRIGHT',
            left and 14 or -14,
            -92
        )
    end
end

local function TalentTooltip(self)
    if not self.step then
        return
    end
    GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
    local node = A.nodes and A.nodes[self.step.name]
    if node and node.spell then
        GameTooltip:SetSpellByID(node.spell)
    else
        GameTooltip:SetText(self.step.name)
    end
    GameTooltip:AddLine(A.Reason(A.guide, self.step), 0.92, 0.86, 0.72, true)
    GameTooltip:Show()
end

function A.ToggleSpecMenu()
    local menu = A.panel.menu
    if menu:IsShown() then
        menu:Hide()
        return
    end
    local count = 0
    for index, guide in ipairs(A.profiles or {}) do
        if guide.mode == A.guide.mode then
            count = count + 1
            local row = menu.rows[count]
            if not row then
                row = Button(menu, '', 6, -6 - (count - 1) * 28, 270, function(self)
                    A.Select(self.profileIndex)
                end)
                row.icon = Icon(row, 5, -3, 16)
                menu.rows[count] = row
            end
            row.profileIndex = index
            row:SetText((guide.spec == A.guide.spec and '|cffffd100' or '') .. guide.spec .. '|r')
            row.icon:SetTexture(A.SpecIcon(guide.spec))
            row:Show()
        end
    end
    for i = count + 1, #menu.rows do
        menu.rows[i]:Hide()
    end
    menu:SetHeight(count * 28 + 12)
    menu:Show()
end

function A.CreateUI()
    local p = CreateFrame('Frame', 'TalentGuidePanel', UIParent, 'BackdropTemplate')
    A.panel = p
    p:SetSize(WIDTH, HEIGHT)
    p:SetFrameStrata('DIALOG')
    p:SetClampedToScreen(true)
    p:SetMovable(true)
    p:EnableMouse(true)
    A.SkinPanel(p, true)
    p.title = Text(p, 14, 12, -8, 250)
    p.title:SetTextColor(unpack(A.Theme.gold))
    p.title:SetText("Raynna's Talent Guide")
    local drag = CreateFrame('Frame', nil, p)
    drag:SetPoint('TOPLEFT', 5, -4)
    drag:SetSize(270, 23)
    drag:EnableMouse(true)
    drag:RegisterForDrag('LeftButton')
    drag:SetScript('OnDragStart', function()
        p.dragging = true
        p:StartMoving()
    end)
    drag:SetScript('OnDragStop', function()
        p:StopMovingOrSizing()
        p.dragging = false
        local point, _, relativePoint, x, y = p:GetPoint()
        A.db.position = { point, relativePoint, x, y }
    end)
    Button(p, 'x', 280, -5, 22, function()
        A.dismissed = true
        A.Refresh()
    end)
    Text(p, 11, 14, -36):SetText('Specialization')
    p.choose = Button(p, '', 14, -52, 282, A.ToggleSpecMenu)
    p.specIcon = Icon(p.choose, 6, -3, 16)
    p.arrow = p.choose:CreateTexture(nil, 'OVERLAY')
    p.arrow:SetSize(20, 20)
    p.arrow:SetPoint('RIGHT', -3, 0)
    p.arrow:SetTexture('Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up')
    p.menu = CreateFrame('Frame', nil, p, 'BackdropTemplate')
    p.menu:SetWidth(282)
    p.menu:SetPoint('TOPLEFT', p.choose, 'BOTTOMLEFT', 0, -2)
    p.menu:SetFrameStrata('FULLSCREEN_DIALOG')
    p.menu:EnableMouse(true)
    A.SkinPanel(p.menu, false)
    p.menu.rows = {}
    p.menu:Hide()
    p:SetScript('OnHide', function()
        p.menu:Hide()
        p.sourceBox:Hide()
        GameTooltip:Hide()
    end)
    p.leveling = Button(p, 'Leveling', 14, -80, 138, function()
        A.SelectMode('Leveling')
    end)
    p.pve = Button(p, 'Level 60 / PvE', 158, -80, 138, function()
        A.SelectMode('PvE')
    end)
    p.adapt = Button(p, 'Follow guide', 14, -110, 138, function()
        if A.guide and A.guide.hybrid then
            return
        end
        A.db.adaptive = not A.db.adaptive
        A.page = 0
        A.Refresh()
    end)
    p.bias = Button(p, 'Balanced', 158, -110, 138, function()
        A.db.bias = A.db.bias == 'Balanced' and 'Damage' or A.db.bias == 'Damage' and 'Survival' or 'Balanced'
        A.Refresh()
    end)
    p.status = Text(p, 11, 14, -140)
    p.status:SetHeight(30)
    p.when = Text(p, 11, 14, -178)
    p.when:SetTextColor(unpack(A.Theme.gold))
    p.pick = CreateFrame('Button', nil, p)
    p.pick:SetPoint('TOPLEFT', 14, -198)
    p.pick:SetSize(282, 38)
    p.pick.icon = Icon(p.pick, 0, 0, 36)
    p.next = Text(p.pick, 14, 44, -1, 238)
    p.next:SetHeight(38)
    p.pick:SetScript('OnEnter', TalentTooltip)
    p.pick:SetScript('OnLeave', function()
        GameTooltip:Hide()
    end)
    p.detail = Text(p, 10, 14, -244)
    p.detail:SetHeight(27)
    p.reason = Text(p, 11, 14, -276)
    p.reason:SetHeight(38)
    local line = p:CreateTexture(nil, 'ARTWORK')
    line:SetPoint('TOPLEFT', 14, -321)
    line:SetSize(282, 1)
    line:SetColorTexture(0.63, 0.43, 0.14, 0.7)
    p.listTitle = Text(p, 11, 14, -330, 220)
    p.listTitle:SetTextColor(unpack(A.Theme.gold))
    p.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame('Button', nil, p)
        row:SetPoint('TOPLEFT', 14, -350 - (i - 1) * 22)
        row:SetSize(282, 22)
        row.icon = Icon(row, 0, -1, 18)
        row.text = Text(row, 11, 24, -3, 258)
        row.text:SetWordWrap(false)
        row.text:SetHeight(16)
        row:SetScript('OnEnter', TalentTooltip)
        row:SetScript('OnLeave', function()
            GameTooltip:Hide()
        end)
        p.rows[i] = row
    end
    Button(p, '<', 14, -443, 24, function()
        A.page = math.max(0, (A.page or 0) - 1)
        A.Refresh()
    end)
    Button(p, '>', 42, -443, 24, function()
        local count = A.current and #A.current.pending or 0
        A.page = math.min(math.max(0, math.ceil(count / ROWS) - 1), (A.page or 0) + 1)
        A.Refresh()
    end)
    p.legacy = Button(p, '', 74, -443, 144, function()
        A.db.firstLevel = A.db.firstLevel == 5 and 10 or A.db.firstLevel - 1
        A.Refresh()
    end)
    p.legacy:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
        GameTooltip:SetText('Legacy: Talented')
        GameTooltip:AddLine(
            'Set the first talent level from 10 down to 5. Route labels follow this setting; actual available points come from the game.',
            0.92,
            0.86,
            0.72,
            true
        )
        GameTooltip:Show()
    end)
    p.legacy:SetScript('OnLeave', function()
        GameTooltip:Hide()
    end)
    p.build = Button(p, 'Build', 226, -443, 70, function()
        A.db.showBuild = not A.db.showBuild
        A.Refresh()
    end)
    p.source = Button(p, 'Source', 226, -475, 70, function()
        if not A.guide then
            return
        end
        p.sourceBox:SetText(A.guide.source)
        p.sourceBox:Show()
        p.sourceBox:SetFocus()
        p.sourceBox:HighlightText()
    end)
    p.source:SetScript('OnEnter', function(self)
        if not A.guide then
            return
        end
        GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
        GameTooltip:SetText(A.guide.publisher .. ' | ' .. A.guide.status)
        GameTooltip:AddLine(
            'Checked ' .. A.guide.checked .. '. Click to copy the source URL.',
            0.92,
            0.86,
            0.72,
            true
        )
        if A.guide.outdated then
            GameTooltip:AddLine('The source flags older talent data.', 1, 0.6, 0.2, true)
        end
        GameTooltip:Show()
    end)
    p.source:SetScript('OnLeave', function()
        GameTooltip:Hide()
    end)
    Text(p, 10, 14, -480, 205):SetText('Drag title to move | /tg reset')
    p.sourceBox = CreateFrame('EditBox', nil, p, 'InputBoxTemplate')
    p.sourceBox:SetSize(270, 24)
    p.sourceBox:SetPoint('BOTTOMLEFT', 20, 8)
    p.sourceBox:SetAutoFocus(false)
    p.sourceBox:SetScript('OnEscapePressed', function(self)
        self:ClearFocus()
        self:Hide()
    end)
    p.sourceBox:SetScript('OnEnterPressed', function(self)
        self:ClearFocus()
        self:Hide()
    end)
    p.sourceBox:Hide()
end

function A.Draw(errorText)
    local p, guide, result = A.panel, A.guide, A.current
    p.adapt:SetText(
        guide and guide.hybrid and 'Hybrid: adaptive'
            or A.db.adaptive and 'Adapt to my talents'
            or 'Follow guide'
    )
    if guide and guide.hybrid then
        p.bias:Show()
        p.bias:SetText(A.db.bias or 'Balanced')
    else
        p.bias:Hide()
    end
    p.choose:SetText(guide and guide.spec or 'Select specialization')
    p.specIcon:SetTexture(A.SpecIcon(guide and guide.spec))
    p.leveling:SetText(guide and guide.mode == 'Leveling' and '|cffffd100Leveling|r' or 'Leveling')
    p.pve:SetText(guide and guide.mode == 'PvE' and '|cffffd100Level 60 / PvE|r' or 'Level 60 / PvE')
    p.legacy:SetText('First talent: level ' .. A.db.firstLevel)
    p.build:SetText(A.db.showBuild and 'Build: on' or 'Build: off')
    local issue = errorText or (result and result.error)
    p.pick.step = not issue and result and result.next or nil
    if issue then
        p.status:SetText('|cffffb333Guidance paused|r')
        p.when:SetText('CHECK GUIDE COMPATIBILITY')
        p.next:SetText('No recommendation')
        p.pick.icon:SetTexture(134400)
        p.detail:SetText('')
        p.reason:SetText(issue)
    elseif result then
        local available = A.unspent ~= nil and (' | ' .. A.unspent .. ' unspent') or ''
        local status = ('Level %d | %d/51 points%s'):format(UnitLevel('player'), result.completed, available)
        if result.offBuild > 0 then
            status = status .. ('\n|cffffb333%d point(s) outside this build|r'):format(result.offBuild)
        end
        p.status:SetText(status)
        local nextText = A.NextPickText(result, UnitLevel('player'), A.db.firstLevel, A.unspent)
        p.when:SetText(nextText.heading)
        p.detail:SetText(
            result.adaptive and (result.advice or nextText.detail)
                or (guide.ordered and nextText.detail or 'PvE target build - suggested progression')
        )
        if result.next then
            local step = result.next
            p.pick.icon:SetTexture(SpellIcon(step.name))
            p.next:SetText(
                (result.canBuy and '|cff66ff66' or '|cffffd100')
                    .. step.name
                    .. '|r\nRank '
                    .. step.rank
                    .. '/'
                    .. step.max
            )
            p.reason:SetText(A.Reason(guide, step))
        else
            p.pick.icon:SetTexture(A.SpecIcon(guide.spec))
            p.next:SetText(
                result.exhausted and '|cffff9933No points remaining|r' or '|cff66ff66Build complete|r'
            )
            p.reason:SetText(
                result.exhausted and 'Current talents kept. A respec is needed to reach the exact target.'
                    or 'All recommended ranks are present.'
            )
        end
    end
    local pending = (not issue and result and result.pending) or {}
    A.page = math.min(A.page or 0, math.max(0, math.ceil(#pending / ROWS) - 1))
    p.listTitle:SetText(
        (
            result and result.adaptive and 'Adaptive priorities'
            or guide and guide.ordered and 'Level-by-level route'
            or 'Remaining PvE targets'
        )
            .. '  '
            .. (A.page + 1)
            .. '/'
            .. math.max(1, math.ceil(#pending / ROWS))
    )
    for i, row in ipairs(p.rows) do
        local step = pending[A.page * ROWS + i]
        row.step = step
        if step then
            row.icon:SetTexture(SpellIcon(step.name))
            local prefix = guide.ordered
                    and not result.adaptive
                    and ('Lv ' .. (A.db.firstLevel + step.index - 1))
                or ('#' .. step.index)
            row.text:SetText(prefix .. '  ' .. step.name .. ' ' .. step.rank .. '/' .. step.max)
            row:Show()
        else
            row:Hide()
        end
    end
end
