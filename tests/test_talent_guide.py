"""Offline Lua 5.1 checks. Run: python tests/test_talent_guide.py"""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('A = {}')
def load(name):
    lua.execute('assert(loadstring(...))("TalentGuide", A)', (ROOT / 'TalentGuide' / name).read_text(encoding='utf8'))
load('Guides.lua')
load('Engine.lua')
lua.execute(r'''
assert(#A.guides == 55)
local specs, levelingSpecs = {}, {}
for _, guide in ipairs(A.guides) do
    local steps, targets = A.Expand(guide)
    assert(#steps == 51, guide.spec)
    local nodes = {}
    for _, step in ipairs(steps) do
        nodes[step.name] = {rank=0, max=step.max, canBuy=true, y=0, group=guide.spec}
    end
    local initial = A.Evaluate(guide, nodes)
    assert(not initial.error and initial.completed == 0 and #initial.pending == 51)
    assert(initial.next.rank == 1 and initial.canBuy)
    if guide.ordered then
        levelingSpecs[guide.classToken..guide.spec] = true
        for _, step in ipairs(steps) do
            local progress = A.Evaluate(guide, nodes)
            assert(progress.next.name == step.name and progress.next.rank == step.rank, 'every level advances exactly one rank')
            nodes[step.name].rank = step.rank
        end
    end
    for name, rank in pairs(targets) do nodes[name].rank = rank end
    local done = A.Evaluate(guide, nodes)
    assert(done.completed == 51 and not done.next and #done.pending == 0 and not done.exhausted)
    if guide.mode == 'PvE' then specs[guide.classToken..guide.spec] = true end
end
local n=0; for _ in pairs(specs) do n=n+1 end; assert(n == 27)
local levels=0; for _ in pairs(levelingSpecs) do levels=levels+1 end; assert(levels == 27)
local guide = {ordered=true,spec='Main',chunks={{name='First',rank=2,max=2},{name='Later',rank=1,max=1}}}
local nodes = {First={rank=0,max=2,canBuy=false,y=0,group='Main'},Later={rank=0,max=1,canBuy=true,y=1,group='Main'}}
local result = A.Evaluate(guide,nodes)
assert(result.next.name == 'First' and not result.canBuy, 'strict route must not skip a blocked prerequisite')
nodes.First.rank = 1
assert(A.Evaluate(guide,nodes).next.rank == 2, 'partial ranks')
nodes.Other = {rank=3,max=5,y=0}
assert(A.Evaluate(guide,nodes).offBuild == 3, 'deviations')
nodes.First.max=3; assert(A.Evaluate(guide,nodes).error, 'changed max rank fails closed'); nodes.First.max=2
nodes.First.ambiguous=true; assert(A.Evaluate(guide,nodes).error, 'ambiguous name fails closed'); nodes.First.ambiguous=nil
nodes.First=nil; assert(A.Evaluate(guide,nodes).error, 'missing talent fails closed')
nodes.First={rank=0,max=2,canBuy=false,y=0,group='Main'}
guide.ordered=false
assert(A.Evaluate(guide,nodes).next.name == 'Later', 'PvE picks legal target')
nodes.First.canBuy=true; nodes.First.group='Secondary'
assert(A.Evaluate(guide,nodes).next.name == 'Later', 'PvE prefers selected tree')
local nextResult = {next={index=11},completed=23,offBuild=1,canBuy=false}
assert(A.NextPickText(nextResult,33,10,0).heading == 'NEXT POINT - LEVEL 34')
assert(A.NextPickText(nextResult,33,10,0).detail:find('catch%-up'), 'old milestone clearly labeled')
assert(A.NextPickText(nextResult,5,10,0).heading == 'NEXT POINT - LEVEL 10', 'before first talent level')
assert(A.NextPickText(nextResult,33,5,2).badge == 'NEXT - LOCKED', 'points exist but prerequisites fail')
nextResult.canBuy=true; assert(A.NextPickText(nextResult,33,10,2).badge == 'NEXT - PICK NOW')
nextResult.canBuy=false; nextResult.completed=50; nextResult.offBuild=1
assert(A.NextPickText(nextResult,55,5,0).badge == 'NEXT - RESPEC', 'Legacy cap does not promise another point')
local hybrid=A.guides[#A.guides]
assert(hybrid.hybrid and hybrid.spec=='Feral Cat / Bear')
local hn={}
for _,s in ipairs(A.Expand(hybrid)) do hn[s.name]={rank=0,max=s.max,canBuy=true,y=0,group='Feral Combat'} end
local tank=A.Evaluate(hybrid,hn,{bias='Survival'})
local cat=A.Evaluate(hybrid,hn,{bias='Damage'})
assert(tank.next.name=='Thick Hide' and cat.next.name=='Savage Fury','hybrid role preference changes priority')
hn['Thick Hide'].canBuy=false
assert(A.Evaluate(hybrid,hn,{bias='Survival'}).next.name~='Thick Hide','bias never overrides client eligibility')
hn.Extra={rank=49,max=49,canBuy=false,y=0}
local budget=A.Evaluate(hybrid,hn,{adaptive=true})
assert(budget.remainingBudget==2 and #budget.pending==2 and budget.omitted==49 and budget.respecNeeded)
assert(hn.Extra.rank==49 and hn.Ferocity.rank==0,'adaptive evaluation preserves purchased ranks')
hn.Extra.rank=51
local exhausted=A.Evaluate(hybrid,hn,{adaptive=true})
assert(exhausted.exhausted and not exhausted.next and not exhausted.canBuy and #exhausted.pending==0)
local adaptive=A.Evaluate(guide,nodes,{adaptive=true})
assert(adaptive.adaptive and adaptive.next.name=='First','adaptive route order retained among legal choices')
nodes.First.canBuy=false
adaptive=A.Evaluate(guide,nodes,{adaptive=true})
assert(adaptive.next.name=='Later' and adaptive.tradeoff:find('First'), 'blocked earlier pick and its delay are explained')
''')

lua.execute(r'''
Frames = {}
local methods = {}
function methods:SetScript(event, callback) self[event] = callback end
function methods:HookScript(event, callback) self['hook'..event] = callback end
function methods:SetText(value) self.text = value end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and not PARENT_HIDDEN end
function methods:GetFrameLevel() return 1 end
function methods:GetPoint() return 'RIGHT', UIParent, 'RIGHT', -24, 0 end
function methods:GetWidth() return 1500 end
function methods:GetHeight() return 900 end
function methods:GetRight() return RIGHT or 1170 end
function methods:GetEffectiveScale() return 1 end
function methods:SetPoint(...) self.anchor={...} end
function methods:SetTexture(t) self.texture=t end
function methods:SetAlpha(a) self.alpha=a end
for _, name in ipairs({'RegisterEvent','SetWidth','SetHeight','SetSize','SetFont','SetJustifyH','SetJustifyV','SetTextColor','SetFrameStrata','SetFrameLevel','SetClampedToScreen','SetMovable','EnableMouse','RegisterForDrag','StartMoving','StopMovingOrSizing','SetBackdrop','SetBackdropColor','SetBackdropBorderColor','SetAutoFocus','ClearFocus','SetFocus','HighlightText','ClearAllPoints','SetWordWrap','SetScale','SetTexCoord','SetAllPoints','SetVertexColor','SetColorTexture','SetChecked','SetMaxLetters'}) do methods[name]=function() end end
function methods:SetFrameLevel(level) self.frameLevel=level end
function methods:SetWordWrap(enabled) self.wordWrap=enabled end
function CreateFrame(kind,name,parent)
    local frame=setmetatable({shown=true}, {__index=methods})
    Frames[#Frames+1]=frame
    if name then _G[name]=frame end
    return frame
end
function methods:CreateFontString() return CreateFrame() end
function methods:CreateTexture() return CreateFrame() end
UIParent=CreateFrame(); STANDARD_TEXT_FONT='font'; SlashCmdList={}
LOCALE='enUS'; function GetLocale() return LOCALE end
function UnitClass() return 'Hunter','HUNTER' end
function UnitLevel() return 20 end
function InCombatLockdown() return COMBAT end
GameTooltip={AddLine=function() end,Show=function() end,Hide=function() end,SetOwner=function() end,SetSpellByID=function() end,SetText=function() end}
local frame=CreateFrame()
function frame:IsInspecting() return INSPECT end
function frame:IsLocked() return LOCKED end
function frame:GetConfigID() return CONFIG or 123 end
function frame:GetTalentButtonByNodeID(id) return BUTTONS[id] end
PlayerSpellsFrame={TalentsFrame=frame}
BUTTONS={}; NODE={}; ENTRY={}; DEF={}; IDS={}; NAMES={}
local guide = A.Profiles('HUNTER')[1]
local steps=A.Expand(guide)
local seen={}
for _, step in ipairs(steps) do
    if not seen[step.name] then
        local id=#IDS+1; seen[step.name]=true; IDS[id]=id
        NODE[id]={entryIDs={id},activeEntry={entryID=id},ranksPurchased=0,maxRanks=step.max,posY=id,groupIDs={1},isVisible=true,isAvailable=true}
        ENTRY[id]={definitionID=id}; DEF[id]={spellID=id}; NAMES[id]=step.name
        BUTTONS[id]=CreateFrame(); BUTTONS[id].GetNodeID=function() return id end
        BUTTONS[id].CanPurchaseRank=function() return not NOPOINTS end
    end
end
C_Traits={
    GetTreeCurrencyInfo=function() return {{traitCurrencyID=1,quantity=NOPOINTS and 0 or 1}} end,
    GetConfigInfo=function() return {treeIDs={1}} end,
    GetTreeNodes=function() return IDS end,
    GetGroupDisplayInfoByTreeID=function() return {{groupID=1,displayName='Beast Mastery'}} end,
    GetNodeInfo=function(_,id) return NODE[id] end,
    GetEntryInfo=function(_,id) return ENTRY[id] end,
    GetDefinitionInfo=function(id) return DEF[id] end,
    CanPurchaseRank=function() return not NOPOINTS end,
}
C_ClassTalents={}
C_Spell={GetSpellName=function(id) return NAMES[id] end,GetSpellTexture=function(id) return id end}
''')
load('Client.lua')
load('SettingsRegistry.lua')
load('Theme.lua')
load('UI.lua')
load('Settings.lua')
lua.execute(r'''
TalentGuideDB={enabled=false,selections={['123']=1},firstLevel=10}
A.events.OnEvent(nil,'ADDON_LOADED','TalentGuide')
assert(A.db.enabled and A.db.visibilityVersion==1, 'legacy close-button disable recovered')
A.Refresh()
assert(A.panel:IsShown() and A.current.next.name == 'Deadly Aspects')
assert(A.current.canBuy and A.current.completed == 0)
assert(A.overlays[BUTTONS[1]]:IsShown(), 'overlay created')
assert(not A.overlays[BUTTONS[2]]:IsShown(), 'only the next talent highlighted by default')
assert(A.overlays[BUTTONS[1]].label.text == 'NEXT PICK')
assert(A.overlays[BUTTONS[1]].badge.anchor[1]=='BOTTOM' and A.overlays[BUTTONS[1]].badge.anchor[3]=='TOP', 'next badge above its own icon')
local gold=A.overlays[BUTTONS[1]]
assert(gold.arrows:IsShown() and gold.leftArrow.text=='>' and gold.rightArrow.text=='<', 'next pick has unique inward pointers')
assert(gold.badge.anchor[2]==BUTTONS[1], 'badge belongs to its own native talent button')
assert(gold.badge.frameLevel>gold.frameLevel and gold.label.wordWrap==false, 'badge stays above icon layers without wrapping')
gold.OnUpdate(gold,0.2); assert(gold.glow.alpha<1 and gold.glow:IsShown(),'gold frame pulses')
A.db.animate=false;A.Refresh();assert(not gold.OnUpdate,'animation toggle removes update work');A.db.animate=true
NODE[1].ranksPurchased=5;A.Refresh();assert(gold.label.text=='Good' and not gold.OnUpdate,'purchased target is Good, no pulse')
assert(not gold.arrows:IsShown(), 'pointers disappear when talent is no longer next')
assert(gold.badge.anchor[1]=='BOTTOM' and gold.badge.anchor[3]=='TOP', 'Good stays above, never below')
NODE[1].ranksPurchased=0
local badID=100
IDS[#IDS+1]=badID;NODE[badID]={entryIDs={badID},activeEntry={entryID=badID},ranksPurchased=1,maxRanks=5,posY=0,groupIDs={1},isVisible=true,isAvailable=true}
ENTRY[badID]={definitionID=badID};DEF[badID]={spellID=badID};NAMES[badID]='Off-build test talent'
BUTTONS[badID]=CreateFrame();BUTTONS[badID].GetNodeID=function()return badID end;BUTTONS[badID].CanPurchaseRank=function()return true end
A.Refresh();assert(A.overlays[BUTTONS[badID]].label.text=='Not recommended','off-build purchase marked red')
NODE[badID].ranksPurchased=0;A.Refresh();assert(not A.overlays[BUTTONS[badID]]:IsShown(),'unselected off-build talent is not criticized')
assert(A.panel.anchor[1]=='TOPLEFT' and A.panel.anchor[3]=='TOPRIGHT', 'dock beside tree when room')
RIGHT=1450; A.PositionPanel(); assert(A.panel.anchor[1]=='TOPRIGHT' and A.panel.anchor[3]=='TOPRIGHT', 'fit inside tree on narrow screen'); RIGHT=nil
A.ToggleSpecMenu(); assert(A.panel.menu:IsShown() and #A.panel.menu.rows==3, 'all leveling specs in actual dropdown')
local chosen=A.panel.menu.rows[2].profileIndex
A.panel.menu.rows[2].OnClick(A.panel.menu.rows[2])
assert(A.selection==chosen and A.guide.mode=='Leveling' and not A.panel.menu:IsShown(), 'dropdown selects another leveling spec')
A.SelectMode('PvE'); assert(A.guide.mode=='PvE')
A.SelectMode('Leveling'); assert(A.guide.mode=='Leveling')
A.Select(1)
NODE[1].ranksPurchased=1; NODE[1].activeRank=5 -- gear-granted ranks do not count as purchased
A.Refresh(); assert(A.current.next.rank == 2)
NOPOINTS=true; A.Refresh(); assert(not A.current.canBuy and A.unspent==0)
assert(A.panel.when.text == 'NEXT POINT - LEVEL 21')
NOPOINTS=false
INSPECT=true; A.Refresh(); assert(not A.current and not A.overlays[BUTTONS[1]]:IsShown())
INSPECT=false; LOCKED=true; A.Refresh(); assert(not A.current)
LOCKED=false; LOCALE='deDE'; A.Refresh(); assert(not A.current)
LOCALE='enUS'; COMBAT=true; A.Refresh(); assert(not A.panel:IsShown())
COMBAT=false; A.Refresh(); assert(A.panel:IsShown())
A.Select(2); local selectedKey=A.ProfileKey(A.guide); assert(A.db.selections['123']==selectedKey)
CONFIG=124; A.Refresh(); assert(A.selection==1, 'separate dual spec preference')
CONFIG=123; A.Refresh(); assert(A.selection==2)
A.db.selections['123']=2; A.Refresh(); assert(A.guide.mode=='PvE' and A.guide.spec=='Beast Mastery', 'migrate old saved indices')
A.Select(1)
local talentFrame=PlayerSpellsFrame.TalentsFrame
A.ToggleSpecMenu(); talentFrame:Hide(); talentFrame.hookOnHide()
assert(not A.panel:IsShown() and not A.panel.menu:IsShown() and not A.current, 'immediate hide with talent UI')
talentFrame:Show(); PARENT_HIDDEN=true; A.Refresh()
assert(not A.panel:IsShown(), 'hidden parent must not resurrect guide when talent child IsShown is true')
PARENT_HIDDEN=false
talentFrame:Show(); talentFrame.hookOnShow()
assert(A.panel:IsShown() and A.current, 'immediate reopen with talent UI')
A.dismissed=true; A.Refresh(); assert(not A.panel:IsShown())
talentFrame.hookOnShow(); assert(A.panel:IsShown(), 'close applies only until next opening')
SlashCmdList.TALENTGUIDE('off'); assert(not A.panel:IsShown())
A.events.OnEvent(nil,'ADDON_LOADED','TalentGuide')
assert(not A.db.enabled and A.db.explicitOff, 'explicit off survives reload migration')
SlashCmdList.TALENTGUIDE('reset'); assert(A.db.enabled and not A.db.explicitOff and A.panel:IsShown(), 'reset recovers hidden guide')
A.db.enabled=true; PlayerSpellsFrame.TalentsFrame:Hide(); A.Refresh(); assert(not A.panel:IsShown())
PlayerSpellsFrame.TalentsFrame:Show(); A.Select(1)
local missing = DEF[1]; DEF[1]=nil; A.Refresh()
assert(A.current.error and not A.overlays[BUTTONS[1]]:IsShown(), 'stale guide cannot highlight')
DEF[1]=missing
RaynnaTalentGuide.SetEnabled(false); assert(not A.panel:IsShown() and A.db.explicitOff)
RaynnaTalentGuide.SetEnabled(true); assert(A.panel:IsShown() and not A.db.explicitOff)
assert(RaynnaTalentGuide.IsEnabled())
RaynnaTalentGuide.Reset(); assert(A.db.position == nil and A.panel:IsShown())
RaynnaTrackerDB={appearance={paper=false,opacity=0.6}}
RaynnaTalentGuide.ApplyAppearance()
''')
print('PASS: 55 profiles; adaptive budgets, hybrid priorities, gold pulse, Good/Not recommended ratings; all 27 leveling routes, dropdown/mode selection, next-level labels, layout, immediate visibility, migration and API checks.')
