import SwiftUI
import FinvuSDK

struct LoginView: View {
    let finvuManager = FinvuManager.shared
    let finvuClientConfig: FinvuClientConfig
    
    // State variables
    @State private var username: String = ""
    @State private var mobileNumber: String = ""
    @State private var consentHandleId: String = ""
    @State private var otp: String = ""
    @State private var showOtpField: Bool = false
    @State private var otpReference: String?
    @State private var navigateToDashboard: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var isRetryingLogin: Bool = false
    @State private var hasRetriedOnce: Bool = false
    
    // Constants
    static let consentHandleIds = [
            "ee793531-620b-40f4-a76b-9af3d065ead9",
    ]
    
    init() {
        let finvuUrl = URL(string: "wss://webvwdev.finvu.in/consentapiv2")!
        finvuClientConfig = FinvuClientConfig(
            finvuEndpoint: finvuUrl,
            certificatePins: [],
            finvuSnaAuthConfig: FinvuSnaAuthConfig(
                environment: .uat,
                viewController: UIApplication.shared
                    .connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                    .first!
                    .rootViewController!
            )
        )
        _consentHandleId = State(initialValue: LoginView.consentHandleIds[0])
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Login")
                    .font(.title)
                    .padding()
                
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .padding(.horizontal)
                
                TextField("Mobile Number", text: $mobileNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding(.horizontal)
                
                TextField("Consent Handle ID", text: $consentHandleId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                                
                if showOtpField {
                    TextField("Enter OTP", text: $otp)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .padding(.horizontal)
                    
                    HStack(spacing: 20) {
                        Button("Retry Login") {
                            performLogin()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRetryingLogin)
                        
                        Button("Verify OTP") {
                            verifyOtp()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Button("Login") {
                        performLogin()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRetryingLogin)
                }
                
                NavigationLink(destination: Dashboard(), isActive: $navigateToDashboard) {
                    EmptyView()
                }
            }
            .padding()
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
            .onAppear {
                initializeSDK()
            }
        }
    }
    
    private func initializeSDK() {
        finvuManager.initializeWith(config: finvuClientConfig)
        finvuManager.connect { error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = "Connection failed: \(error.localizedDescription)"
                    showError = true
                    return
                }
                print("Connected successfully")
            }
        }
    }
    
    private func performLogin() {
        guard !username.isEmpty && !mobileNumber.isEmpty && !consentHandleId.isEmpty else {
            errorMessage = "Please enter username and mobile number"
            showError = true
            return
        }
        
        isRetryingLogin = true
        
        finvuManager.loginWith(username: username,
                               mobileNumber: mobileNumber,
                               consentHandleId: consentHandleId) { response, error in
            DispatchQueue.main.async {
                isRetryingLogin = false
                
                if let error = error {
                    print("Login error: \(error.localizedDescription)")
                    
                    // Check if it's error code 1002 and we haven't retried yet
                    if error.code == 1002 && !hasRetriedOnce {
                        print("SNA failed with error 1002, retrying login automatically...")
                        hasRetriedOnce = true
                        isRetryingLogin = true
                        
                        // Call finvuManager.login directly (no recursion)
                        finvuManager.loginWith(username: username,
                                               mobileNumber: mobileNumber,
                                               consentHandleId: consentHandleId) { retryResponse, retryError in
                            DispatchQueue.main.async {
                                isRetryingLogin = false
                                handleLoginResponse(response: retryResponse, error: retryError)
                            }
                        }
                        return
                    }
                    
                    // Show error if it's not 1002 or we've already retried
                    errorMessage = error.localizedDescription
                    showError = true
                    return
                }
                
                handleLoginResponse(response: response, error: nil)
            }
        }
    }
    
    private func handleLoginResponse(response: LoginOtpReference?, error: NSError?) {
        if let error = error {
            print("Login error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
            return
        }
        
        if let reference = response?.reference, let authType = response?.authType {
            print("Login successful - authType: \(String(describing: authType))")
            
            otpReference = reference
            
            if authType == "SNA", let token = response?.snaToken, !token.isEmpty {
                print("SNA Authentication successful, auto-verifying with token")
                otp = token
                verifyOtp()
                return
            } else {
                print("OTP mode - showing OTP field")
                showOtpField = true
            }
        }
    }
    
    private func verifyOtp() {
        guard let reference = otpReference, !otp.isEmpty else {
            errorMessage = "Please enter OTP"
            showError = true
            return
        }
        
        finvuManager.verifyLoginOtp(otp: otp, otpReference: reference) { response, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = error.localizedDescription
                    showError = true
                    return
                }
                
                // Store data and navigate to dashboard
                UserDefaults.standard.set(mobileNumber, forKey: "mobileNumber")
                UserDefaults.standard.set(username, forKey: "username")
                UserDefaults.standard.set(consentHandleId, forKey: "consentHandleId")
                
                navigateToDashboard = true
            }
        }
    }
}

final class FinvuClientConfig: FinvuConfig {
    var finvuSnaAuthConfig: FinvuSnaAuthConfig?
    
    var finvuEndpoint: URL
    var certificatePins: [String]?
    
    init(finvuEndpoint: URL, certificatePins: [String]?, finvuSnaAuthConfig : FinvuSnaAuthConfig?) {
        self.finvuEndpoint = finvuEndpoint
        self.certificatePins = certificatePins
        self.finvuSnaAuthConfig = finvuSnaAuthConfig
    }
}

#Preview {
    LoginView()
}
