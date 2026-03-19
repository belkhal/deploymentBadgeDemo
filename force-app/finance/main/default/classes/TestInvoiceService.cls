@isTest
private class TestInvoiceService {
    @isTest
    static void calculateTotal_returnsZero() {
        Account acc = new Account(Name = 'Test Invoice');
        insert acc;

        Test.startTest();
        Decimal total = InvoiceService.calculateTotal(acc.Id);
        Test.stopTest();

        Assert.areEqual(0, total, 'calculateTotal should return 0');
    }

    @isTest
    static void calculateTotal_handlesNullId() {
        Test.startTest();
        Decimal total = InvoiceService.calculateTotal(null);
        Test.stopTest();

        Assert.areEqual(0, total, 'calculateTotal should return 0 even with null');
    }
}
