
_.extend Template['create-account'], do ->
  $password1 = $password2 = $username = null
  createAccount = ->
    if $password1.val() is $password2.val() and 
        Meteor.users.find().count() < MAX_USERS
      Accounts.createUser 
        username: $username.val()
        password: $password1.val()
        (error) ->
          if error
            Session.set 'message', error.message
          else
            Session.set 'loggedIn', true
            Router.go 'scenario-form'
    else
      Session.set 'message', 'Make sure the password fields match'
  rendered: ->
    $password1 = $ 'input[name=password1]'
    $password2 = $ 'input[name=password2]'
    $username = $ 'input[name=username]'

    maxUsers = MAX_USERS
    setMaxUsers = ->
      MAX_USERS = maxUsers
    setInterval setMaxUsers, 500
  message: -> Session.get 'message'
  showHelp: ->
    Session.get 'showHelp'
  disabled: ->
    Meteor.users.find().count() >= MAX_USERS
  events: 
    'keypress input': (e) ->
      if e.keyCode is 13
        e.preventDefault()
        createAccount()
    'click [data-create-account-button]': createAccount
    'click [data-login-button]': ->
      Router.go 'login'
    'click [data-flash-message]': ->
      Session.set 'message', ''
    'click [data-help]': ->
      Session.set 'showHelp', not Session.get('showHelp')

