import Foundation
import SwiftUI
import FinvuSDK

struct Dashboard: View {
    @State var linkedAccountsResponse: LinkedAccountsResponse?
    @State private var navigateToProcessConsent = false
    @State private var navigateToAddAccount = false
    @State private var consentId: String = "d5ec2f85-9313-4b1c-b97a-d110d073e18b"
    @State private var showAlert: Bool = false
    private var finvuManager = FinvuManager.shared
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    init(linkedAccountsResponse: LinkedAccountsResponse? = nil) {
            self.linkedAccountsResponse = linkedAccountsResponse
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Linked Accounts Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Linked Accounts")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    // Fixed height ScrollView for linked accounts
                    ScrollView {
                        if let linkedAccounts = linkedAccountsResponse?.linkedAccounts {
                            VStack(spacing: 8) {
                                ForEach(linkedAccounts, id: \.linkReferenceNumber) { account in
                                    LinkedAccountRow(account: account)
                                        .padding(.horizontal, 16) // Add horizontal margins
                                }
                            }
                            .padding(.vertical, 16) // Add vertical margins
                        } else {
                            Text("No linked accounts found")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(height: 300) // Fixed height for the accounts list
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                HStack {
                    Text("Add New Account")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    NavigationLink(destination: AccountDiscoveryView()) {
                                    Text("Add")
                    }
                    .buttonStyle(.bordered)
                }
                
                // Process Consent Button
                NavigationLink(destination: ConsentsHomeView()) {
                    Text("Process Consent")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Text("Revoke Consent")
                TextField("Consent ID", text: $consentId)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)

                            Button(action: {
                                finvuManager.revokeConsent(consentId: consentId, accountAggregator: nil, fipDetails: nil){ error in
                                    if let error = error {
                                        let errorCode = error.errorCode
                                        let errorMessage = error.errorMessage
                                        let localized = error.localizedDescription
                                        print("FinvuManager.revokeConsent - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                                        return
                                    }
                                    showAlert = true
                                }
                            }) {
                                Text("Submit")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.horizontal)
            }
            .padding(16)
        }
        .onAppear {
            refreshLinkedAccounts()
        }.alert(isPresented: $showAlert) {
            Alert(
                title: Text("Consent Revoked"),
                message: Text("The consent has been successfully revoked."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    func refreshLinkedAccounts() {
        finvuManager.fetchLinkedAccounts { result, error in
            if let error = error {
                let errorCode = error.errorCode
                let errorMessage = error.errorMessage
                let localized = error.localizedDescription
                print("FinvuManager.fetchLinkedAccounts - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                return
            }
            
            self.linkedAccountsResponse = result
        }
    }
}
// Separate view for linked account row
struct LinkedAccountRow: View {
    let account: LinkedAccountDetailsInfo
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.fipName)
                    .font(.subheadline)
                Text("\(account.maskedAccountNumber) (\(account.accountType))")
                    .font(.footnote)
                if let lastUpdateTime = account.linkedAccountUpdateTimestamp {
                    Text("last update on \(dateFormatter.string(from: lastUpdateTime))")
                        .font(.footnote)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}


#Preview {
    Dashboard()
}
