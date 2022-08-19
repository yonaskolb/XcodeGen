import AppIntents

struct Intent: AppIntent {
    static var title: LocalizedStringResource = "Intent"
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
