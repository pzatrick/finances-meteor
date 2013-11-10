describe "finances", ->
  [a1, a2, a3, i1, i2, i3] = (null for i in [1..6])
  Account = finances.Account
  Item = finances.Item

  beforeEach ->
    finances.reset()
    a1 = new Account name: 'Fred'
    a2 = new Account name: 'Dafny'
    a3 = new Account name: 'Shaggy/Scooby'
    i1 = new Item name: 'dinner', amount: 60
    i2 = new Item name: 'costume', amount: 25
    i3 = new Item name: 'snacks', amount: 12

  it 'should be groovy', ->
    expect(finances).toBeDefined()

  it 'should track users', ->
    a1.uses i1
    a2.uses i1
    expect(a1 in finances.getUsers(i1)).toBe true
    expect(a2 in finances.getUsers(i1)).toBe true

  it 'should track payments', ->
    a1.pays i1, 50
    a2.pays i1, 50
    accounts = (p.fromAccount for p in finances.getPaymentsForItem(i1))
    expect(a1 in accounts)
    expect(a2 in accounts)

  describe 'when settling debts', ->

    it 'should ignore equal and opposite debts', ->
      i2 = i1.clone('b-fast')
      a1.paysAndUses i1
      a2.paysAndUses i2
      a1.uses i2
      a2.uses i1

      finances.createInternalPayments()
      finances.simplifyPayments()

      expect(a1.owes().total).toBe 0
      expect(a2.owes().total).toBe 0

    it 'should ignore debts to and from the same Account', ->
      a1.paysAndUses i1

      finances.createInternalPayments()
      finances.simplifyPayments()

      expect(a1.owes().total).toBe 0

    it 'should ignore larger cycles of equal debts', ->
      i2 = i1.clone('b-fast')
      i3 = i1.clone('lunch')
      a1.paysAndUses i1
      a2.uses i1
      a2.paysAndUses i2
      a3.uses i2
      a3.paysAndUses i3
      a1.uses i3

      finances.createInternalPayments()
      finances.simplifyPayments()

      expect(a1.owes().total).toBe 0
      expect(a2.owes().total).toBe 0
      expect(a3.owes().total).toBe 0

    it 'should replace debts along the same path with one direct debt', ->
      i2 = i1.clone('b-fast')

      a1.paysAndUses i1
      a2.uses i1
      a2.paysAndUses i2
      a3.uses i2

      finances.createInternalPayments()
      finances.simplifyPayments()

      expect(a3.owes().total).toBe i2.amount / 2
      expect(a2.owes().total).toBe 0
      expect(a1.owes().total).toBe 0

    describe 'when all debts are not equal', ->

      describe 'when the first debt in the path is bigger', ->

        it 'should reduce debts along a given path and create a direct debt', ->

          i2 = new Item name: 'dessert', amount: i1.amount + 5

          a1.paysAndUses i1
          a2.uses i1
          a2.paysAndUses i2
          a3.uses i2

          finances.createInternalPayments()
          finances.simplifyPayments()

          expect(a3.owes().total).toBe i2.amount / 2
          expect(a2.owes().total).toBe 0
          expect(a1.owes().total).toBe 0

      describe 'when the second debt in the path is bigger', ->

        it 'should reduce debts along a given path and create a direct debt', ->
          i2 = new finances.Item name: 'dessert', amount: i1.amount + 5

          a1.paysAndUses i2
          a2.uses i2
          a2.paysAndUses i1
          a3.uses i1

          finances.createInternalPayments()
          finances.simplifyPayments()

          expect(a3.owes().total).toBe i1.amount / 2
          expect(a2.owes().total).toBe i2.amount / 2 - i1.amount / 2
          expect(a1.owes().total).toBe 0

  describe 'pseudo-random number generator', ->

    it 'should always generate the same sequence for a given seed', ->
      rng1 = finances.getPRNG(42)
      sequence1 = rng1() for i in [1..20]
      rng2 = finances.getPRNG(42)
      sequence2 = rng2() for i in [1..20]
      for i in [1..20]
        expect(sequence1[i]).toEqual sequence2[i]
  
  describe 'test scenarios', ->
    # TODO: make a scenario class and move all the methods and
    #       properties of `finances` to `finances.Scenario`
    count = 10
    findSum = (list) ->
      add = (a, b) ->
        a + b
      _.reduce list, add, 0
    withEachScenario = (fn) =>
      for i in [1..count]
        finances.reset()
        s = finances.testScenario(i)
        fn(s)

    it 'should have payments', ->
      withEachScenario (s) ->
        expect(s.totalPayments).toBeGreaterThan 0

    it 'should have all items paid for', ->
      withEachScenario (s) ->
        expect(s.totalPayments).toBe findSum (i.amount for i in s.items)
        expect(finances.payments.length >= s.items.length).toBeTruthy()
        for i in s.items
          expect(findSum(
            p.amount for p in finances.getPaymentsForItem(i)
          )).toBe i.amount
        
    it 'should have every account at least either a payer or a user', ->
      withEachScenario (s) ->
        for a in s.accounts
          expect(a.usesItems.length or a.sendsPayments.length).toBeTruthy()

    it """should transform to one in which the net amount
          that each account pays is equal""", ->
      withEachScenario (s) ->
        finances.createInternalPayments()
        finances.simplifyPayments()
        fairShare = s.totalPayments / s.accounts.length
        for a in s.accounts.length
          share = findSum (p.amount for p in a.sendsPayments) -
            findSum (p.amount for p in a.receivesPayments)

          expect(share).toEqual fairShare
