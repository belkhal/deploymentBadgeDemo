@IsTest
private class HealthcareVisitServiceTest {
    @IsTest
    static void buildVisitSummary_formatsDateAndConcern() {
        Date d = Date.newInstance(2025, 6, 15);
        String summary = HealthcareVisitService.buildVisitSummary('Annual checkup', d);
        System.assert(summary.contains('2025-06-15'), 'Should include ISO-like date: ' + summary);
        System.assert(summary.contains('Annual checkup'), summary);
    }

    @IsTest
    static void buildVisitSummary_nullDate_returnsPlaceholder() {
        System.assertEquals(
            'Visit: date not set',
            HealthcareVisitService.buildVisitSummary('x', null)
        );
    }

    @IsTest
    static void buildVisitSummary_blankConcern_usesGeneral() {
        Date d = Date.today();
        String summary = HealthcareVisitService.buildVisitSummary('   ', d);
        System.assert(summary.contains('General'), summary);
    }

    @IsTest
    static void isEscalationCandidate_detectsKeywords() {
        System.assertEquals(false, HealthcareVisitService.isEscalationCandidate(null));
        System.assertEquals(false, HealthcareVisitService.isEscalationCandidate('Routine'));
        System.assertEquals(true, HealthcareVisitService.isEscalationCandidate('URGENT follow-up'));
        System.assertEquals(true, HealthcareVisitService.isEscalationCandidate('patient emergency'));
    }
}
