Pod::Spec.new do |s|
    s.name             = 'PasskeymeSDK'
    s.version          = '0.1.0'
    s.summary          = 'A simple SDK for integrating passkeys with Passkeyme.com'
  
    s.description      = <<-DESC
                         PasskeymeSDK is a simple SDK for integrating passkeys into your iOS applications.
                         DESC
  
    s.homepage         = 'https://passkeyme.com'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Justin Crosbie' => 'justincrosbie@gmail.com' }
    s.source           = { :git => 'https://github.com/justincrosbie/passkeyme-ios-sdk.git', :tag => s.version.to_s }
  
    s.ios.deployment_target = '16.0'
    s.source_files = 'PasskeymeSDK/**/*.{swift}'
    s.frameworks = 'AuthenticationServices'
    s.swift_version = '5.0'
  end