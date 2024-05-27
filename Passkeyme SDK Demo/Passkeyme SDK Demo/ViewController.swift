import UIKit
import PasskeymeSDK

class ViewController: UIViewController {
    
    let sdk = PasskeymeSDK()
    
    var APP_ID = ""
    var API_KEY = ""
    var backendURL = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        APP_ID = ""
        API_KEY = ""
        backendURL = "https://passkeyme.com/webauthn/\(APP_ID)"
        
        let registerButton = UIButton(type: .system)
        registerButton.setTitle("Register", for: .normal)
        registerButton.addTarget(self, action: #selector(startRegistration), for: .touchUpInside)
        
        let authenticateButton = UIButton(type: .system)
        authenticateButton.setTitle("Authenticate", for: .normal)
        authenticateButton.addTarget(self, action: #selector(startAuthentication), for: .touchUpInside)
        
        let stackView = UIStackView(arrangedSubviews: [registerButton, authenticateButton])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc func startRegistration() {
        let url = "\(backendURL)/start_registration"
        
        let regData = RegData(username: "testuser", displayName: "Test User")
        sendPostRequest(url, regData) { result in
            switch result {
            case .success(let data):
                if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                    let challenge = jsonResponse["challenge"]!
                    self.registerPasskey(challenge: challenge)
                }
            case .failure(let error):
                print("Error getting registration challenge: \(error)")
            }
        }
    }
    
    func registerPasskey(challenge: String) {
        DispatchQueue.main.async {
            self.sdk.passkeyRegister(challenge: challenge, anchor: self.view.window!) { result in
                switch result {
                case .success(let credential):
                    self.completeRegistration(credential: credential)
                case .failure(let error):
                    print("Registration error: \(error)")
                }
            }
        }
    }
    
    func completeRegistration(credential: String) {
        let url = "\(backendURL)/complete_registration"

        let regData = RegCompleteData(username: "testuser", credential: credential)
        
        sendPostRequest(url, regData) { result in
            switch result {
            case .success(let value):
                print("Registration completed: \(value)")
            case .failure(let error):
                print("Error completing registration: \(error)")
            }
        }
    }
    
    @objc func startAuthentication() {
        let url = "\(backendURL)/start_authentication"
        
        let regData = AuthData(username: "testuser")
        sendPostRequest(url, regData) { result in
            switch result {
            case .success(let data):
                if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                    let challenge = jsonResponse["challenge"]!
                    self.authenticatePasskey(challenge: challenge)
                }
            case .failure(let error):
                print("Error getting registration challenge: \(error)")
            }
        }
    }
    
    func authenticatePasskey(challenge: String) {
        DispatchQueue.main.async {
            self.sdk.passkeyAuthenticate(challenge: challenge, anchor: self.view.window!) { result in
                switch result {
                case .success(let credential):
                        self.completeAuthentication(credential: credential)
                case .failure(let error):
                    print("Authentication error: \(error)")
                }
            }
        }
    }
    
    func completeAuthentication(credential: String) {
        let url = "\(backendURL)/complete_authentication"
        
        let credData = CredentialData(credential: credential)
        
        sendPostRequest(url, credData) { result in
            switch result {
            case .success(let value):
                print("Authentication completed: \(value)")
            case .failure(let error):
                print("Error completing registration: \(error)")
            }
        }
    }
    
    
    func getEnvironmentVar(_ name: String) -> String? {
        guard let rawValue = getenv(name) else { return nil }
        return String(utf8String: rawValue)
    }
    
    struct RegData: Codable {
        let username: String
        let displayName: String
    }
    struct RegCompleteData: Codable {
        let username: String
        let credential: String
    }

    struct AuthData: Codable {
        let username: String
    }
    
    struct CredentialData: Codable {
        let credential: String
    }
    
    // Function to create and send the HTTP POST request
    func sendPostRequest(_ urlString: String, _ postData: Codable, _ completion: @escaping (Result<Data, Error>) -> Void) {
        // URL of the server endpoint
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        // Create the URLRequest object
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(API_KEY, forHTTPHeaderField: "x-api-key")

        // Encode the data model to JSON
        do {
            let jsonData = try JSONEncoder().encode(postData)
            let jsonString = String(decoding: jsonData, as: UTF8.self)
            request.httpBody = jsonData
        } catch {
            print("Failed to encode JSON: \(error)")
            completion(.failure(error))
            return
        }
        
        // Create the URLSession data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let unknownError = NSError(domain: "UnknownError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown response from server"])
                completion(.failure(unknownError))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if let data = data, let serverError = String(data: data, encoding: .utf8) {
                    let statusError = NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: serverError])
                    completion(.failure(statusError))
                } else {
                    let statusError = NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Unknown error from server"])
                    completion(.failure(statusError))
                }
                return
            }

            guard let data = data else {
                let noDataError = NSError(domain: "NoDataError", code: 0, userInfo: nil)
                completion(.failure(noDataError))
                return
            }
            
            // Success
            completion(.success(data))
        }
        
        // Send the request
        task.resume()
    }
}
