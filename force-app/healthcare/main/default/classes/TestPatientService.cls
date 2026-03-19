@isTest
private class TestPatientService {
    @isTest
    static void getPatientStatus_returnsActive() {
        Account acc = new Account(Name = 'Test Patient');
        insert acc;

        Test.startTest();
        String status = PatientService.getPatientStatus(acc.Id);
        Test.stopTest();

        Assert.areEqual('Active', status, 'getPatientStatus should return Active');
    }

    @isTest
    static void getPatientStatus_handlesNullId() {
        Test.startTest();
        String status = PatientService.getPatientStatus(null);
        Test.stopTest();

        Assert.areEqual('Active', status, 'getPatientStatus should return Active even with null');
    }
}
