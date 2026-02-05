import Foundation
import CoreLocation

// MARK: - Shop
struct Shop: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var description: String
    var imageURL: String?
    var address: String
    var latitude: Double
    var longitude: Double
    var category: ShopCategory
    var rating: Double
    var reviewCount: Int
    var isOpen: Bool
    var deliveryFee: Double
    var minOrderAmount: Double
    var estimatedDeliveryTime: String
    var ownerId: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, imageURL, address, latitude, longitude
        case category, rating, reviewCount, isOpen, deliveryFee, minOrderAmount
        case estimatedDeliveryTime, ownerId
    }
}

enum ShopCategory: String, Codable, CaseIterable {
    case grocery = "grocery"
    case restaurant = "restaurant"
    case bakery = "bakery"
    case pharmacy = "pharmacy"
    case flowers = "flowers"
    case cbd = "cbd"
    case other = "other"

    var displayName: String {
        switch self {
        case .grocery: return "Epicerie"
        case .restaurant: return "Restaurant"
        case .bakery: return "Boulangerie"
        case .pharmacy: return "Pharmacie"
        case .flowers: return "Fleuriste"
        case .cbd: return "CBD Shop"
        case .other: return "Autre"
        }
    }

    var icon: String {
        switch self {
        case .grocery: return "cart.fill"
        case .restaurant: return "fork.knife"
        case .bakery: return "birthday.cake.fill"
        case .pharmacy: return "cross.case.fill"
        case .flowers: return "camera.macro"
        case .cbd: return "leaf.fill"
        case .other: return "bag.fill"
        }
    }
}

// MARK: - Product
struct Product: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var description: String
    var price: Double
    var imageURL: String?
    var category: String
    var shopId: String
    var isAvailable: Bool
    var stock: Int
    var isRestricted: Bool  // Age-restricted products (alcohol, tobacco, etc.)
    var minimumAge: Int?    // Required age (default 18 for alcohol)

    var formattedPrice: String {
        String(format: "%.2f €", price)
    }

    var requiresAgeVerification: Bool {
        isRestricted && (minimumAge ?? 18) >= 18
    }

    // CodingKeys with default values for backwards compatibility
    enum CodingKeys: String, CodingKey {
        case id, name, description, price, imageURL, category
        case shopId, isAvailable, stock, isRestricted, minimumAge
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        price = try container.decode(Double.self, forKey: .price)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        category = try container.decode(String.self, forKey: .category)
        shopId = try container.decode(String.self, forKey: .shopId)
        isAvailable = try container.decode(Bool.self, forKey: .isAvailable)
        stock = try container.decode(Int.self, forKey: .stock)
        isRestricted = try container.decodeIfPresent(Bool.self, forKey: .isRestricted) ?? false
        minimumAge = try container.decodeIfPresent(Int.self, forKey: .minimumAge)
    }

    init(id: String, name: String, description: String, price: Double, imageURL: String? = nil,
         category: String, shopId: String, isAvailable: Bool, stock: Int,
         isRestricted: Bool = false, minimumAge: Int? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.imageURL = imageURL
        self.category = category
        self.shopId = shopId
        self.isAvailable = isAvailable
        self.stock = stock
        self.isRestricted = isRestricted
        self.minimumAge = minimumAge
    }
}

// MARK: - Order
struct Order: Identifiable, Codable, Equatable {
    let id: String
    var userId: String
    var shopId: String
    var shopName: String
    var driverId: String?
    var items: [OrderItem]
    var status: OrderStatus
    var subtotal: Double
    var deliveryFee: Double
    var total: Double
    var deliveryAddress: String
    var deliveryLatitude: Double
    var deliveryLongitude: Double
    var createdAt: Date
    var updatedAt: Date
    var estimatedDelivery: Date?
    var notes: String?
    var paymentStatus: String?
    var paymentIntentId: String?

    var deliveryCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: deliveryLatitude, longitude: deliveryLongitude)
    }

    enum CodingKeys: String, CodingKey {
        case id, userId, shopId, shopName, driverId, items, status
        case subtotal, deliveryFee, total, deliveryAddress
        case deliveryLatitude, deliveryLongitude
        case createdAt, updatedAt, estimatedDelivery, notes
        case paymentStatus, paymentIntentId
    }
}

struct OrderItem: Identifiable, Codable, Equatable {
    let id: String
    var productId: String
    var productName: String
    var price: Double
    var quantity: Int

    var total: Double { price * Double(quantity) }
}

enum OrderStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case confirmed = "confirmed"
    case preparing = "preparing"
    case ready = "ready"
    case pickedUp = "picked_up"
    case delivering = "delivering"
    case delivered = "delivered"
    case cancelled = "cancelled"

    // Alternative values from backend
    case created = "created"
    case paid = "paid"
    case inTransit = "in_transit"

    var displayName: String {
        switch self {
        case .pending, .created: return "En attente"
        case .paid: return "Payée"
        case .confirmed: return "Confirmée"
        case .preparing: return "En préparation"
        case .ready: return "Prête"
        case .pickedUp: return "Récupérée"
        case .delivering, .inTransit: return "En livraison"
        case .delivered: return "Livrée"
        case .cancelled: return "Annulée"
        }
    }

    var icon: String {
        switch self {
        case .pending, .created: return "clock.fill"
        case .paid: return "creditcard.fill"
        case .confirmed: return "checkmark.circle.fill"
        case .preparing: return "flame.fill"
        case .ready: return "bag.fill.badge.checkmark"
        case .pickedUp: return "car.fill"
        case .delivering, .inTransit: return "bicycle"
        case .delivered: return "checkmark.seal.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .pending, .created: return "#F59E0B"
        case .paid: return "#10B981"
        case .confirmed: return "#3B82F6"
        case .preparing: return "#F97316"
        case .ready: return "#8B5CF6"
        case .pickedUp: return "#06B6D4"
        case .delivering, .inTransit: return "#22C55E"
        case .delivered: return "#10B981"
        case .cancelled: return "#EF4444"
        }
    }

    /// Returns true if the order is still active (not delivered or cancelled)
    var isActive: Bool {
        switch self {
        case .delivered, .cancelled:
            return false
        default:
            return true
        }
    }

    /// Progress value from 0 to 1 for tracking
    var progressValue: Double {
        switch self {
        case .pending, .created: return 0.1
        case .paid: return 0.2
        case .confirmed: return 0.3
        case .preparing: return 0.5
        case .ready: return 0.6
        case .pickedUp: return 0.7
        case .delivering, .inTransit: return 0.85
        case .delivered: return 1.0
        case .cancelled: return 0.0
        }
    }

    /// Step number for visual tracking (1-5)
    var stepNumber: Int {
        switch self {
        case .pending, .created, .paid: return 1
        case .confirmed: return 2
        case .preparing: return 3
        case .ready, .pickedUp: return 4
        case .delivering, .inTransit, .delivered: return 5
        case .cancelled: return 0
        }
    }
}

// MARK: - Delivery (for Driver)
struct Delivery: Identifiable, Codable, Equatable {
    let id: String
    var orderId: String
    var driverId: String?
    var shopName: String
    var shopAddress: String
    var shopLatitude: Double
    var shopLongitude: Double
    var customerName: String
    var customerAddress: String
    var customerLatitude: Double
    var customerLongitude: Double
    var status: DeliveryStatus
    var earnings: Double
    var distance: Double
    var createdAt: Date
    var pickedUpAt: Date?
    var deliveredAt: Date?

    var shopCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: shopLatitude, longitude: shopLongitude)
    }

    var customerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: customerLatitude, longitude: customerLongitude)
    }
}

enum DeliveryStatus: String, Codable {
    case available = "available"
    case accepted = "accepted"
    case atShop = "at_shop"
    case pickedUp = "picked_up"
    case delivering = "delivering"
    case delivered = "delivered"

    var displayName: String {
        switch self {
        case .available: return "Disponible"
        case .accepted: return "Acceptée"
        case .atShop: return "Au magasin"
        case .pickedUp: return "Récupérée"
        case .delivering: return "En cours"
        case .delivered: return "Livrée"
        }
    }
}

// MARK: - Statistics
struct MerchantStats: Equatable {
    var todayOrders: Int
    var todayRevenue: Double
    var pendingOrders: Int
    var totalProducts: Int

    static let empty = MerchantStats(todayOrders: 0, todayRevenue: 0, pendingOrders: 0, totalProducts: 0)
}

struct DriverStats: Equatable {
    var todayDeliveries: Int
    var todayEarnings: Double
    var totalDeliveries: Int
    var rating: Double

    static let empty = DriverStats(todayDeliveries: 0, todayEarnings: 0, totalDeliveries: 0, rating: 5.0)
}

// MARK: - Driver Location (for real-time tracking)
struct DriverLocation: Codable {
    let driverId: String
    var latitude: Double
    var longitude: Double
    var heading: Double?
    var speed: Double?
    var updatedAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
