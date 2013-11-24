// Generated by CoffeeScript 1.6.2
(function() {
  describe('the example data', function() {
    beforeEach(function() {
      return prepareTestData();
    });
    describe('account collection', function() {
      it('should have >0 accounts', function() {
        return expect(AccountCollection.find({}).count()).toBeGreaterThan(0);
      });
      return it('should return Account objects', function() {
        expect(AccountCollection.find({}).fetch()[0].constructor).toBe(finances.Account);
        return expect(_.values(currentScenario.accounts).length).toBeGreaterThan(0);
      });
    });
    describe('item collection', function() {
      it('should have >0 items', function() {
        return expect(ItemCollection.find({}).count()).toBeGreaterThan(0);
      });
      return it('should return Item objects', function() {
        expect(ItemCollection.find({}).fetch()[0].constructor).toBe(finances.Item);
        return expect(_.values(currentScenario.items).length).toBeGreaterThan(0);
      });
    });
    return describe('payment collection', function() {
      it('should have >0 items', function() {
        return expect(PaymentCollection.find({}).count()).toBeGreaterThan(0);
      });
      return it('should return Payment objects', function() {
        expect(PaymentCollection.find({}).fetch()[0].constructor).toBe(finances.Payment);
        return expect(currentScenario.payments.length).toBeGreaterThan(0);
      });
    });
  });

}).call(this);
