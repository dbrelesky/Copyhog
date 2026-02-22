import XCTest
@testable import Copyhog

final class PasswordDetectorTests: XCTestCase {

    // MARK: - Should detect as passwords

    func testStrongPasswordWithAllClasses() {
        // Uppercase + lowercase + digits + special chars
        XCTAssertTrue(PasswordDetector.looksLikePassword("P@ssw0rd!23"))
        XCTAssertTrue(PasswordDetector.looksLikePassword("MyS3cur3#Pass"))
        XCTAssertTrue(PasswordDetector.looksLikePassword("Ab1!cD2@eF3#"))
    }

    func testGeneratedPasswords() {
        // Typical password manager generated passwords
        XCTAssertTrue(PasswordDetector.looksLikePassword("x7K#mQ9$vL2&nR"))
        XCTAssertTrue(PasswordDetector.looksLikePassword("Hg4!kL8@pQ2#wZ"))
        XCTAssertTrue(PasswordDetector.looksLikePassword("aB3$dE5^fG7*hI"))
    }

    func testAPIKeys() {
        // Long hex strings (API keys)
        XCTAssertTrue(PasswordDetector.looksLikePassword("a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"))
        // Mixed case token with high entropy
        XCTAssertTrue(PasswordDetector.looksLikePassword("tok_test_4eC39HqLyjWDarjtT1zdp7dc"))
    }

    func testJWTTokens() {
        // JWT-like structure (three dot-separated segments)
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        XCTAssertTrue(PasswordDetector.looksLikePassword(jwt))
    }

    func testBase64Tokens() {
        // Base64-encoded tokens with high entropy
        XCTAssertTrue(PasswordDetector.looksLikePassword("dGhpcyBpcyBhIHRlc3QgdG9rZW4="))
    }

    func testThreeCharacterClasses() {
        // 3 classes + high entropy
        XCTAssertTrue(PasswordDetector.looksLikePassword("Hello123!@#"))
        XCTAssertTrue(PasswordDetector.looksLikePassword("test$WORD99"))
    }

    // MARK: - Should NOT detect as passwords

    func testNormalWords() {
        XCTAssertFalse(PasswordDetector.looksLikePassword("hello"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("password"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("copyhog"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("SwiftUI"))
    }

    func testNormalSentences() {
        XCTAssertFalse(PasswordDetector.looksLikePassword("This is a normal sentence"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("Hello world, how are you?"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("The quick brown fox jumps over the lazy dog"))
    }

    func testURLs() {
        XCTAssertFalse(PasswordDetector.looksLikePassword("https://www.google.com"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("https://example.com/path/to/page"))
    }

    func testEmailAddresses() {
        XCTAssertFalse(PasswordDetector.looksLikePassword("user@example.com"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("john.doe@company.org"))
    }

    func testShortStrings() {
        // Too short to be a password (< 8 chars)
        XCTAssertFalse(PasswordDetector.looksLikePassword("Ab1!"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("12345"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("abc"))
    }

    func testMultilineText() {
        XCTAssertFalse(PasswordDetector.looksLikePassword("line one\nline two"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("func main() {\n    print(\"hi\")\n}"))
    }

    func testPhoneNumbers() {
        XCTAssertFalse(PasswordDetector.looksLikePassword("555-123-4567"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("(555)123-4567"))
    }

    func testCodeSnippets() {
        // Single-line code that's not a password
        XCTAssertFalse(PasswordDetector.looksLikePassword("print(\"hello\")"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("let x = 42"))
    }

    func testSimpleNumbers() {
        XCTAssertFalse(PasswordDetector.looksLikePassword("12345678"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("00000000"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("11111111"))
    }

    func testFilePaths() {
        // File paths without spaces
        XCTAssertFalse(PasswordDetector.looksLikePassword("/usr/local/bin/python3"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("/Users/me/Documents"))
    }

    func testEmptyAndWhitespace() {
        XCTAssertFalse(PasswordDetector.looksLikePassword(""))
        XCTAssertFalse(PasswordDetector.looksLikePassword("   "))
        XCTAssertFalse(PasswordDetector.looksLikePassword("\n\n"))
    }

    func testLongPlainText() {
        // Long string but no password characteristics
        XCTAssertFalse(PasswordDetector.looksLikePassword("aaaaaaaaaaaaaaaa"))
        XCTAssertFalse(PasswordDetector.looksLikePassword("abcabcabcabcabcabc"))
    }

    // MARK: - Entropy

    func testEntropyOfRandomString() {
        // Random-looking string should have high entropy
        let entropy = PasswordDetector.shannonEntropy("x7K#mQ9$vL2&nR")
        XCTAssertGreaterThan(entropy, 3.0)
    }

    func testEntropyOfRepetitiveString() {
        // Repetitive string should have low entropy
        let entropy = PasswordDetector.shannonEntropy("aaaaaaaaaa")
        XCTAssertLessThan(entropy, 1.0)
    }

    func testEntropyOfEnglishWord() {
        let entropy = PasswordDetector.shannonEntropy("password")
        XCTAssertLessThan(entropy, 3.0)
    }
}
