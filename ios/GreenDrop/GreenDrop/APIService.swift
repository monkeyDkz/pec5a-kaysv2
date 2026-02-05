import Foundation

// MARK: - API Configuration
struct APIConfig {
    // Change this to your production URL when deploying
    #if DEBUG
    // Use your Mac's local IP (visible in `pnpm dev` output under "Network:")
    static let baseURL = "http://192.168.1.141:3000/api"
    #else
    static let baseURL = "https://pec5a.vercel.app/api"
    #endif

    static let timeout: TimeInterval = 30
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String?)
    case networkError(Error)
    case unauthorized
    case forbidden
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide"
        case .noData:
            return "Aucune donnée reçue"
        case .decodingError(let error):
            return "Erreur de décodage: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return message ?? "Erreur serveur (\(code))"
        case .networkError(let error):
            return "Erreur réseau: \(error.localizedDescription)"
        case .unauthorized:
            return "Non autorisé - veuillez vous reconnecter"
        case .forbidden:
            return "Accès refusé"
        case .notFound:
            return "Ressource non trouvée"
        }
    }
}

// MARK: - API Response
struct APIResponse<T: Decodable>: Decodable {
    let data: T?
    let error: String?
    let message: String?
}

// MARK: - API Service
@MainActor
class APIService {
    static let shared = APIService()

    private let session: URLSession
    private var authToken: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.timeoutIntervalForResource = APIConfig.timeout
        self.session = URLSession(configuration: config)
    }

    // MARK: - Auth Token
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    // MARK: - Generic Request
    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        queryParams: [String: String]? = nil
    ) async throws -> T {
        // Build URL with query params
        var urlString = "\(APIConfig.baseURL)\(endpoint)"

        if let queryParams = queryParams, !queryParams.isEmpty {
            let queryString = queryParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add body for POST/PATCH/PUT
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.noData
            }

            // Handle HTTP errors
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                throw APIError.unauthorized
            case 403:
                throw APIError.forbidden
            case 404:
                throw APIError.notFound
            default:
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)["message"]
                throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }

            // Decode response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Try ISO8601 first
                let iso8601Formatter = ISO8601DateFormatter()
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }

                // Try without fractional seconds
                iso8601Formatter.formatOptions = [.withInternetDateTime]
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }

                // Try timestamp
                if let timestamp = Double(dateString) {
                    return Date(timeIntervalSince1970: timestamp / 1000)
                }

                return Date()
            }

            return try decoder.decode(T.self, from: data)

        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Shops
    func getShops(category: String? = nil, search: String? = nil, lat: Double? = nil, lng: Double? = nil) async throws -> [Shop] {
        var params: [String: String] = [:]
        if let category = category { params["category"] = category }
        if let search = search { params["search"] = search }
        if let lat = lat { params["lat"] = String(lat) }
        if let lng = lng { params["lng"] = String(lng) }

        return try await request(endpoint: "/shops", queryParams: params.isEmpty ? nil : params)
    }

    func getProducts(shopId: String) async throws -> [Product] {
        return try await request(endpoint: "/shops/\(shopId)/products")
    }

    // MARK: - Orders
    func createOrder(_ order: CreateOrderRequest) async throws -> Order {
        let body: [String: Any] = [
            "shopId": order.shopId,
            "items": order.items.map { [
                "productId": $0.productId,
                "productName": $0.productName,
                "price": $0.price,
                "quantity": $0.quantity
            ]},
            "deliveryAddress": order.deliveryAddress,
            "deliveryLatitude": order.deliveryLatitude,
            "deliveryLongitude": order.deliveryLongitude,
            "notes": order.notes ?? ""
        ]

        return try await request(endpoint: "/orders", method: "POST", body: body)
    }

    func getMyOrders(status: String? = nil) async throws -> [Order] {
        var params: [String: String]? = nil
        if let status = status {
            params = ["status": status]
        }
        return try await request(endpoint: "/orders/my", queryParams: params)
    }

    func getOrder(id: String) async throws -> Order {
        return try await request(endpoint: "/orders/\(id)")
    }

    func updateOrderStatus(orderId: String, status: String, driverId: String? = nil) async throws -> Order {
        var body: [String: Any] = ["status": status]
        if let driverId = driverId {
            body["driverId"] = driverId
        }
        return try await request(endpoint: "/orders/\(orderId)", method: "PATCH", body: body)
    }

    // MARK: - Driver
    func updateDriverLocation(latitude: Double, longitude: Double, heading: Double? = nil, speed: Double? = nil) async throws -> DriverLocationResponse {
        var body: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]
        if let heading = heading { body["heading"] = heading }
        if let speed = speed { body["speed"] = speed }

        return try await request(endpoint: "/drivers/location", method: "POST", body: body)
    }

    func updateDriverStatus(status: String) async throws -> DriverStatusResponse {
        let body: [String: Any] = ["status": status]
        return try await request(endpoint: "/drivers/status", method: "POST", body: body)
    }

    // MARK: - Notifications
    func registerFCMToken(token: String, deviceId: String? = nil) async throws -> EmptyResponse {
        var body: [String: Any] = ["token": token]
        if let deviceId = deviceId { body["deviceId"] = deviceId }
        return try await request(endpoint: "/notifications", method: "PUT", body: body)
    }

    // MARK: - Upload
    func uploadFile(base64Data: String, mimeType: String, orderId: String? = nil, fileType: String = "delivery_photo") async throws -> UploadResponse {
        var body: [String: Any] = [
            "base64Data": base64Data,
            "mimeType": mimeType,
            "fileType": fileType
        ]
        if let orderId = orderId { body["orderId"] = orderId }

        return try await request(endpoint: "/upload", method: "POST", body: body)
    }
}

// MARK: - Request/Response Models
struct CreateOrderRequest {
    let shopId: String
    let items: [CreateOrderItem]
    let deliveryAddress: String
    let deliveryLatitude: Double
    let deliveryLongitude: Double
    let notes: String?
}

struct CreateOrderItem {
    let productId: String
    let productName: String
    let price: Double
    let quantity: Int
}

struct DriverLocationResponse: Decodable {
    let success: Bool
    let message: String?
}

struct DriverStatusResponse: Decodable {
    let success: Bool
    let status: String?
    let message: String?
}

struct UploadResponse: Decodable {
    let success: Bool
    let url: String?
    let message: String?
}

struct EmptyResponse: Decodable {
    let success: Bool?
    let message: String?
}
