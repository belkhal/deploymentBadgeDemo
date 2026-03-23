/**
 * Healthcare org domain helpers for visit-related business rules.
 * Bedrock-Healthcare package.
 */
public with sharing class HealthcareVisitService {
    /**
     * Builds a short summary line for display or logging from visit inputs.
     */
    public static String buildVisitSummary(String primaryConcern, Date visitDate) {
        BedrockLogger.log('INFO', 'HealthcareVisitService.buildVisitSummary');
        if (visitDate == null) {
            return 'Visit: date not set';
        }
        String concern = String.isBlank(primaryConcern) ? 'General' : primaryConcern.trim();
        return 'Visit on ' + formatDate(visitDate) + ' — ' + concern;
    }

    /**
     * Returns true when the concern text should be escalated (simple keyword rule).
     */
    public static Boolean isEscalationCandidate(String primaryConcern) {
        if (String.isBlank(primaryConcern)) {
            return false;
        }
        String upper = primaryConcern.toUpperCase();
        return upper.contains('EMERGENCY') || upper.contains('URGENT');
    }

    private static String formatDate(Date d) {
        return String.valueOf(d.year()) + '-' + pad(d.month()) + '-' + pad(d.day());
    }

    private static String pad(Integer n) {
        String s = String.valueOf(n);
        return s.length() == 1 ? '0' + s : s;
    }
}
