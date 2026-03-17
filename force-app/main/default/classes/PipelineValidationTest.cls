/**
 * @description       : 
 * @author            : Bader Eddine Elkhal
 * @group             : 
 * @last modified on  : 03-17-2026
 * @last modified by  : Bader Eddine Elkhal
**/
public with sharing class PipelineValidationTest {
    @AuraEnabled(cacheable=true)
    public static String getMessage() {
        return 'Pipeline validation successful';
    }
    
}
