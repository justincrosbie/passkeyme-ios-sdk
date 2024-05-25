import Foundation
import AuthenticationServices

public class PasskeymeSDK {
    
    public init() {}
    
    public func passkeyRegister(challenge: String, completion: @escaping (Result<String, Error>) -> Void) {
        let data = challenge.data(using: .utf8) {
        do {
            // Use a Codable struct or dictionary to represent the data
            let regChallenge = try! JSONDecoder().decode(RegisterChallenge.self, from: data)

            let domain = regChallenge.publicKey.rp.id
            let username = regChallenge.publicKey.user.name
            let rpID = regChallenge.publicKey.rp.id
            let userIDData = regChallenge.publicKey.user.id.data(using: .utf8)!
            let challengeData = Data(regChallenge.publicKey.challenge.utf8)

            let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)

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
        } catch {
            call.reject("Invalid JSON data")
        }
    }
    
    public func passkeyAuthenticate(challenge: String, completion: @escaping (Result<String, Error>) -> Void) {
        let data = challenge.data(using: .utf8) {
        do {
            // Use a Codable struct or dictionary to represent the data
            let authChallenge = try! JSONDecoder().decode(AuthChallenge.self, from: data)
            let domain = authChallenge.publicKey.rpId
            let challengeData = Data(authChallenge.publicKey.challenge.utf8)
            
            // Fetch the challenge from the server. The challenge needs to be unique for each request.
            let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challengeData)
            
            // Also allow the user to use a saved password, if they have one.
            let passwordCredentialProvider = ASAuthorizationPasswordProvider()
            let passwordRequest = passwordCredentialProvider.createRequest()
            
            // Pass in any mix of supported sign-in request types.
            let authController = ASAuthorizationController(authorizationRequests: [ assertionRequest, passwordRequest ] )
            authController.delegate = self
            authController.presentationContextProvider = self
            
            if preferImmediatelyAvailableCredentials {
                // If credentials are available, presents a modal sign-in sheet.
                // If there are no locally saved credentials, no UI appears and
                // the system passes ASAuthorizationError.Code.canceled to call
                // `AccountManager.authorizationController(controller:didCompleteWithError:)`.
                authController.performRequests(options: .preferImmediatelyAvailableCredentials)
            } else {
                // If credentials are available, presents a modal sign-in sheet.
                // If there are no locally saved credentials, the system presents a QR code to allow signing in with a
                // passkey from a nearby device.
                authController.performRequests()
            }
            
            isPerformingModalReqest = true
        } catch {
            call.reject("Invalid JSON data")
        }
    }
}

extension PasskeymeSDK: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            let credentialID = credential.credentialID.base64EncodedString()

            let id = credential.credentialID
            let type = "public-key"
            let rawIdEncoded = base64UrlEncode(credential.credentialID)
            let attestationObjectEncoded = base64UrlEncode(credential.rawAttestationObject!)
            
            if let decodedChallenge = updateClientDataJSONChallenge(from: credential.rawClientDataJSON) {
                let clientDataEncoded = base64UrlEncode(decodedChallenge)

                let jsonString = """
                {
                    "credential":
                    {
                        "id": "\(String(data: id, encoding: .utf8) ?? "")",
                        "type": "\(type)",
                        "rawId": "\(rawIdEncoded)",
                        "response": {
                            "clientDataJSON": "\(clientDataEncoded)",
                            "attestationObject": "\(attestationObjectEncoded)",
                        }
                    }
                }
                """
                
                completion(.success(jsonString))
            } else {
                completion(.failure(NSError(domain: "PasskeymeSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "Challenge decode conversion Fail."])))
            }
        } else if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            let credentialID = credential.credentialID.base64EncodedString()

            if let rawAuthenticatorData = credential.rawAuthenticatorData,
               let signature = credential.signature,
               let userID = credential.userID {
                
                let stringUserID = String(data: userID, encoding: .utf8)
                let stringSignature = String(data: signature, encoding: .utf8)
                let stringAuthenticatorData = String(data: rawAuthenticatorData, encoding: .utf8)
                
                // Verify the below signature and clientDataJSON with your service for the given userID.
                let rawClientDataJSON = credential.rawClientDataJSON
                let credentialID = credential.credentialID
                let type = "public-key"
                let rawIdEncoded = base64UrlEncode(credential.credentialID)

                let clientDataEncoded = base64UrlEncode(credential.rawClientDataJSON)
                
                let jsonString = """
                {
                    "credential":
                    {
                        "authenticatorAttachment": "platform",
                        "id": "\(rawIdEncoded)",
                        "type": "public-key",
                        "rawId": "\(rawIdEncoded)",
                        "response": {
                            "clientDataJSON": "\(credential.rawClientDataJSON.base64EncodedString())",
                            "authenticatorData": "\(base64UrlEncode(rawAuthenticatorData))",
                            "signature": "\(base64UrlEncode(signature))",
                            "userHandle": "\(base64UrlEncode(userID))"
                        }
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

    func base64UrlEncode(_ data: Data) -> String {
        var encodedString = data.base64EncodedString()
        encodedString = encodedString
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        return encodedString
    }
    
    func base64UrlDecode(_ base64String: String) -> Data? {
        var base64 = base64String
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        switch base64.count % 4 {
        case 2: base64 += "=="
        case 3: base64 += "="
        default: break
        }
        return Data(base64Encoded: base64)
    }
    func base64UrlDecodeToStr(_ base64String: String) -> String {
        var base64 = base64String
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        switch base64.count % 4 {
        case 2: base64 += "=="
        case 3: base64 += "="
        default: break
        }
        let d = Data(base64Encoded: base64)!
        return String(data: d, encoding: .utf8)!
    }

    func base64UrlToBase64(_ base64Url: String) -> String {
        var base64 = base64Url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        switch base64.count % 4 {
        case 2: base64 += "=="
        case 3: base64 += "="
        default: break
        }
        return base64
    }
    
    func updateClientDataJSONChallenge(from rawClientDataJSON: Data) -> Data? {
        
        // Decode the raw clientDataJSON to a JSON object
        guard var clientData = try? JSONSerialization.jsonObject(with: rawClientDataJSON, options: []) as? [String: Any],
              let base64Challenge = clientData["challenge"]
               else {
            return nil
        }
        
        let decodedChallengeStr = base64UrlDecodeToStr(base64Challenge as? String ?? "")
        
        // Update the challenge field to the decoded value
        clientData["challenge"] = decodedChallengeStr as Any
        clientData["crossOrigin"] = false as Any
        
        let type = clientData["type"] as? String
        let challenge = clientData["challenge"] as? String
        let origin = clientData["origin"] as? String
        
        let updatedStr = "{\"type\":\"\(type!)\",\"challenge\":\"\(challenge!)\",\"origin\":\"\(origin!)\",\"crossOrigin\":false}"

        let updatedData = updatedStr.data(using: .utf8)
        
        return updatedData!        
    }}