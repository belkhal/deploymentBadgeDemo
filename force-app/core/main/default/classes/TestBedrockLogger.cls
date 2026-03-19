@isTest
private class TestBedrockLogger {
    @isTest
    static void log_acceptsLevelAndMessage() {
        Test.startTest();
        BedrockLogger.log('INFO', 'Test message');
        BedrockLogger.log('ERROR', 'Error message');
        BedrockLogger.log('DEBUG', 'Debug message');
        Test.stopTest();

        Assert.isTrue(true, 'log should execute without exception');
    }

    @isTest
    static void log_handlesEmptyStrings() {
        Test.startTest();
        BedrockLogger.log('', '');
        Test.stopTest();

        Assert.isTrue(true, 'log should handle empty strings');
    }
}
