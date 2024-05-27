import Foundation
import AuthenticationServices

extension NSNotification.Name {
    static let UserSignedIn = Notification.Name("UserSignedInNotification")
    static let ModalSignInSheetCanceled = Notification.Name("ModalSignInSheetCanceledNotification")
}

public class PasskeymeSDK : NSObject, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
    
    var authenticationAnchor: ASPresentationAnchor?
    var completion: (Result<String, Error>) -> Void = { _ in }
    var isPerformingModalReqest = false
    
    public func passkeyRegister(challenge: String, anchor: ASPresentationAnchor, completion: @escaping (Result<String, Error>) -> Void) {

        self.completion = completion
        self.authenticationAnchor = anchor

        if let data = challenge.data(using: .utf8) {
            // Use a Codable struct or dictionary to represent the data
            let regChallenge = try! JSONDecoder().decode(RegisterChallenge.self, from: data)

            let username = regChallenge.publicKey.user.name
            let rpID = regChallenge.publicKey.rp.id
            let userIDData = regChallenge.publicKey.user.id.data(using: .utf8)!
            let challengeData = Data(regChallenge.publicKey.challenge.utf8)

            // Create the Credential Provider with the specified RP ID
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpID)
            
            // Create the Registration Request using the Provider
            let registrationRequest = provider.createCredentialRegistrationRequest(
                challenge: challengeData,
                name: username,
                userID: userIDData
            )
            
            // Use only ASAuthorizationPlatformPublicKeyCredentialRegistrationRequests or
            // ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequests here.
            let authController = ASAuthorizationController(authorizationRequests: [ registrationRequest ] )
            authController.delegate = self
            authController.presentationContextProvider = self
            authController.performRequests()
            isPerformingModalReqest = true
        } else {
            completion(.failure(NSError(domain: "PasskeymeSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"])))
        }
    }
    
    public func passkeyAuthenticate(challenge: String, anchor: ASPresentationAnchor, completion: @escaping (Result<String, Error>) -> Void) {

        self.completion = completion
        self.authenticationAnchor = anchor
        
        if let data = challenge.data(using: .utf8) {
            // Use a Codable struct or dictionary to represent the data
            let authChallenge = try! JSONDecoder().decode(AuthChallenge.self, from: data)
            let domain = authChallenge.publicKey.rpId
            let challengeData = Data(authChallenge.publicKey.challenge.utf8)
            
            let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)

            // Fetch the challenge from the server. The challenge needs to be unique for each request.
            let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challengeData)
            
            // Also allow the user to use a saved password, if they have one.
            let passwordCredentialProvider = ASAuthorizationPasswordProvider()
            let passwordRequest = passwordCredentialProvider.createRequest()
            
            // Pass in any mix of supported sign-in request types.
            let authController = ASAuthorizationController(authorizationRequests: [ assertionRequest, passwordRequest ] )
            authController.delegate = self
            authController.presentationContextProvider = self

            let preferImmediatelyAvailableCredentials = true
            
            if preferImmediatelyAvailableCredentials {
                // If credentials are available, presents a modal sign-in sheet.
                // If there are no locally saved credentials, no UI appears and
                // the system passes ASAuthorizationError.Code.canceled to call
                // `AccountManager.authorizationController(controller:didCompleteWithError:)`.
                authController.performRequests(options: .preferImmediatelyAvailableCredentials)
            // } else {
            //     // If credentials are available, presents a modal sign-in sheet.
            //     // If there are no locally saved credentials, the system presents a QR code to allow signing in with a
            //     // passkey from a nearby device.
            //     authController.performRequests()
            }
            
            isPerformingModalReqest = true
        } else {
            completion(.failure(NSError(domain: "PasskeymeSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"])))
        }
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {

            let id = credential.credentialID
            let type = "public-key"
            let rawIdEncoded = EncodingUtils.base64UrlEncode(credential.credentialID)
            let attestationObjectEncoded = EncodingUtils.base64UrlEncode(credential.rawAttestationObject!)
            
            if let decodedChallenge = EncodingUtils.updateClientDataJSONChallenge(from: credential.rawClientDataJSON) {
                let clientDataEncoded = EncodingUtils.base64UrlEncode(decodedChallenge)

                let jsonString = """
                {
                    "id": "\(rawIdEncoded)",
                    "type": "\(type)",
                    "rawId": "\(rawIdEncoded)",
                    "response": {
                        "clientDataJSON": "\(clientDataEncoded)",
                        "attestationObject": "\(attestationObjectEncoded)",
                    }
                }
                """
                
                completion(.success(jsonString))
            } else {
                completion(.failure(NSError(domain: "PasskeymeSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "Challenge decode conversion Fail."])))
            }
        } else if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {

            if let rawAuthenticatorData = credential.rawAuthenticatorData,
               let signature = credential.signature,
               let userID = credential.userID {
                
                // Verify the below signature and clientDataJSON with your service for the given userID.
                let type = "public-key"
                let rawIdEncoded = EncodingUtils.base64UrlEncode(credential.credentialID)

                let jsonString = """
                {
                    "authenticatorAttachment": "platform",
                    "id": "\(rawIdEncoded)",
                    "type": "\(type)",
                    "rawId": "\(rawIdEncoded)",
                    "response": {
                        "clientDataJSON": "\(credential.rawClientDataJSON.base64EncodedString())",
                        "authenticatorData": "\(EncodingUtils.base64UrlEncode(rawAuthenticatorData))",
                        "signature": "\(EncodingUtils.base64UrlEncode(signature))",
                        "userHandle": "\(EncodingUtils.base64UrlEncode(userID))"
                    }
                }
                """

                completion(.success(jsonString))
            } else {
                completion(.failure(NSError(domain: "PasskeymeSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "Credential decode conversion Fail."])))
            }
        } else {
            completion(.failure(NSError(domain: "PasskeymeSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown credential type."])))
        }
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
    
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIWindow()
    }
}
