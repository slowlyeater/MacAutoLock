import Foundation
import Testing
@testable import MacAutoLockShared

@Test
func pairingCodeAcceptsExactlyFourDigits() {
    #expect(PairingCodeValidator.normalized("1234") == "1234")
    #expect(PairingCodeValidator.normalized(" 9876 ") == "9876")
}

@Test
func pairingCodeRejectsNonFourDigitInputs() {
    #expect(PairingCodeValidator.normalized("123") == nil)
    #expect(PairingCodeValidator.normalized("12345") == nil)
    #expect(PairingCodeValidator.normalized("12A4") == nil)
    #expect(PairingCodeValidator.normalized("") == nil)
}

@Test
func generatedPairingCodeIsFourDigits() {
    for _ in 0..<50 {
        let code = PairingCodeValidator.generate()
        #expect(code.count == 4)
        #expect(PairingCodeValidator.normalized(code) == code)
    }
}
