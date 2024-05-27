import Foundation

public class EncodingUtils {
    
    public init() {}
    
    public static func base64UrlEncode(_ data: Data) -> String {
        var encodedString = data.base64EncodedString()
        encodedString = encodedString
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        return encodedString
    }
    
    public static func base64UrlDecode(_ base64String: String) -> Data? {
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
    public static func base64UrlDecodeToStr(_ base64String: String) -> String {
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

    public static func base64UrlToBase64(_ base64Url: String) -> String {
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
    
    public static func updateClientDataJSONChallenge(from rawClientDataJSON: Data) -> Data? {
        
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
    }

    public static func dictToJSONString(dict: [String: Any]) -> String? {
        // Check if the JSON is valid and can be serialized
        guard JSONSerialization.isValidJSONObject(dict) else {
            print("Invalid JSON object")
            return nil
        }
        
        // Serialize the dictionary to JSON data
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
            // Convert JSON data to string
            let jsonString = String(data: jsonData, encoding: .utf8)
            return jsonString
        } catch {
            print("Failed to serialize JSON: \(error)")
            return nil
        }
    }

    public static func createAttestationJSONString(clientDataJSON: String, attestationObject: String, 
                        rawId: String, id: String, type: String) -> String? {
        // Create a dictionary with your data
        let jsonDict: [String: Any] = [
            "rawId": rawId,
            "id": id,
            "type": type,
            "response": [
                "clientDataJSON": clientDataJSON,
                "attestationObject": attestationObject
            ],
        ]
        
        return dictToJSONString(dict: jsonDict)
    }

    public static func createAuthenticatorJSONString(clientDataJSON: String, authenticatorData: String, signature: 
                        String, userHandle: String, rawId: String, id: String, type: String, 
                        authenticatorAttachment: String) -> String? {
        // Create a dictionary with your data
        let jsonDict: [String: Any] = [
            "authenticatorAttachment": authenticatorAttachment,
            "rawId": rawId,
            "id": id,
            "type": type,
            "response": [
                "clientDataJSON": clientDataJSON,
                "authenticatorData": authenticatorData,
                "signature": signature,
                "userHandle": userHandle
            ],
        ]
        
        return dictToJSONString(dict: jsonDict)
    }
}
