import Foundation
import SwiftUI
import FinvuSDK

struct ConsentsHomeView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State var linkedAccounts = [LinkedAccountDetailsInfo]()
    @State private var consentDetailList: [String: ConsentRequestDetailInfo] = [:] // HashMap for consent details
    @State private var showApprovalDialog = false
    @State private var showDenyConfirmation = false
    @State private var selectedAccounts: Set<LinkedAccountDetailsInfo> = []
    @State private var selectedConsentDetail: ConsentRequestDetailInfo? // To hold the selected consent detail
    let finvuManager = FinvuManager.shared
    private let dateFormatter = DateFormatter()
    
    var body: some View {
        ScrollView{
            VStack {
                // Linked Accounts Section
                Text("Select Linked Accounts")
                    .font(.headline)
                ForEach(linkedAccounts, id: \.accountReferenceNumber) { account in
                    HStack {
                        Text(account.maskedAccountNumber)
                        Spacer()
                        Image(systemName: selectedAccounts.contains(account) ? "checkmark.square.fill" : "square")
                            .onTapGesture {
                                toggle(account: account)
                            }
                    }
                    .padding() // Add padding for better spacing
                    .background(Color.white) // Optional: Add background color for better visibility
                    .cornerRadius(8) // Optional: Add corner radius for rounded corners
                    .shadow(radius: 1) // Optional: Add shadow for depth
                }
                
                Divider()
                
                // Buttons Section
                HStack {
                    Button("Approve") {
                        // Set the flag to true to show the alert dialog
                        showApprovalDialog = true
                    }
                    .buttonStyle(.borderedProminent)
                    .alert(isPresented: $showApprovalDialog) {
                        Alert(
                            title: Text("Approve Consent"),
                            message: Text("Do you want to split consents?"),
                            primaryButton: .default(Text("Split")) {
                                print("Split option selected")
                                splitConsentFlow()
                            },
                            secondaryButton: .default(Text("Multiple")) {
                                print("Multiple option selected")
                                multiConsentFlow()
                            }
                        )
                    }
                    
                    Button("Deny") {
                        showDenyConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .alert(isPresented: $showDenyConfirmation) {
                        Alert(title: Text("Deny Consent"),
                              message: Text("Are you sure you want to deny the consent?"),
                              primaryButton: .destructive(Text("Deny")) {
                            denyConsent()
                        },
                              secondaryButton: .cancel())
                    }
                }
                .padding()
                
                // Consent Details Section
                if let consentDetail = selectedConsentDetail {
                    ConsentDetailView(consentDetail: consentDetail)
                        .padding()
                }
            }
            .onAppear {
                fetchLinkedAccounts()
                LoginView.consentHandleIds.forEach { consentHandleId in
                    getConsentDetails(consentHandleId: consentHandleId)
                }
            }
        }
    }
    
    private func fetchLinkedAccounts() {
        finvuManager.fetchLinkedAccounts { result, error in
            
            if let error = error {
                let errorCode = error.errorCode
                let errorMessage = error.errorMessage
                let localized = error.localizedDescription
                print("FinvuManager.fetchLinkedAccounts - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                return
            }
            
            linkedAccounts = result?.linkedAccounts ?? []
        }
    }
    
    private func getConsentDetails(consentHandleId: String) {
        finvuManager.getConsentRequestDetails(consentHandleId: consentHandleId) { response, error in
            if let error = error {
                let errorCode = error.errorCode
                let errorMessage = error.errorMessage
                let localized = error.localizedDescription
                print("FinvuManager.getConsentRequestDetails - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                return
            }
            
            // Ensure response is valid
            guard let response = response else {
                print("Invalid response received.")
                return
            }
            
            // Use the existing model to create a ConsentRequestDetailInfo instance
            let consentRequestDetail = ConsentRequestDetailInfo(
                consentId: response.detail.consentId,
                consentHandle: response.detail.consentHandle,
                statusLastUpdateTimestamp: nil, // You can set this value if needed
                financialInformationUser: FinancialInformationEntityInfo(
                    id: response.detail.financialInformationUser.id,
                    name: response.detail.financialInformationUser.name
                ),
                consentPurposeInfo: ConsentPurposeInfo(
                    code: response.detail.consentPurposeInfo.code,
                    text: response.detail.consentPurposeInfo.text
                ),
                consentDisplayDescriptions: response.detail.consentDisplayDescriptions,
                consentDateTimeRange: DateTimeRange(
                    from: response.detail.consentDateTimeRange.from,
                    to: response.detail.consentDateTimeRange.to
                ),
                dataDateTimeRange: DateTimeRange(
                    from: response.detail.dataDateTimeRange.from,
                    to: response.detail.dataDateTimeRange.to
                ),
                consentDataLifePeriod: ConsentDataLifePeriod(
                    unit: response.detail.consentDataLifePeriod.unit,
                    value: response.detail.consentDataLifePeriod.value
                ),
                consentDataFrequency: ConsentDataFrequency(
                    unit: response.detail.consentDataFrequency.unit,
                    value: response.detail.consentDataFrequency.value
                ),
                fiTypes: response.detail.fiTypes
            )
            
            consentDetailList[consentHandleId] = consentRequestDetail
            
            if consentHandleId == LoginView.consentHandleIds[0] {
                selectedConsentDetail = consentRequestDetail
            }
        }
    }
    
    
    
    private func toggle(account: LinkedAccountDetailsInfo) {
        if selectedAccounts.contains(account) {
            selectedAccounts.remove(account)
        } else {
            selectedAccounts.insert(account)
        }
    }
    
    private func splitConsentFlow() {
        selectedAccounts.enumerated().forEach { index, account in
            finvuManager.approveAccountConsentRequest(consentDetail: consentDetailList[LoginView.consentHandleIds[index]]!,
                                                      linkedAccounts: [account]) { result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        let errorCode = error.errorCode
                        let errorMessage = error.errorMessage
                        let localized = error.localizedDescription
                        print("FinvuManager.approveAccountConsentRequest - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                        return
                    }
                    
                    if index == selectedAccounts.count - 1 {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func multiConsentFlow() {
        finvuManager.approveAccountConsentRequest(consentDetail: consentDetailList[LoginView.consentHandleIds[0]]!,
                                                  linkedAccounts: Array(selectedAccounts)) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    let errorCode = error.errorCode
                    let errorMessage = error.errorMessage
                    let localized = error.localizedDescription
                    print("FinvuManager.approveAccountConsentRequest - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                    return
                }
                // navigate back to previous view
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    private func denyConsent() {
        finvuManager.denyAccountConsentRequest(consentDetail: consentDetailList[LoginView.consentHandleIds[0]]!){ result, error in
            if let error = error {
                let errorCode = error.errorCode
                let errorMessage = error.errorMessage
                let localized = error.localizedDescription
                print("FinvuManager.denyAccountConsentRequest - Error Code: \(errorCode ?? "nil"), Error Message: \(errorMessage ?? "nil"), Localized: \(localized)")
                return
            }
            // navigate back to previous view
            presentationMode.wrappedValue.dismiss()
            
        }
    }}

struct ConsentDetailView: View {
    var consentDetail: ConsentRequestDetailInfo
    
    var body: some View {
        VStack(alignment: .leading) {
            
            Text("Consent Requested")
                .font(.headline)
                .padding(.vertical, 20)
            
            VStack(alignment: .leading) {
                Text("Consent Purpose:")
                    .font(.headline)
                
                Text("\(consentDetail.consentPurposeInfo.code) - \(consentDetail.consentPurposeInfo.text)")
                    .font(.body)
            }
            .padding(.bottom, 5)
            
            HStack {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        Text("Data Fetch Freq. :")
                            .font(.headline)
                        Text(String(format: "%.1f %@", consentDetail.consentDataFrequency.value, consentDetail.consentDataFrequency.unit))
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.bottom, 5)
                    
                    VStack(alignment: .leading) {
                        Text("Data Fetch From:")
                            .font(.headline)
                        Text(formatDate(consentDetail.dataDateTimeRange.from))
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.bottom, 5)
                    
                    VStack(alignment: .leading) {
                        Text("Consent Requested On:")
                            .font(.headline)
                        Text(formatDate(consentDetail.consentDateTimeRange.from))
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .padding(.trailing)
                
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        Text("Data Use:")
                            .font(.headline)
                        Text(String(format: "%.1f %@", consentDetail.consentDataLifePeriod.value, consentDetail.consentDataLifePeriod.unit))
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.bottom, 5)
                    
                    VStack(alignment: .leading) {
                        Text("Data Fetch Until:")
                            .font(.headline)
                        Text(formatDate(consentDetail.dataDateTimeRange.to))
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.bottom, 5)
                    
                    VStack(alignment: .leading) {
                        Text("Consent Expires On:")
                            .font(.headline)
                        Text(formatDate(consentDetail.consentDateTimeRange.to))
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .padding(.vertical, 5)
            
            Text("Account Information:")
                .font(.headline)
            
            Text(consentDetail.consentDisplayDescriptions.joined(separator: ", "))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 5)
            
            Text("Account Types Requested:")
                .font(.headline)
            
            Text(consentDetail.fiTypes?.joined(separator: ", ") ?? "N/A")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
