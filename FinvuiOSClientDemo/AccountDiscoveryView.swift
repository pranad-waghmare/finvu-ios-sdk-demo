import Foundation
import FinvuSDK
import SwiftUI

// View to list available FIPs
struct AccountDiscoveryView: View {
    @State var results = [FIPInfo]()
    let finvuManager = FinvuManager.shared
    
    var body: some View {
        List(results, id: \.fipId) { item in
            NavigationLink(destination: FIPDetailsView(fipInfo: item)) {
                Text(item.productName ?? "")
            }
        }
        .navigationTitle("Available FIPs")
        .onAppear {
            finvuManager.fipsAllFIPOptions { response, error in
                if let error = error {
                    let errorCode = error.errorCode
                    let errorMessage = error.errorMessage
                    let localized = error.localizedDescription
                    print("FinvuManager.fipsAllFIPOptions - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                    return
                }
                results = response?.searchOptions ?? []
            }
        }
    }
}

// View to show FIP details, handle account discovery, and link accounts
struct FIPDetailsView: View {
    @State var fipDetails: FIPDetails?
    @State var entityInfo: EntityInfo?
    @State var addedIdentifiers = [TypeIdentifierInfo]()
    @State var showDiscoveredAccounts = false
    @State var discoveredAccountsResponse: DiscoveredAccountsResponse?
    @State var linkedAccountIdentifiers = Set<String>()
    
    @State private var identifierCategory = ""
    @State private var identifierType = ""
    @State private var identifierValue = ""
    
    let fipInfo: FIPInfo
    let finvuManager = FinvuManager.shared
    
    var body: some View {
        VStack {
            Text("FIP ID = \(fipInfo.fipId)")
            
            if let entityInfo = entityInfo {
                Text("Entity Name = \(entityInfo.entityName)")
                if let logoUrl = entityInfo.entityIconUri {
                    AsyncImage(url: URL(string: logoUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        ProgressView()
                    }
                }
            }
            
            Button("Start discovery") {
                let identifiers = addedIdentifiers
                finvuManager.discoverAccounts(fipId: fipDetails!.fipId, fiTypes: fipInfo.fipFitypes, identifiers: identifiers) { response, error in
                    if let error = error {
                        let errorCode = error.errorCode
                        let errorMessage = error.errorMessage
                        let localized = error.localizedDescription
                        print("FinvuManager.discoverAccounts - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                        return
                    }
                    discoveredAccountsResponse = response
                    showDiscoveredAccounts = true
                }
            }
            
            if showDiscoveredAccounts {
                NavigationLink(destination: AccountDiscoveryResultView(discoveredAccountsResponse: discoveredAccountsResponse!,
                                                                       fipDetails: fipDetails!,
                                                                       linkedAccountIdentifiers: linkedAccountIdentifiers)) {
                    Text("Accounts found")
                }
            }
            
            List(fipDetails?.typeIdentifiers ?? [], id: \.fiType) { item in
                DisclosureGroup(item.fiType) {
                    ForEach(item.identifiers, id: \.type) { identifier in
                        HStack {
                            Text("\(identifier.type) \(identifier.category)")
                        }
                    }
                }
            }
            
            Text("Add Identifiers")
            TextField("Category", text: $identifierCategory)
            TextField("Type", text: $identifierType)
            TextField("Value", text: $identifierValue)
            Button("Add") {
                addedIdentifiers.append(TypeIdentifierInfo(category: identifierCategory, type: identifierType, value: identifierValue))
                identifierCategory = ""
                identifierType = ""
                identifierValue = ""
            }
            
            Text("Added Identifiers")
            ForEach(addedIdentifiers, id: \.type) { item in
                Text("\(item.type) \(item.category) \(item.value)")
            }
        }
        .onAppear {
            // Fetch FIP details and entity info
            finvuManager.fetchFIPDetails(fipId: fipInfo.fipId) { details, error in
                if let error = error {
                    let errorCode = error.errorCode
                    let errorMessage = error.errorMessage
                    let localized = error.localizedDescription
                    print("FinvuManager.fetchFIPDetails - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                    return
                }
                fipDetails = details
            }
            
            finvuManager.getEntityInfo(entityId: fipInfo.fipId, entityType: "FIP") { entityInfo, error in
                if let error = error {
                    let errorCode = error.errorCode
                    let errorMessage = error.errorMessage
                    let localized = error.localizedDescription
                    print("FinvuManager.getEntityInfo - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                    return
                }
                self.entityInfo = entityInfo
            }
            
            // Fetch linked accounts
            finvuManager.fetchLinkedAccounts { result, error in
                if let error = error {
                    let errorCode = error.errorCode
                    let errorMessage = error.errorMessage
                    let localized = error.localizedDescription
                    print("FinvuManager.fetchLinkedAccounts - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                    return
                }
                linkedAccountIdentifiers = Set(result?.linkedAccounts?.map { $0.accountReferenceNumber } ?? [])
            }
        }
    }
}

struct AccountDiscoveryResultView: View {
    let finvuManager = FinvuManager.shared
    let discoveredAccountsResponse: DiscoveredAccountsResponse
    let fipDetails: FIPDetails
    let linkedAccountIdentifiers: Set<String>
    @State private var selectedAccountRefNumbers = Set<String>()
    @State private var linkingRequestReferenceNumber: AccountLinkingRequestReference?
    @State private var otp = ""
    @State private var showErrorDialog = false
    @State private var errorMessage = ""
    @State var accountLinkingInfo : ConfirmAccountLinkingInfo?
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        VStack {
            Button("Link selected accounts") {
                let selectedAccounts = discoveredAccountsResponse.accounts.filter {
                    selectedAccountRefNumbers.contains($0.accountReferenceNumber)
                }
                finvuManager.linkAccounts(fipDetails: fipDetails, accounts: selectedAccounts) { result, error in
                    if let error = error {
                        let errorCode = error.errorCode
                        let errorMessage = error.errorMessage
                        let localized = error.localizedDescription
                        print("FinvuManager.linkAccounts - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                        self.errorMessage = "Error linking accounts: \(localized)"
                        self.showErrorDialog = true
                        return
                    }
                    self.linkingRequestReferenceNumber = result
                }
            }
            .disabled(selectedAccountRefNumbers.isEmpty) // Disable button if no account is selected
            
            if let referenceNumber = linkingRequestReferenceNumber {
                TextField("Enter OTP", text: $otp)
                Button("Confirm") {
                    finvuManager.confirmAccountLinking(linkingReference: referenceNumber, otp: otp) { info, error in
                        DispatchQueue.main.async{
                            if let error = error {
                                let errorCode = error.errorCode
                                let errorMessage = error.errorMessage
                                let localized = error.localizedDescription
                                print("FinvuManager.confirmAccountLinking - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                                self.errorMessage = "Error confirming account linking: \(localized)"
                                self.showErrorDialog = true
                                return
                            }
                            accountLinkingInfo = info
                            print("Linked accounts = \(info.debugDescription)")
                            if(accountLinkingInfo  != nil){
                                presentationMode.wrappedValue.dismiss()
                                presentationMode.wrappedValue.dismiss()
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                }
                .disabled(otp.isEmpty) // Disable button if no account is selected
            }
            
            List(discoveredAccountsResponse.accounts, id: \.accountReferenceNumber) { account in
                HStack {
                    Text(account.maskedAccountNumber)
                    Spacer()
                    
                    // Only show the checkbox if the account is not already linked
                    if !linkedAccountIdentifiers.contains(account.accountReferenceNumber) {
                        Image(systemName: selectedAccountRefNumbers.contains(account.accountReferenceNumber) ? "checkmark.circle.fill" : "circle")
                            .onTapGesture {
                                toggle(accountRefNumber: account.accountReferenceNumber)
                            }
                    } else {
                        Text("Linked").foregroundStyle(.green) // Indicate that the account is already linked
                    }
                }
            }
        }
        .alert(isPresented: $showErrorDialog) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    func toggle(accountRefNumber: String) {
        if selectedAccountRefNumbers.contains(accountRefNumber) {
            selectedAccountRefNumbers.remove(accountRefNumber)
        } else {
            selectedAccountRefNumbers.insert(accountRefNumber)
        }
    }
}
