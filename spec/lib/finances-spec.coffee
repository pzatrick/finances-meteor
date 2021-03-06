root = this

describe "finances", ->
  [s, a1, a2, a3, i1, i2, i3] = (null for i in [1..7])

  beforeEach ->
    root.ScenarioCollection = new Meteor.Collection null
    root.AccountCollection = new Meteor.Collection null
    root.ItemCollection = new Meteor.Collection null
    root.PaymentCollection = new Meteor.Collection null
    root.UsageCollection = new Meteor.Collection null
    s = new finances.Scenario name: 'test' 
    s._id = ScenarioCollection.insert s
    a1 = s.addAccount name: 'Fred'
    a2 = s.addAccount name: 'Dafny'
    a3 = s.addAccount name: 'Shaggy/Scooby'
    i1 = s.addItem name: 'dinner', amount: 60
    i2 = s.addItem name: 'costume', amount: 25
    i3 = s.addItem name: 'snacks', amount: 12

  it 'should be groovy', ->
    expect(finances).toBeDefined()

  it 'should build arithmetic expressions', ->
    addItems = [
      { name: 'fruits' }
      { name: 'veggies' }
      { name: 'exercise' }
    ]
    minusItems = [
      { name: 'smoking' }
      { name: 'fast food' }
      { name: '(di)stress' }
    ]
    exp = finances.buildArithmaticExpression(addItems, minusItems)
    expect(exp).toBe 'fruits+veggies+exercise-smoking-fast food-(di)stress'

  it 'should track users', ->
    a1.uses i1, i1.amount / 2
    a2.uses i1, i1.amount / 2
    s._usages(item: i1._id).forEach (usage) =>
      expect(usage.fromAccount in [a1._id, a2._id]).toBeTruthy()

  it 'should track payments', ->
    a1.pays i1, i1.amount / 2
    a2.pays i1, i1.amount / 2
    expect(s._payment(addItems: i1._id, fromAccount: a1._id)).toBeDefined()
    expect(s._payment(addItems: i1._id, fromAccount: a2._id)).toBeDefined()

  describe 'when settling debts', ->

    it 'should ignore equal and opposite debts', ->
      i2 = i1.clone 'b-fast'
      a1.paysAndUses i1
      a2.paysAndUses i2
      a1.uses i2
      a2.uses i1

      s.addInternalPayments()
      s.simplifyPayments()

      expect(a1.crunch().total).toBe 0
      expect(a2.crunch().total).toBe 0

    it 'should properly handle this scenario', ->
      i1 = s.addItem amount: 5, name: 'i1'
      i2 = s.addItem amount: 4, name: 'i2'
      a1.pays i1
      a2.uses i1
      a2.pays i2
      a1.uses i2

      s.addInternalPayments()
      s.simplifyPayments()

      expect(a1.crunch().total).toBe 0
      expect(a2.crunch().total).toBe 1

    it 'should ignore debts to and from the same Account', ->
      a1.paysAndUses i1

      s.addInternalPayments()
      s.simplifyPayments()

      expect(a1.crunch().total).toBe 0

    it 'should ignore larger cycles of equal debts', ->
      i2 = i1.clone('b-fast')
      i3 = i1.clone('lunch')
      a1.paysAndUses i1, i1.amount / 2
      a2.uses i1, i1.amount / 2
      a2.paysAndUses i2, i2.amount / 2
      a3.uses i2, i2.amount / 2
      a3.paysAndUses i3, i3.amount / 2
      a1.uses i3, i3.amount / 2

      s.addInternalPayments()
      s.simplifyPayments()

      expect(a1.crunch().total).toBe 0
      expect(a2.crunch().total).toBe 0
      expect(a3.crunch().total).toBe 0

    it 'should replace debts along the same path with one direct debt', ->
      i2 = i1.clone('b-fast')

      a1.pays i1
      a1.uses i1, i1.amount / 2
      a2.uses i1, i1.amount / 2
      a2.pays i2
      a2.uses i2, i2.amount / 2
      a3.uses i2, i2.amount / 2

      s.addInternalPayments()
      s.simplifyPayments()

      expect(a3.crunch().total).toBe i2.amount / 2
      expect(a2.crunch().total).toBe 0
      expect(a1.crunch().total).toBe 0

    it 'should handle multiple payers for the same item', ->
      a1.pays i1, i1.amount / 2
      a2.pays i1, i1.amount / 2
      a3.uses i1

      s.addInternalPayments()
      s.simplifyPayments()

      expect(a1.crunch().total).toBe 0
      expect(a2.crunch().total).toBe 0
      expect(a3.crunch().total).toBe 60

    describe 'when all debts are not equal', ->

      describe 'when the first debt in the path is bigger', ->

        it 'should reduce debts along a given path and add a direct debt', ->

          i2 = s.addItem 
            name: 'dessert'
            amount: i1.amount + 5

          a1.pays i1
          a1.uses i1, i1.amount / 2
          a2.uses i1, i1.amount / 2
          a2.pays i2
          a2.uses i2, i2.amount / 2
          a3.uses i2, i2.amount / 2

          s.addInternalPayments()
          s.simplifyPayments()

          expect(a3.crunch().total).toBe i2.amount / 2
          expect(a2.crunch().total).toBe 0
          expect(a1.crunch().total).toBe 0

      describe 'when the second debt in the path is bigger', ->

        it 'should reduce debts along a given path and add a direct debt', ->
          i2 = s.addItem
            name: 'dessert'
            amount: i1.amount + 5

          a1.pays i2
          a1.uses i2, i2.amount / 2
          a2.uses i2, i2.amount / 2
          a2.pays i1
          a2.uses i1, i1.amount / 2
          a3.uses i1, i1.amount / 2

          s.addInternalPayments()
          s.simplifyPayments()

          expect(a3.crunch().total).toBe i1.amount / 2
          expect(a2.crunch().total).toBe i2.amount / 2 - i1.amount / 2
          expect(a1.crunch().total).toBe 0

    describe 'when multiple accounts pay unequal amounts for the same item', ->

      it 'should simplify such that each account pays an equal amount', ->
        a1.pays i1, 42
        a2.pays i1, 18
        a1.uses i1, i1.amount / 3
        a2.uses i1, i1.amount / 3
        a3.uses i1, i1.amount / 3

        s.addInternalPayments()
        s.simplifyPayments()

        expect(a1.balance()).toBe -i1.amount / 3
        expect(a2.balance()).toBe -i1.amount / 3
        expect(a3.balance()).toBe -i1.amount / 3

    describe 'when multiple accounts use unequal amounts of the same item', ->

      it 'should simplify such that each account pays the amount used', ->
        a1.pays i1, i1.amount / 3
        a2.pays i1, i1.amount / 3
        a3.pays i1, i1.amount / 3
        a1.uses i1, 42
        a2.uses i1, 18

        s.addInternalPayments()
        s.simplifyPayments()

        expect(a1.balance()).toBe -42
        expect(a2.balance()).toBe -18
        expect(a3.balance()).toBe 0


  describe 'pseudo-random number generator', ->

    it 'should always generate the same sequence for a given seed', ->
      rng1 = finances.getPRNG(42)
      sequence1 = rng1() for i in [1..20]
      rng2 = finances.getPRNG(42)
      sequence2 = rng2() for i in [1..20]
      for i in [1..20]
        expect(sequence1[i]).toEqual sequence2[i]

  describe 'zero sum arrays', ->

    it 'should sum to zero', ->
      for seed in [1..20]
        zsa = finances.randomZeroSumArray(10, 10, seed)
        sum = 0
        for v in zsa
          sum += v
        expect(sum).toBe 0
  
  describe 'test scenarios', ->
    count = 10
    findSum = (list) ->
      add = (a, b) ->
        a + b
      _.reduce list, add, 0
    sumAmounts = (list) ->
      findSum(o.amount for o in list)
    scenarios = []
    beforeEach ->
      scenarios =
      for seed in [1..20]
        finances.testScenario seed

    it 'should have all items paid for', ->
      for s in scenarios
        for item in s._items().fetch()
          # NOTE: this works as long as there aren't payments for multiple
          #       items yet.
          totalPayment = sumAmounts s._payments(addItems: item._id).fetch()
          if item.amount isnt finances.round totalPayment
            debugger
          expect(item.amount).toBe finances.round totalPayment

    it 'should have all items used', ->
      for s in scenarios
        for item in s._items().fetch()
          # NOTE: this works as long as there aren't payments for multiple
          #       items yet.
          totalPayment = sumAmounts s._usages(item: item._id).fetch()
          if item.amount isnt finances.round totalPayment
            debugger
          expect(item.amount).toBe finances.round totalPayment
           
    xit 'should have every account at least either a payer or a user', ->
      for s in scenarios
        for a in s._accounts().fetch()
          expect(s._usage(fromAccount: a._id) or s._payment(fromAccount: a._id)).toBeDefined()

    it 'should transform such that each account pays for its share of each item it uses', ->
      for s in scenarios
        s.addInternalPayments()
        s.simplifyPayments()
        for account in s._accounts().fetch()
          account = new finances.Account account
          fairShare = 0
          for usage in s._usages(fromAccount: account._id).fetch()
            fairShare += s._item(usage.item).amount / s._usages(item: usage.item).count()
          if finances.round(account.balance()) isnt finances.round -fairShare
            debugger
          expect(finances.round account.balance()).toBe(finances.round -fairShare)

          

