models   = require '../assets/js/models'

describe "Dotstorm idea order", ->
  dotstorm = null
  beforeEach ->
    dotstorm = new models.Dotstorm name: "test", slug: "test"

  it "gets id group positions", ->
    ideas = ['1', '2', {ideas: ['3', '4']}, '5', '6', {ideas: ['7', '8']}]
    dotstorm.set(ideas: ideas)
    expect(dotstorm.get "ideas").toEqual(ideas)
    expect(dotstorm.getGroupPos '1').toEqual({list: ideas, pos: 0, group: undefined})
    expect(dotstorm.getGroupPos '2').toEqual({list: ideas, pos: 1, group: undefined})
    expect(dotstorm.getGroupPos '3').toEqual({list: ['3', '4'], pos: 0, group: ideas})
    expect(dotstorm.getGroupPos '4').toEqual({list: ['3', '4'], pos: 1, group: ideas})

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
