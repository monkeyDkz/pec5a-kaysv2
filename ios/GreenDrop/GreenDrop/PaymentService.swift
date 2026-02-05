import SwiftUI
import Foundation
import FirebaseAuth
import StripePaymentSheet

// MARK: - Payment Service
@MainActor
final class PaymentService: ObservableObject {
    static let shared = PaymentService()

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var paymentReady = false

    private(set) var clientSecret: String?
    private(set) var ephemeralKey: String?
    private(set) var customerId: String?
    private(set) var paymentIntentId: String?
    private(set) var publishableKey: String?

    private init() {}

    struct PaymentIntentResponse: Codable {
        let clientSecret: String
        let ephemeralKey: String
        let customerId: String
        let paymentIntentId: String
        let publishableKey: String
        let paymentStatus: String?
    }

    /// Whether the last payment was auto-confirmed server-side (saved card)
    var wasAutoConfirmed: Bool {
        return paymentStatus == "succeeded" || paymentStatus == "requires_capture"
    }

    private(set) var paymentStatus: String?

    /// Prepares a payment by calling the backend to create a PaymentIntent
    func preparePayment(amount: Double, shopId: String, useSavedCard: Bool = false) async throws -> PaymentIntentResponse {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let url = URL(string: "\(APIConfig.baseURL)/payments/create-intent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token
        do {
            if let token = try await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("[Payment] Auth token set: \(token.prefix(20))...")
            } else {
                print("[Payment] No current user, skipping auth token")
            }
        } catch {
            print("[Payment] Failed to get auth token: \(error)")
        }

        let body: [String: Any] = [
            "amount": amount,
            "currency": "eur",
            "shopId": shopId,
            "useSavedCard": useSavedCard
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = APIConfig.timeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PaymentError.serverError(statusCode)
        }

        let paymentResponse = try JSONDecoder().decode(PaymentIntentResponse.self, from: data)

        self.clientSecret = paymentResponse.clientSecret
        self.ephemeralKey = paymentResponse.ephemeralKey
        self.customerId = paymentResponse.customerId
        self.paymentIntentId = paymentResponse.paymentIntentId
        self.publishableKey = paymentResponse.publishableKey
        self.paymentStatus = paymentResponse.paymentStatus
        self.paymentReady = true

        return paymentResponse
    }

    /// Configures a Stripe PaymentSheet from a PaymentIntentResponse
    func configurePaymentSheet(from response: PaymentIntentResponse) -> PaymentSheet {
        STPAPIClient.shared.publishableKey = response.publishableKey

        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "GreenDrop"
        configuration.customer = .init(id: response.customerId, ephemeralKeySecret: response.ephemeralKey)
        configuration.allowsDelayedPaymentMethods = false

        return PaymentSheet(paymentIntentClientSecret: response.clientSecret, configuration: configuration)
    }

    /// Requests Stripe Connect onboarding URL for a merchant
    func getOnboardingURL(shopId: String, prefill: OnboardingPrefill? = nil) async throws -> String {
        let url = URL(string: "\(APIConfig.baseURL)/payments/connect/onboard")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = try? await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: String] = ["shopId": shopId]
        if let prefill = prefill {
            if !prefill.firstName.isEmpty { body["firstName"] = prefill.firstName }
            if !prefill.lastName.isEmpty { body["lastName"] = prefill.lastName }
            if !prefill.phone.isEmpty { body["phone"] = prefill.phone }
            if !prefill.address.isEmpty { body["address"] = prefill.address }
            if !prefill.city.isEmpty { body["city"] = prefill.city }
            if !prefill.postalCode.isEmpty { body["postalCode"] = prefill.postalCode }
            if !prefill.iban.isEmpty { body["iban"] = prefill.iban }
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = APIConfig.timeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw PaymentError.onboardingFailed
        }

        struct OnboardingResponse: Codable {
            let url: String
            let accountId: String
        }

        let onboardingResponse = try JSONDecoder().decode(OnboardingResponse.self, from: data)
        return onboardingResponse.url
    }

    /// Gets the Stripe Express dashboard URL for a merchant
    func getDashboardURL(shopId: String) async throws -> String {
        let url = URL(string: "\(APIConfig.baseURL)/payments/connect/dashboard")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = try? await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = ["shopId": shopId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = APIConfig.timeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw PaymentError.dashboardFailed
        }

        struct DashboardResponse: Codable {
            let url: String
        }

        let dashboardResponse = try JSONDecoder().decode(DashboardResponse.self, from: data)
        return dashboardResponse.url
    }

    // MARK: - Driver Stripe Connect

    /// Requests Stripe Connect onboarding URL for a driver
    func getDriverOnboardingURL(prefill: OnboardingPrefill? = nil) async throws -> String {
        let url = URL(string: "\(APIConfig.baseURL)/payments/connect/driver-onboard")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = try? await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: String] = [:]
        if let prefill = prefill {
            if !prefill.firstName.isEmpty { body["firstName"] = prefill.firstName }
            if !prefill.lastName.isEmpty { body["lastName"] = prefill.lastName }
            if !prefill.phone.isEmpty { body["phone"] = prefill.phone }
            if !prefill.address.isEmpty { body["address"] = prefill.address }
            if !prefill.city.isEmpty { body["city"] = prefill.city }
            if !prefill.postalCode.isEmpty { body["postalCode"] = prefill.postalCode }
            if !prefill.iban.isEmpty { body["iban"] = prefill.iban }
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = APIConfig.timeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw PaymentError.onboardingFailed
        }

        struct OnboardingResponse: Codable {
            let url: String
            let accountId: String
        }

        let onboardingResponse = try JSONDecoder().decode(OnboardingResponse.self, from: data)
        return onboardingResponse.url
    }

    /// Gets the Stripe Express dashboard URL for a driver
    func getDriverDashboardURL() async throws -> String {
        let url = URL(string: "\(APIConfig.baseURL)/payments/connect/driver-dashboard")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = try? await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: [:] as [String: String])
        request.timeoutInterval = APIConfig.timeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw PaymentError.dashboardFailed
        }

        struct DashboardResponse: Codable {
            let url: String
        }

        let dashboardResponse = try JSONDecoder().decode(DashboardResponse.self, from: data)
        return dashboardResponse.url
    }

    func reset() {
        clientSecret = nil
        ephemeralKey = nil
        customerId = nil
        paymentIntentId = nil
        publishableKey = nil
        paymentStatus = nil
        paymentReady = false
        errorMessage = nil
    }

    private func getAuthToken() async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            if let user = Auth.auth().currentUser {
                user.getIDToken { token, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: token)
                    }
                }
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
}

// MARK: - Onboarding Prefill Data
struct OnboardingPrefill {
    var firstName: String = ""
    var lastName: String = ""
    var phone: String = ""
    var address: String = ""
    var city: String = ""
    var postalCode: String = ""
    var iban: String = ""
}

// MARK: - Payment Errors
enum PaymentError: LocalizedError {
    case serverError(Int)
    case onboardingFailed
    case dashboardFailed
    case paymentCancelled
    case paymentFailed(String)

    var errorDescription: String? {
        switch self {
        case .serverError(let code):
            return "Erreur serveur (\(code)). Veuillez réessayer."
        case .onboardingFailed:
            return "Impossible de configurer les paiements. Veuillez réessayer."
        case .dashboardFailed:
            return "Impossible d'ouvrir le tableau de bord. Veuillez réessayer."
        case .paymentCancelled:
            return "Paiement annulé."
        case .paymentFailed(let message):
            return "Paiement échoué: \(message)"
        }
    }
}
