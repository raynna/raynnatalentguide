local _, A = ...

function A.BuildSettings()
    local registry = RaynnaModsSettingsRegistry
    if not A.db.appearance then
        A.db.appearance = registry:AppearanceDefaults()
    end
    registry:RegisterAppearance('talentguide', function()
        return A.db.appearance
    end, function(key, value)
        A.db.appearance[key] = value
        A.ApplyAppearance()
    end)
    registry:Register('talentguide', 'Talent Guide', function(panel)
        local refreshers = {}
        local function text(value, x, y)
            local label = panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
            label:SetPoint('TOPLEFT', x, y)
            label:SetText(value)
        end
        local function check(label, y, get, set)
            local control = CreateFrame('CheckButton', nil, panel, 'UICheckButtonTemplate')
            control:SetPoint('TOPLEFT', 24, y)
            control:SetSize(26, 26)
            text(label, 54, y - 6)
            control:SetScript('OnClick', function(self)
                set(not not self:GetChecked())
                A.Refresh()
            end)
            refreshers[#refreshers + 1] = function()
                control:SetChecked(get())
            end
        end
        local function button(label, x, y, width, callback)
            local b = CreateFrame('Button', nil, panel, 'UIPanelButtonTemplate')
            b:SetPoint('TOPLEFT', x, y)
            b:SetSize(width, 24)
            b:SetText(label)
            b:SetScript('OnClick', callback)
            return b
        end
        local function percent(label, y, get, set, minimum, maximum)
            text(label, 24, y - 5)
            local input = CreateFrame('EditBox', nil, panel, 'InputBoxTemplate')
            input:SetPoint('TOPLEFT', 240, y)
            input:SetSize(65, 24)
            input:SetAutoFocus(false)
            input:SetMaxLetters(5)
            local function refresh()
                input:SetText(math.floor(get() * 100 + 0.5) .. '%')
            end
            local function apply(value)
                if value then
                    set(math.max(minimum, math.min(maximum, value)) / 100)
                    A.Refresh()
                end
                refresh()
            end
            input:SetScript('OnEnterPressed', function(self)
                apply(tonumber((self:GetText() or ''):match('^%s*(%d+)%s*%%?%s*$')))
                self:ClearFocus()
            end)
            input:SetScript('OnEscapePressed', function(self)
                refresh()
                self:ClearFocus()
            end)
            input:SetScript('OnEditFocusLost', refresh)
            button('-', 210, y, 24, function()
                apply(get() * 100 - 5)
            end)
            button('+', 312, y, 24, function()
                apply(get() * 100 + 5)
            end)
            refreshers[#refreshers + 1] = refresh
        end
        text("Raynna's Talent Guide", 24, -20)
        text('Changes apply immediately; saved for this character.', 24, -48)
        check('Show with talent window', -78, function()
            return A.db.enabled
        end, RaynnaTalentGuide.SetEnabled)
        check('Adapt to existing talents (suggested priorities)', -108, function()
            return A.db.adaptive
        end, function(v)
            A.db.adaptive = v
        end)
        check('Animated golden next-pick frame', -138, function()
            return A.db.animate ~= false
        end, function(v)
            A.db.animate = v
        end)
        check('Good / Not recommended borders on purchased talents', -168, function()
            return A.db.showRatings ~= false
        end, function(v)
            A.db.showRatings = v
        end)
        check('Show all remaining build talents', -198, function()
            return A.db.showBuild
        end, function(v)
            A.db.showBuild = v
        end)
        percent('Guide scale', -240, function()
            return A.db.scale or 1
        end, function(v)
            A.SetScale(v)
        end, 40, 180)
        button('Open guide', 24, -280, 145, RaynnaTalentGuide.Open)
        button('Center and show', 190, -280, 145, function()
            A.db.position = { 'CENTER', 'CENTER', 0, 0 }
            RaynnaTalentGuide.Open()
        end)
        text('Appearance - all installed Raynna addons', 24, -330)
        check('Parchment background', -356, function()
            return A.db.appearance.paper ~= false
        end, function(v)
            registry:SetAppearance('paper', v)
        end)
        percent('Background opacity', -400, function()
            return A.db.appearance.opacity or 0.97
        end, function(v)
            registry:SetAppearance('opacity', v)
        end, 20, 100)
        text('/tg opens talents | /tg settings opens this page', 24, -448)
        return function()
            for _, refresh in ipairs(refreshers) do
                refresh()
            end
        end
    end)
end
