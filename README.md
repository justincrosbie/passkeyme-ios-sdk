![alt text](https://passkeyme.com/docs/img/passkeyme-logo-removebg-preview.png)
# Passkeyme iOS SDK

Passkeyme Web SDK is a convenience SDK for the Passkeyme platform JavaScript/TypeScript library that provides simple functions to handle passkey registration and authentication using the WebAuthn API. This library helps you integrate passkey-based authentication into your web applications with ease.

See [Passkeyme](https://passkeyme.com)

## Installation

You can install the Passkey SDK via cocoapods:

```bash
platform :ios, '16.0'

target 'Passkeyme SDK Demo' do
  use_frameworks!

  pod 'PasskeymeSDK', "~> 0.3.0"
end
```

then
```
pod install
```

## Usage

Importing the SDK

```
import PasskeymeSDK
```

### Creating an Instance

Create an instance of the PasskeySDK:

```
let sdk = PasskeymeSDK()
```

### Registering a Passkey

To register a passkey, use the passkeyRegister method. This method takes a challenge string as input and returns a promise that resolves to an object containing the credential.

```
sdk.passkeyRegister(challenge: challenge, anchor: self.view.window!) { result in
    switch result {
    case .success(let credential):
        self.completeRegistration(credential: credential)
    case .failure(let error):
        print("Registration error: \(error)")
    }
}
```

### Authenticating with a Passkey

To authenticate using a passkey, use the passkeyAuthenticate method. This method takes a challenge string as input and returns a promise that resolves to an object containing the credential.

```
sdk.passkeyAuthenticate(challenge: challenge, anchor: self.view.window!) { result in
    switch result {
    case .success(let credential):
        self.completeAuthentication(credential: credential)
    case .failure(let error):
        print("Authentication error: \(error)")
    }
}
```

## API

passkeyRegister(challenge: string): Promise<{ credential: string }>

	•	challenge: A string that represents the challenge provided by your server.
	•	Returns: A promise that resolves to an object containing the credential.

passkeyAuthenticate(challenge: string): Promise<{ credential: string }>

	•	challenge: A string that represents the challenge provided by your server.
	•	Returns: A promise that resolves to an object containing the credential.

## Example

Here is a full working example. 

To get it working, first, go to [Passkeyme](https://passkeyme.com), register, create an app and grab the AppID and API Key, and populate in your env as:
```
APP_ID=
API_KEY=
```

You'll need to run it behind an addressible domain for Passkeys to work. You can host it, or use ngrok to serve it.
You'll need to follow the istructions at https://passkeyme.com/docs/docs/SDKs/swift-sdk

```
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
```
