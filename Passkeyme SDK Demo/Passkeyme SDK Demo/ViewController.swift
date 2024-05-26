import UIKit
import PasskeymeSDK
import Alamofire

class ViewController: UIViewController {
    
    let sdk = PasskeymeSDK()

    var APP_ID = ""
    var API_KEY = ""
    var backendURL = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        APP_ID = getEnvironmentVar("APP_ID")!
        API_KEY = getEnvironmentVar("API_KEY")!
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
        AF.request(url, method: .post, parameters: nil, encoding: JSONEncoding.default)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    if let json = value as? [String: Any], let challenge = json["challenge"] as? String {
                        self.registerPasskey(challenge: challenge)
                    }
                case .failure(let error):
                    print("Error getting registration challenge: \(error)")
                }
            }
    }
    
    func registerPasskey(challenge: String) {
        sdk.passkeyRegister(challenge: challenge, anchor: self.view.window!) { result in
            switch result {
            case .success(let credential):
                self.completeRegistration(credential: credential)
            case .failure(let error):
                print("Registration error: \(error)")
            }
        }
    }
    
    func completeRegistration(credential: String) {
        let url = "\(backendURL)/complete_registration"
        let parameters: [String: Any] = ["credential": credential]
        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    print("Registration completed: \(value)")
                case .failure(let error):
                    print("Error completing registration: \(error)")
                }
            }
    }
    
    @objc func startAuthentication() {
        let url = "\(backendURL)/start_authentication"
        AF.request(url, method: .post, parameters: nil, encoding: JSONEncoding.default)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    if let json = value as? [String: Any], let challenge = json["challenge"] as? String {
                        self.authenticatePasskey(challenge: challenge)
                    }
                case .failure(let error):
                    print("Error getting authentication challenge: \(error)")
                }
            }
    }
    
    func authenticatePasskey(challenge: String) {
        sdk.passkeyAuthenticate(challenge: challenge, anchor: self.view.window!) { result in
            switch result {
            case .success(let credential):
                self.completeAuthentication(credential: credential)
            case .failure(let error):
                print("Authentication error: \(error)")
            }
        }
    }
    
    func completeAuthentication(credential: String) {
        let url = "\(backendURL)/complete_authentication"
        let parameters: [String: Any] = ["credential": credential]
        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
            .responseJSON { response in
                switch response.result {
                case .success(let value):
                    print("Authentication completed: \(value)")
                case .failure(let error):
                    print("Error completing authentication: \(error)")
                }
            }
    }
    
    
    func getEnvironmentVar(_ name: String) -> String? {
        guard let rawValue = getenv(name) else { return nil }
        return String(utf8String: rawValue)
    }
}
