//
//  BiometricHelper.swift
//  RD-Monitor
//
//  Created by Jean-Pierre Hermans on 28/05/2025.
//
import LocalAuthentication

class BiometricHelper {
    static func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                    localizedReason: "Authenticate to access Real-Debrid") { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
}
