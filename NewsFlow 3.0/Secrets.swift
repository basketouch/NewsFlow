import Foundation

/// Claves privadas locales.
/// Después del primer clone, ejecuta:
///   git update-index --skip-worktree "NewsFlow 3.0/Secrets.swift"
/// y sustituye los valores vacíos por las keys reales.
enum Secrets {
    /// OpenAI API Key — platform.openai.com/account/api-keys
    static let openAIKey = ""
}
