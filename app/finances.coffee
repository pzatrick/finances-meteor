
#
# dinner:
#   sugardaddy: Fred
#   moochers: Dafny Shaggy Scooby
# hotel:
#   sugermomma: Thelma
#   moochers: Fred Shaggy Scooby

if not _?
  _ = Package?.underscore._

class Item
  constructor: (@name, @amount) ->
    finances.items[@name] = this
  clone: (name = @name) ->
    new Item(name, @amount)

class Account
  constructor: (@name) ->
    @usesItems = []
    @sendsPayments = []
    @receivesPayments = []
  pays: (item, percent = 100) ->
    new Payment
      item: item
      percent: percent
      fromAccount: this
  uses: (item) ->
    finances.getUsers(item).push this
    @usesItems.push item
  paysAndUses: (item, percent = 100) ->
    @pays(item, percent)
    @uses(item)
  owes: ->
    total = 0
    for p in @sendsPayments when not p.settled
      console.debug "include in total #{p.toString()}"
      total += p.amount
    total: total

class Payment
  constructor: (@options) ->
    finances.payments.push this
    @item = @options.item
    @percent = @options.percent or 100
    if @item?
      finances.getPaymentsForItem(@item).push this

    @amount =
    if @item?
      @item.amount *
      if @percent
        100/@percent
      else
        1/@getUsers(@item).length
    else
      @options.amount or 0
      
    @settled = if @options.settled? then @options.settled else true
    @fromAccount = @options.fromAccount
    @fromAccount?.sendsPayments.push this
    @toAccount = @options.toAccount
    @toAccount?.receivesPayments.push this
    console.debug "create #{@toString()}"

  # amount: ->
  #   @amount * (@percent/100)
  isInternal: ->
    @fromAccount? and @toAccount?
  toString: ->
    """#{
    if @settled
      ''
    else
      'unsettled '
    }payment from #{
      @fromAccount.name
    } to #{
      @toAccount?.name
    } for #{
      @item?.name
    } ($#{
      @amount
    })"""

@finances ?=
  getPaymentsForItem: (item) ->
    @paymentsForItem[item.name] ?= []
  getUsers: (item) ->
    @users[item.name] ?= []
  reset: ->
    @items = {}
    @paymentsForItem = {}
    @users = {}
    @payments = []
  deletePayment: (p) ->
    console.debug "delete #{p.toString()}"
    deleteFromArray = (parent, prop, value) ->
      parent[prop] = _(parent[prop]).without(value)
    deleteFromArray p.fromAccount, 'sendsPayments', p
    deleteFromArray p.toAccount, 'receivesPayments', p
    if p.item?
      delete @paymentsForItem[p.item.name]
    p.settled = true
  createOrIncreasePayment: (options) ->
    payments = _(@payments).filter (p) ->
      p.fromAccount is options.fromAccount and p.toAccount is options.toAccount
    if payments[0]
      console.debug "increase #{payments[0].toString()} by $#{options.amount}"
      payments[0].amount += options.amount
      payments[0]
    else
      new Payment options
  createInternalPayments: ->
    for item in _.values(@items)
      for p in @getPaymentsForItem(item) when p.settled
        for user in @getUsers(item) when user isnt p.fromAccount
          @createOrIncreasePayment
            amount: item.amount / @getUsers(item).length
            toAccount: p.fromAccount
            fromAccount: user
            settled: false
    undefined
  simplifyPayments: ->
    # Simplify the payment graph as much as
    # possible without changing the ultimate
    # flow of $$$.
    #
    # Pseudo-code for a general solution:
    # The => symbol represents a payment between two accounts
    # Arithmetic operations with payments are performed with payment amounts
    # Assignment operations create payments if none existed previously
    #
    #
    # For each A1 => A2
    #   If A2 => A3
    #     If A1 => A2 > A2 => A3
    #       (A1 => A3) += (A1 => A2) - (A2 => A3)
    #       (A1 => A2) -= (A1 => A3)
    #       (A2 => A3) = 0
    #     Else If A1 => A2 < A2 => A3
    #       (A1 => A3) += (A2 => A3) - (A1 => A2)
    #       (A2 => A3) -= (A1 => A3)
    #       (A1 => A2) = 0
    #     Else If A1 => A2 is A2 => A3
    #       (A1 => A3) = (A1 => A2)
    #       (A1 => A2) = (A2 => A3) = 0

    # Implemenation:

    payments = _(@payments)
      .sortBy('amount')
      .filter (p) -> not p.settled and p.isInternal()

    for p in payments
      for p2 in payments when p.toAccount is p2.fromAccount and
          not (p.settled or p2.settled)
        console.debug """#{
          p.fromAccount.name
        } owes $#{
          p.amount
        } to #{
          p.toAccount.name
        } and #{
          p2.fromAccount.name
        } owes $#{
          p2.amount
        } to #{
          p2.toAccount.name
        }"""

        if p.amount is p2.amount
          if p.fromAccount isnt p2.toAccount
            console.debug "redirect #{p.toString()} to #{p2.toAccount.name}"
            p.toAccount = p2.toAccount
          else
            @deletePayment(p)
          @deletePayment(p2)
        else
          minflow = Math.min(p.amount, p2.amount)

          if p.fromAccount isnt p2.toAccount
            payments.push newp = @createOrIncreasePayment
              fromAccount: p.fromAccount
              toAccount: p2.toAccount
              amount: minflow
              settled: false
              
          if p.amount > p2.amount
            console.debug "decrease #{p.toString()} by $#{minflow}"
            if p.amount > minflow
              p.amount -= minflow
            else
              @deletePayment(p)
            @deletePayment(p2)
          else
            console.debug "decrease #{p2.toString()} by $#{minflow}"
            if p2.amount > minflow
              p2.amount -= minflow
            else
              @deletePayment(p2)
            @deletePayment(p)

    undefined
          
  Item: Item
  Account: Account
  Payment: Payment

finances.reset()

    

     

