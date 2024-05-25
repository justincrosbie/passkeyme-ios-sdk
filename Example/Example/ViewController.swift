import UIKit
import PasskeymeSDK

class ViewController: UIViewController {
    
    let sdk = PasskeymeSDK()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let registerButton = UIButton(type: .system)
        registerButton.setTitle("Register", for: .normal)
        registerButton.addTarget(self, action: #selector(registerPasskey), for: .touchUpInside)
        
        let authenticateButton = UIButton(type: .system)
        authenticateButton.setTitle("Authenticate", for: .normal)
        authenticateButton.addTarget(self, action: #selector(authenticatePasskey), for: .touchUpInside)
        
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
    
    @objc func registerPasskey() {
        sdk.passkeyRegister(challenge: "your-challenge") { result in
            switch result {
            case .success(let credentialID):
                print("Registered credential: \(credentialID)")
            case .failure(let error):
                print("Registration error: \(error)")
            }
        }
    }
    
    @objc func authenticatePasskey() {
        sdk.passkeyAuthenticate(challenge: "your-challenge") { result in
            switch result {
            case .success(let credentialID):
                print("Authenticated credential: \(credentialID)")
            case .failure(let error):
                print("Authentication error: \(error)")
            }
        }
    }
}