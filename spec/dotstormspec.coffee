models   = require '../assets/js/dotstorm/models'

describe "Dotstorm idea order", ->
  dotstorm = null
  beforeEach ->
    dotstorm = new models.Dotstorm name: "test", slug: "test"

  it "gets id group positions", ->
    ideas = ['1', '2', {ideas: ['3', '4']}, '5', '6', {ideas: ['7', '8']}]
    dotstorm.set(ideas: ideas)
    expect(dotstorm.get "ideas").toEqual(ideas)
    expect(dotstorm.getGroupPos '1').toEqual({list: ideas, pos: 0, parent: undefined, groupPos: undefined})
    expect(dotstorm.getGroupPos '2').toEqual({list: ideas, pos: 1, parent: undefined, groupPos: undefined})
    expect(dotstorm.getGroupPos '3').toEqual({list: ['3', '4'], pos: 0, parent: ideas, groupPos: 2})
    expect(dotstorm.getGroupPos '4').toEqual({list: ['3', '4'], pos: 1, parent: ideas, groupPos: 2})

  it "adds IDs", ->
    dotstorm.addIdea "1"
    expect(dotstorm.get "ideas").toEqual ["1"]

  it "removes IDs", ->
    dotstorm.addIdea "1"
    dotstorm.removeIdea "1"
    expect(dotstorm.get "ideas").toEqual []

  it "groups and ungroups", ->
    ideas = ['1', '2', '3', '4', '5']
    dotstorm.set(ideas: ideas)
    dotstorm.groupify('2', '3')
    expect(dotstorm.get "ideas").toEqual(['1', {ideas: ['2', '3']}, '4', '5'])
    dotstorm.groupify('1', '3')
    expect(dotstorm.get "ideas").toEqual([{ideas: ['2', '1', '3']}, '4', '5'])
    dotstorm.groupify('4', '3', true)
    expect(dotstorm.get "ideas").toEqual([{ideas: ['2', '1', '3', '4']}, '5'])
    
    # ungroup
    dotstorm.ungroup('4')
    expect(dotstorm.get "ideas").toEqual(['4', {ideas: ['2', '1', '3']}, '5'])
    dotstorm.ungroup('2', true)
    expect(dotstorm.get "ideas").toEqual(['4', {ideas: ['1', '3']}, '2', '5'])

  it "puts left and right of", ->
    ideas = ['1', '2', {ideas: ['3', '4']}, '5']
    dotstorm.set(ideas: ideas)
    expect(dotstorm.get "ideas").toEqual(ideas)

    # left/right out of a group.
    dotstorm.putLeftOf('2', '1')
    expect(dotstorm.get "ideas").toEqual(['2', '1', {ideas: ['3', '4']}, '5'])
    dotstorm.putRightOf('2', '1')
    expect(dotstorm.get "ideas").toEqual(['1', '2', {ideas: ['3', '4']}, '5'])

    # move into a group.
    dotstorm.putRightOf('2', '4')
    expect(dotstorm.get "ideas").toEqual(['1', {ideas: ['3', '4', '2']}, '5'])
    dotstorm.putLeftOf('1', '4')
    expect(dotstorm.get "ideas").toEqual([{ideas: ['3', '1', '4', '2']}, '5'])

    # move out of a group
    dotstorm.putRightOf('2', '5')
    expect(dotstorm.get "ideas").toEqual([{ideas: ['3', '1', '4']}, '5', '2'])
    dotstorm.putLeftOf('4', '5')
    expect(dotstorm.get "ideas").toEqual([{ideas: ['3', '1']}, '4', '5', '2'])

    # move out of group destroy group
    dotstorm.putRightOf('1', '4')
    dotstorm.putRightOf('3', '4')
    expect(dotstorm.get "ideas").toEqual(['4', '3', '1', '5', '2'])
    dotstorm.groupify('3', '1')
    dotstorm.putLeftOf('3', '4')
    dotstorm.putLeftOf('1', '4')
    expect(dotstorm.get "ideas").toEqual(['3', '1', '4', '5', '2'])
    dotstorm.groupify('4', '5')
    dotstorm.putLeftOf('4', '1')
    dotstorm.groupify('5', '4')
    expect(dotstorm.get "ideas").toEqual(['3', {ideas: ['5', '4']}, '1', '2'])

    # idempotent out of group
    dotstorm.set("ideas", [{ideas: ['3', '1']}, '4', '5', '2'])
    dotstorm.putRightOf('2', '5')
    expect(dotstorm.get "ideas").toEqual([{ideas: ['3', '1']}, '4', '5', '2'])
    dotstorm.putLeftOf('4', '5')
    expect(dotstorm.get "ideas").toEqual([{ideas: ['3', '1']}, '4', '5', '2'])
    
    # idempotent in group
    dotstorm.putLeftOf('3', '1')
    expect(dotstorm.get "ideas").toEqual([{ideas: ['3', '1']}, '4', '5', '2'])
    dotstorm.putRightOf('1', '3')
    expect(dotstorm.get "ideas").toEqual([{ideas: ['3', '1']}, '4', '5', '2'])

  it "removes empty groups", ->
    dotstorm.set "ideas", ['1', {ideas: ['2', '3']}, '4']
    dotstorm.ungroup('2')
    expect(dotstorm.get "ideas").toEqual(['1', '2', {ideas: ['3']}, '4'])
    dotstorm.ungroup('3')
    expect(dotstorm.get "ideas").toEqual(['1', '2', '3', '4'])

  it "moves groups", ->
    dotstorm.set "ideas", [
      '1', {ideas: ['2', '3']}, {ideas: ['4', '5']}, '6'
    ]
    dotstorm.putGroupLeftOf('2', '1')
    expect(dotstorm.get "ideas").toEqual [
      {ideas: ['2', '3']}, '1', {ideas: ['4', '5']}, '6'
    ]
    dotstorm.putGroupRightOf('3', '6')
    expect(dotstorm.get "ideas").toEqual [
      '1', {ideas: ['4', '5']}, '6', {ideas: ['2', '3']}
    ]
    dotstorm.putGroupLeftOf('2', '5')
    expect(dotstorm.get "ideas").toEqual [
      '1', {ideas: ['4', '2', '3', '5']}, '6'
    ]
    dotstorm.combineGroups('4', '1')
    expect(dotstorm.get "ideas").toEqual [
      {ideas: ['4', '2', '3', '5', '1']}, '6'
    ]
    dotstorm.combineGroups('4', '6', true)
    expect(dotstorm.get "ideas").toEqual [
      {ideas: ['6', '4', '2', '3', '5', '1']}
    ]

    # Combine groups.
    dotstorm.set "ideas", [
      '1', {ideas: ['2', '3']}, {ideas: ['4', '5']}, '6'
    ]
    dotstorm.combineGroups('2', '4')
    expect(dotstorm.get "ideas").toEqual [
      '1', {ideas: ['2', '3', '4', '5']}, '6'
    ]

    # Move a group to a target (left side), groupifying.
    dotstorm.set "ideas", [
      '1', {ideas: ['2', '3']}, {ideas: ['4', '5']}, '6'
    ]
    dotstorm.combineGroups('4', '1')
    expect(dotstorm.get "ideas").toEqual [
      {ideas: ['4', '5', '1']}, {ideas: ['2', '3']}, '6'
    ]

    # Move a group to a target (right side), groupifying.
    dotstorm.set "ideas", [
      '1', {ideas: ['2', '3']}, {ideas: ['4', '5']}, '6'
    ]
    dotstorm.combineGroups('4', '1')
    expect(dotstorm.get "ideas").toEqual [
      {ideas: ['4', '5', '1']}, {ideas: ['2', '3']}, '6'
    ]
 
  it "moves things before and after groups", ->
    dotstorm.set "ideas", [
      '1', {ideas: ['2', '3']}, {ideas: ['4', '5']}, '6'
    ]
    dotstorm.putGroupLeftOfGroup('4', '2')
    expect(dotstorm.get "ideas").toEqual [
      '1', {ideas: ['4', '5']}, {ideas: ['2', '3']}, '6'
    ]
    dotstorm.putGroupRightOfGroup('4', '2')
    expect(dotstorm.get "ideas").toEqual [
      '1', {ideas: ['2', '3']}, {ideas: ['4', '5']}, '6'
    ]

    dotstorm.putLeftOfGroup('6', '4')
    expect(dotstorm.get "ideas").toEqual [
      '1', {ideas: ['2', '3']}, '6', {ideas: ['4', '5']}
    ]

    dotstorm.putRightOfGroup('1', '4')
    expect(dotstorm.get "ideas").toEqual [
      {ideas: ['2', '3']}, '6', {ideas: ['4', '5']}, '1'
    ]


