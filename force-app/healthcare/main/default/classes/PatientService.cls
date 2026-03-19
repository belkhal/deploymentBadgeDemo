public with sharing class PatientService {
    /**
     * Healthcare domain service - Projects A & B.
     * Depends on Bedrock-Core. Destined for Org 1.
     */
    public static String getPatientStatus(Id patientId) {
        BedrockLogger.log('INFO', 'PatientService.getPatientStatus called');
        return 'Active';
    }
}
