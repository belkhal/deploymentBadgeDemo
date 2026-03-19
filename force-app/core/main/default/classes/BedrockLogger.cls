public with sharing class BedrockLogger {
    /**
     * Shared logging utility used across all packages.
     * Part of Bedrock-Core package.
     */
    public static void log(String level, String message) {
        System.debug(level + ': ' + message);
    }
}
