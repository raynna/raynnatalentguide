"""Offline Lua 5.1 checks for Localization.lua. Run: python tests/test_localization.py"""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('A = {}')


def load(name):
    lua.execute(
        'assert(loadstring(...))("TalentGuide", A)',
        (ROOT / 'TalentGuide' / name).read_text(encoding='utf8'),
    )


# A client in another language: spell names come back translated.
lua.execute(r'''
local class = 'DRUID'
function UnitClass() return 'Druid', class end
function SetTestClass(token) class = token end
''')

load('Guides.lua')
load('Localization.lua')

lua.execute(r'''
local classes = 0
for _, trees in pairs(A.talentPositions) do
    classes = classes + 1
    assert(#trees == 3, 'three trees per class')
    for _, tree in pairs(trees) do
        for _, row in pairs(tree) do
            for _, talent in pairs(row) do
                assert(type(talent.en) == 'string' and talent.en ~= '')
                assert(type(talent.max) == 'number' and talent.max > 0)
            end
        end
    end
end
assert(classes == 9, 'nine classes')
assert(A.CanLocalize(), 'the player class has a table')
SetTestClass('DEMONHUNTER')
assert(not A.CanLocalize(), 'an unknown class has none')
SetTestClass('DRUID')
''')

# Positions are derived from the canvas coordinates, so a tree with an empty
# column must not shift the talents that follow it.
lua.execute(r'''
local nodes = {
    [1] = {posX = 100, posY = 100, groupIDs = {7}, maxRanks = 5},
    [2] = {posX = 300, posY = 100, groupIDs = {7}, maxRanks = 5},
    [3] = {posX = 200, posY = 200, groupIDs = {7}, maxRanks = 3},
}
C_Traits = {
    GetGroupDisplayInfoByTreeID = function() return {{groupID = 7, displayName = 'Balance'}} end,
    GetTreeNodes = function() return {1, 2, 3} end,
    GetNodeInfo = function(_, id) return nodes[id] end,
}
local positions = A.BuildNodePositions(1, {treeIDs = {1}})
assert(positions[1].row == 1 and positions[1].column == 1)
assert(positions[2].row == 1 and positions[2].column == 3, 'the empty column is kept')
assert(positions[3].row == 2 and positions[3].column == 2)

-- Druid, Balance, row 1: Improved Wrath (col 2) and Genesis (col 3).
assert(A.EnglishTalentName({tree = 1, row = 1, column = 2}, 5) == 'Improved Wrath')
assert(A.EnglishTalentName({tree = 1, row = 1, column = 3}, 5) == 'Genesis')
assert(A.EnglishTalentName({tree = 1, row = 1, column = 1}, 5) == nil, 'no talent there')
assert(A.EnglishTalentName({tree = 1, row = 1, column = 2}, 4) == nil, 'stale max rank is refused')
assert(A.EnglishTalentName(nil, 5) == nil)
''')

# Every talent a route asks for should exist in the table, so a non-English
# client reaches the same nodes. These eleven are known gaps in the tree data.
KNOWN_GAPS = {
    'ROGUE': {'Blood Splatter', 'Boot Knife', 'Composure', 'Coup de Grace',
              'Death Mark', 'Efficient Strikes', 'Flash of Steel'},
    'SHAMAN': {'Call of Thunder', 'Lightning Mastery'},
    'WARRIOR': {'Improved Whirlwind', 'Reckless Swings'},
}

names = {}
for class_token, trees in lua.eval('A.talentPositions').items():
    found = set()
    for tree in trees.values():
        for row in tree.values():
            for talent in row.values():
                found.add(talent['en'])
    names[class_token] = found

missing, checked = {}, 0
for guide in lua.eval('A.guides').values():
    token = guide['classToken']
    for chunk in guide['chunks'].values():
        checked += 1
        name = chunk['name']
        if name not in names.get(token, set()) and name not in KNOWN_GAPS.get(token, set()):
            missing.setdefault(token, set()).add(name)

assert not missing, 'talents missing from the position table: %r' % missing
assert checked > 1000, 'every route was checked'
print('ok: %d talents, %d route references' % (
    sum(len(found) for found in names.values()), checked))
