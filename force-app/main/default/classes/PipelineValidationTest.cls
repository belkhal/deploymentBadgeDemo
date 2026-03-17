public with sharing class PipelineValidationTest {
    @AuraEnabled(cacheable=true)
    public static String getMessage() {
        return 'Pipeline validation successful';
    }
}
