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
    
    // Constants
    static let consentHandleIds = [
            "52d7c312-1bf6-4747-acb5-50f2dd6d5a2g",
    ]
    
    init() {
        let finvuUrl = URL(string: "wss://webvwdev.finvu.in/consentapi")!
        finvuClientConfig = FinvuClientConfig(
            finvuEndpoint: finvuUrl,
            certificatePins: []
        )
        // Initialize consentHandleId with first item
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
                    
                    // Both buttons in a horizontal stack
                    HStack(spacing: 20) {
                        Button("Login") {
                            login()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Verify OTP") {
                            verifyOtp()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Button("Login") {
                        login()
                    }
                    .buttonStyle(.borderedProminent)
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
    
    private func login() {
        guard !username.isEmpty && !mobileNumber.isEmpty && !consentHandleId.isEmpty else {
            errorMessage = "Please enter username and mobile number"
            showError = true
            return
        }
        
        finvuManager.loginWith(username: username,
                               mobileNumber: mobileNumber,
                               consentHandleId: consentHandleId) { response, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = error.localizedDescription
                    showError = true
                    return
                }
                
                if let reference = response?.reference {
                    otpReference = reference
                    showOtpField = true
                }
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
                // Store necessary data and navigate to dashboard
                UserDefaults.standard.set(mobileNumber, forKey: "mobileNumber")
                UserDefaults.standard.set(username, forKey: "username")
                UserDefaults.standard.set(consentHandleId, forKey: "consentHandleId")
                
                navigateToDashboard = true
            }
        }
    }
}

final class FinvuClientConfig: FinvuConfig {
    var finvuEndpoint: URL
    var certificatePins: [String]?
    
    init(finvuEndpoint: URL, certificatePins: [String]?) {
        self.finvuEndpoint = finvuEndpoint
        self.certificatePins = certificatePins
    }
}

#Preview {
    LoginView()
}
