import SwiftUI
import Foundation
import CoreLocation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

// MARK: - Auth Service
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var currentUser: FirebaseAuth.User?
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?

    // Demo mode flag - set to true to bypass Firebase Auth
    private let demoMode = false

    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()

    var isAuthenticated: Bool {
        userProfile != nil
    }

    private init() {
        if demoMode {
            isLoading = false
        } else {
            setupAuthStateListener()

            // Timeout: if Firebase doesn't respond in 5 seconds, stop loading
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if self.isLoading {
                    print("Firebase Auth timeout - stopping loading")
                    self.isLoading = false
                }
            }
        }
    }

    private func setupAuthStateListener() {
        print("Setting up Firebase Auth listener...")
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            print("Auth state changed - user: \(user?.email ?? "nil")")
            Task { @MainActor in
                self?.currentUser = user

                if let user = user {
                    // Get ID token for API calls
                    if let token = try? await user.getIDToken() {
                        APIService.shared.setAuthToken(token)
                    }

                    // Skip if profile already loaded (signIn already fetched it)
                    if self?.userProfile?.id == user.uid {
                        self?.isLoading = false
                        return
                    }

                    // Fetch user profile from Firestore
                    await self?.fetchUserProfile(userId: user.uid, email: user.email ?? "")
                } else {
                    self?.userProfile = nil
                    APIService.shared.setAuthToken(nil)
                }

                self?.isLoading = false
                print("Auth loading complete - isAuthenticated: \(self?.isAuthenticated ?? false)")
            }
        }
    }

    private func fetchUserProfile(userId: String, email: String) async {
        print("fetchUserProfile started for userId: \(userId)")

        // Always create a fallback profile first
        let fallbackProfile = UserProfile(
            id: userId,
            email: email,
            name: email.components(separatedBy: "@").first?.capitalized ?? "User",
            role: determineRole(from: email),
            status: "active",
            phone: nil,
            address: nil,
            shopId: nil,
            stripeAccountId: nil,
            createdAt: Date()
        )

        do {
            print("Fetching from Firestore collection 'users'...")
            let document = try await db.collection("users").document(userId).getDocument()
            print("Firestore document fetched - exists: \(document.exists)")

            if document.exists, let data = document.data() {
                print("📦 Firestore data received: \(data)")
                let loadedRole = data["role"] as? String ?? fallbackProfile.role
                print("📦 Role from Firestore: '\(loadedRole)'")
                userProfile = UserProfile(
                    id: userId,
                    email: data["email"] as? String ?? email,
                    name: data["name"] as? String ?? fallbackProfile.name,
                    role: loadedRole,
                    status: data["status"] as? String ?? "active",
                    phone: data["phone"] as? String,
                    address: data["address"] as? String,
                    shopId: data["shopId"] as? String,
                    stripeAccountId: data["stripeAccountId"] as? String,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
                print("✅ User profile loaded from Firestore: \(userProfile?.name ?? "nil"), role: \(userProfile?.role ?? "nil")")
            } else {
                userProfile = fallbackProfile
                print("No Firestore doc, using fallback profile: \(userProfile?.name ?? "nil"), role: \(userProfile?.role ?? "nil")")
            }
        } catch {
            print("❌ Firestore error: \(error)")
            print("❌ Error description: \(error.localizedDescription)")
            userProfile = fallbackProfile
            print("⚠️ Using fallback profile due to error - role: \(fallbackProfile.role)")
        }
    }

    private func determineRole(from email: String) -> String {
        if email.contains("driver") { return "driver" }
        if email.contains("merchant") { return "merchant" }
        if email.contains("admin") { return "admin" }
        return "user"
    }

    func signIn(email: String, password: String) async throws {
        print("SignIn started for: \(email)")
        isLoading = true
        errorMessage = nil

        if demoMode {
            try await Task.sleep(nanoseconds: 500_000_000)
            userProfile = UserProfile(
                id: UUID().uuidString,
                email: email,
                name: email.components(separatedBy: "@").first?.capitalized ?? "User",
                role: determineRole(from: email),
                status: "active",
                phone: nil,
                address: nil,
                shopId: nil,
                stripeAccountId: nil,
                createdAt: Date()
            )
            isLoading = false
            return
        }

        do {
            print("Calling Firebase Auth...")
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("Firebase Auth success - user: \(result.user.uid)")
            currentUser = result.user

            if let token = try? await result.user.getIDToken() {
                APIService.shared.setAuthToken(token)
                print("Token obtained")
            }

            // Fetch profile from Firestore
            print("Fetching user profile...")
            await fetchUserProfile(userId: result.user.uid, email: email)
            print("Profile fetched - isLoading = false")
            isLoading = false
        } catch {
            print("SignIn error: \(error.localizedDescription)")
            isLoading = false
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    func signInWithGoogle() async throws {
        isLoading = true
        errorMessage = nil

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            isLoading = false
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Impossible de trouver la fenêtre principale"])
        }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            isLoading = false
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Configuration Google Sign-In manquante"])
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                isLoading = false
                throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Token Google manquant"])
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            currentUser = authResult.user

            if let token = try? await authResult.user.getIDToken() {
                APIService.shared.setAuthToken(token)
            }

            await fetchUserProfile(userId: authResult.user.uid, email: authResult.user.email ?? "")

            // Create user doc in Firestore if new
            let userDoc = try? await db.collection("users").document(authResult.user.uid).getDocument()
            if userDoc == nil || !(userDoc?.exists ?? false) {
                let userData: [String: Any] = [
                    "email": authResult.user.email ?? "",
                    "name": authResult.user.displayName ?? "User",
                    "role": "user",
                    "status": "active",
                    "createdAt": Timestamp(date: Date())
                ]
                try? await db.collection("users").document(authResult.user.uid).setData(userData)
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signUp(email: String, password: String, name: String, role: String = "user") async throws {
        print("📝 SignUp started - email: \(email), role: \(role)")
        isLoading = true
        errorMessage = nil

        if demoMode {
            try await Task.sleep(nanoseconds: 500_000_000)
            userProfile = UserProfile(
                id: UUID().uuidString,
                email: email,
                name: name,
                role: role,
                status: "active",
                phone: nil,
                address: nil,
                shopId: nil,
                stripeAccountId: nil,
                createdAt: Date()
            )
            isLoading = false
            return
        }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            currentUser = result.user

            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try? await changeRequest.commitChanges()

            if let token = try? await result.user.getIDToken() {
                APIService.shared.setAuthToken(token)
            }

            var userData: [String: Any] = [
                "email": email,
                "name": name,
                "role": role,
                "status": "active",
                "createdAt": Timestamp(date: Date())
            ]

            var shopId: String? = nil

            // Create associated documents based on role
            if role == "merchant" {
                // Create a shop document for the merchant
                let shopData: [String: Any] = [
                    "ownerId": result.user.uid,
                    "ownerName": name,
                    "name": "\(name) - Boutique",
                    "description": "",
                    "status": "active",
                    "approvalStatus": "approved",
                    "address": "",
                    "category": "grocery",
                    "location": ["latitude": 48.8566, "longitude": 2.3522],
                    "deliveryFee": 2.99,
                    "minOrderAmount": 10.0,
                    "estimatedDeliveryTime": "20-30 min",
                    "rating": 0.0,
                    "totalOrders": 0,
                    "totalProducts": 0,
                    "createdAt": Timestamp(date: Date()),
                    "updatedAt": Timestamp(date: Date())
                ]
                let shopRef = try await db.collection("shops").addDocument(data: shopData)
                shopId = shopRef.documentID
                userData["shopId"] = shopRef.documentID
                print("✅ Shop created for merchant: \(shopRef.documentID)")
            } else if role == "driver" {
                // Create a driver document
                let driverData: [String: Any] = [
                    "id": result.user.uid,
                    "driverId": result.user.uid,
                    "name": name,
                    "email": email,
                    "phone": "",
                    "status": "offline",
                    "vehicleType": "moto",
                    "vehiclePlate": "",
                    "rating": 5.0,
                    "completedDeliveries": 0,
                    "isAvailable": false,
                    "location": ["lat": 48.8566, "lng": 2.3522, "updatedAt": Date().ISO8601Format()],
                    "lastSeenAt": Date().ISO8601Format(),
                    "createdAt": Timestamp(date: Date())
                ]
                try await db.collection("drivers").document(result.user.uid).setData(driverData)
                print("✅ Driver document created: \(result.user.uid)")
            }

            try await db.collection("users").document(result.user.uid).setData(userData)
            print("✅ User saved to Firestore with role: \(role)")

            let newProfile = UserProfile(
                id: result.user.uid,
                email: email,
                name: name,
                role: role,
                status: "active",
                phone: nil,
                address: nil,
                shopId: shopId,
                stripeAccountId: nil,
                createdAt: Date()
            )

            userProfile = newProfile
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    func signOut() throws {
        if !demoMode {
            try Auth.auth().signOut()
        }
        currentUser = nil
        userProfile = nil
        APIService.shared.setAuthToken(nil)
    }

    func updateProfile(name: String, phone: String, address: String) {
        guard var profile = userProfile else { return }
        profile.name = name
        profile.phone = phone
        profile.address = address
        userProfile = profile

        // Update in Firestore
        Task {
            try? await db.collection("users").document(profile.id).updateData([
                "name": name,
                "phone": phone,
                "address": address
            ])
        }
    }

    func refreshToken() async {
        guard let user = currentUser else { return }
        if let token = try? await user.getIDToken(forcingRefresh: true) {
            APIService.shared.setAuthToken(token)
        }
    }

    private func mapAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            return "Mot de passe incorrect"
        case AuthErrorCode.invalidEmail.rawValue:
            return "Email invalide"
        case AuthErrorCode.userNotFound.rawValue:
            return "Utilisateur non trouvé"
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "Cet email est déjà utilisé"
        case AuthErrorCode.weakPassword.rawValue:
            return "Mot de passe trop faible (min 6 caractères)"
        case AuthErrorCode.networkError.rawValue:
            return "Erreur réseau"
        case AuthErrorCode.invalidCredential.rawValue:
            return "Email ou mot de passe incorrect"
        default:
            return "Erreur: \(error.localizedDescription)"
        }
    }
}

// MARK: - User Profile Model
struct UserProfile: Equatable {
    let id: String
    var email: String
    var name: String
    var role: String
    var status: String
    var phone: String?
    var address: String?
    var shopId: String?
    var stripeAccountId: String?
    var createdAt: Date?
}

// MARK: - Data Service (Firebase Firestore)
@MainActor
final class DataService: ObservableObject {
    static let shared = DataService()

    @Published var shops: [Shop] = []
    @Published var products: [Product] = []
    @Published var orders: [Order] = []
    @Published var deliveries: [Delivery] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var shopsListener: ListenerRegistration?
    private var ordersListener: ListenerRegistration?
    private var deliveriesListener: ListenerRegistration?
    private var driverOrdersListener: ListenerRegistration?

    private init() {}

    // MARK: - Real-time Listeners

    /// Start listening to orders for a specific user (Client)
    func startOrdersListener(forUser userId: String) {
        stopOrdersListener()

        print("Starting real-time orders listener for user: \(userId)")

        ordersListener = db.collection("orders")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("Orders listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                var loadedOrders: [Order] = []
                for document in documents {
                    if let order = self.parseOrder(from: document) {
                        loadedOrders.append(order)
                    }
                }

                // Check for status changes and notify
                self.checkOrderStatusChanges(oldOrders: self.orders, newOrders: loadedOrders)

                self.orders = loadedOrders
                print("Real-time update: \(loadedOrders.count) orders")
            }
    }

    /// Start listening to orders for a specific shop (Merchant)
    func startOrdersListener(forShop shopId: String) {
        stopOrdersListener()

        print("Starting real-time orders listener for shop: \(shopId)")

        ordersListener = db.collection("orders")
            .whereField("shopId", isEqualTo: shopId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("Orders listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                var loadedOrders: [Order] = []
                for document in documents {
                    if let order = self.parseOrder(from: document) {
                        loadedOrders.append(order)
                    }
                }

                // Check for new orders and notify merchant
                self.checkNewOrdersForMerchant(oldOrders: self.orders, newOrders: loadedOrders)

                self.orders = loadedOrders
                print("Real-time update: \(loadedOrders.count) shop orders")
            }
    }

    /// Start listening to available deliveries (Driver)
    /// Listens for: 1) "ready" orders without a driver (available), 2) orders assigned to this driver (active)
    func startDeliveriesListener(forDriver driverId: String) {
        stopDeliveriesListener()

        print("Starting real-time deliveries listener for driver: \(driverId)")

        // Listen for "ready" orders (available for pickup)
        deliveriesListener = db.collection("orders")
            .whereField("status", isEqualTo: "ready")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("Deliveries listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                var availableDeliveries: [Delivery] = []
                for document in documents {
                    let data = document.data()
                    let assignedDriver = data["driverId"] as? String
                    // Include if no driver assigned (available) - these are for all drivers
                    if assignedDriver == nil || assignedDriver!.isEmpty {
                        if let delivery = self.parseDeliveryFromOrder(document) {
                            availableDeliveries.append(delivery)
                        }
                    }
                }

                // Keep existing active deliveries (assigned to this driver)
                let activeDeliveries = self.deliveries.filter { $0.driverId == driverId && $0.status != .available }

                let oldAvailableCount = self.deliveries.filter { $0.status == .available }.count
                if availableDeliveries.count > oldAvailableCount {
                    let newCount = availableDeliveries.count - oldAvailableCount
                    NotificationService.shared.sendLocalNotification(
                        title: "Nouvelle livraison disponible",
                        body: "\(newCount) nouvelle(s) livraison(s) à proximité"
                    )
                }

                self.deliveries = activeDeliveries + availableDeliveries
                print("Real-time update: \(availableDeliveries.count) available, \(activeDeliveries.count) active deliveries")
            }

        // Also listen for orders assigned to this driver
        driverOrdersListener = db.collection("orders")
            .whereField("driverId", isEqualTo: driverId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }

                var driverDeliveries: [Delivery] = []
                for document in documents {
                    let data = document.data()
                    let statusString = data["status"] as? String ?? ""
                    // Skip delivered/cancelled orders in active list
                    if statusString == "delivered" || statusString == "cancelled" {
                        // Still track them for earnings
                        if statusString == "delivered" {
                            if let delivery = self.parseDeliveryFromOrder(document) {
                                var completedDelivery = delivery
                                completedDelivery.status = .delivered
                                completedDelivery.driverId = driverId
                                completedDelivery.deliveredAt = (data["deliveredAt"] as? Timestamp)?.dateValue() ?? (data["updatedAt"] as? Timestamp)?.dateValue()
                                driverDeliveries.append(completedDelivery)
                            }
                        }
                        continue
                    }

                    if let delivery = self.parseDeliveryFromOrder(document) {
                        var activeDelivery = delivery
                        activeDelivery.driverId = driverId
                        // Map order status to delivery status
                        switch statusString {
                        case "delivering":
                            activeDelivery.status = .delivering
                        case "pickedUp":
                            activeDelivery.status = .pickedUp
                        default:
                            activeDelivery.status = .accepted
                        }
                        driverDeliveries.append(activeDelivery)
                    }
                }

                // Merge: keep available deliveries, replace driver-specific ones
                let availableOnly = self.deliveries.filter { $0.status == .available }
                self.deliveries = availableOnly + driverDeliveries
                print("Driver deliveries update: \(driverDeliveries.count) for driver \(driverId)")
            }
    }

    private func checkOrderStatusChanges(oldOrders: [Order], newOrders: [Order]) {
        for newOrder in newOrders {
            if let oldOrder = oldOrders.first(where: { $0.id == newOrder.id }) {
                if oldOrder.status != newOrder.status {
                    NotificationService.shared.sendLocalNotification(
                        title: "Commande mise à jour",
                        body: "Votre commande est maintenant: \(newOrder.status.displayName)"
                    )
                }
            }
        }
    }

    private func checkNewOrdersForMerchant(oldOrders: [Order], newOrders: [Order]) {
        let oldIds = Set(oldOrders.map { $0.id })
        let newOrdersReceived = newOrders.filter { !oldIds.contains($0.id) && $0.status == .pending }

        if !newOrdersReceived.isEmpty {
            NotificationService.shared.sendLocalNotification(
                title: "Nouvelle commande !",
                body: "Vous avez reçu \(newOrdersReceived.count) nouvelle(s) commande(s)"
            )
        }
    }

    private func parseDeliveryFromOrder(_ document: DocumentSnapshot) -> Delivery? {
        let data = document.data() ?? [:]
        let orderId = document.documentID

        // Parse delivery location
        var deliveryLat = 48.8566
        var deliveryLng = 2.3522
        if let location = data["deliveryLocation"] as? [String: Any] {
            deliveryLat = location["latitude"] as? Double ?? 48.8566
            deliveryLng = location["longitude"] as? Double ?? 2.3522
        }

        return Delivery(
            id: orderId,
            orderId: orderId,
            driverId: data["driverId"] as? String,
            shopName: data["shopName"] as? String ?? "Shop",
            shopAddress: data["shopAddress"] as? String ?? "",
            shopLatitude: 48.8566,
            shopLongitude: 2.3522,
            customerName: "Client",
            customerAddress: data["deliveryAddress"] as? String ?? "",
            customerLatitude: deliveryLat,
            customerLongitude: deliveryLng,
            status: .available,
            earnings: (data["deliveryFee"] as? Double ?? 5.0) * 0.8, // 80% for driver
            distance: 2.5,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            pickedUpAt: nil,
            deliveredAt: nil
        )
    }

    func stopOrdersListener() {
        ordersListener?.remove()
        ordersListener = nil
    }

    func stopDeliveriesListener() {
        deliveriesListener?.remove()
        deliveriesListener = nil
        driverOrdersListener?.remove()
        driverOrdersListener = nil
    }

    func stopAllListeners() {
        stopOrdersListener()
        stopDeliveriesListener()
        shopsListener?.remove()
        shopsListener = nil
    }

    // MARK: - Shops (Firestore)
    func loadShops(category: String? = nil, search: String? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            var query: Query = db.collection("shops").whereField("status", isEqualTo: "active")

            if let category = category {
                query = query.whereField("category", isEqualTo: category)
            }

            let snapshot = try await query.getDocuments()
            var loadedShops: [Shop] = []

            for document in snapshot.documents {
                if let shop = parseShop(from: document) {
                    // Apply search filter client-side if needed
                    if let search = search, !search.isEmpty {
                        if shop.name.localizedCaseInsensitiveContains(search) ||
                           shop.address.localizedCaseInsensitiveContains(search) {
                            loadedShops.append(shop)
                        }
                    } else {
                        loadedShops.append(shop)
                    }
                }
            }

            shops = loadedShops
            print("Loaded \(shops.count) shops from Firestore")
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading shops: \(error)")
        }

        isLoading = false
    }

    private func parseShop(from document: DocumentSnapshot) -> Shop? {
        let data = document.data() ?? [:]
        let id = document.documentID

        // Parse location (support both latitude/longitude and lat/lng)
        var latitude = 48.8566
        var longitude = 2.3522
        if let location = data["location"] as? [String: Any] {
            latitude = location["latitude"] as? Double ?? location["lat"] as? Double ?? 48.8566
            longitude = location["longitude"] as? Double ?? location["lng"] as? Double ?? 2.3522
        }

        // Parse category - support both single string and array format
        var categoryString = data["category"] as? String ?? "other"
        if categoryString == "other", let categories = data["categories"] as? [String], let first = categories.first {
            // Map French category names to ShopCategory rawValues
            let lowerFirst = first.lowercased()
            if lowerFirst.contains("bio") || lowerFirst.contains("légumes") || lowerFirst.contains("fruits") || lowerFirst.contains("épicerie") {
                categoryString = "grocery"
            } else if lowerFirst.contains("boulangerie") || lowerFirst.contains("pâtisserie") {
                categoryString = "bakery"
            } else if lowerFirst.contains("pharmacie") {
                categoryString = "pharmacy"
            } else if lowerFirst.contains("fleur") {
                categoryString = "flowers"
            }
        }
        let category = ShopCategory(rawValue: categoryString) ?? .other

        return Shop(
            id: id,
            name: data["name"] as? String ?? "Shop",
            description: data["description"] as? String ?? "",
            imageURL: data["logoUrl"] as? String,
            address: data["address"] as? String ?? "",
            latitude: latitude,
            longitude: longitude,
            category: category,
            rating: data["rating"] as? Double ?? 4.5,
            reviewCount: data["totalOrders"] as? Int ?? 0,
            isOpen: (data["status"] as? String ?? "active") == "active",
            deliveryFee: data["deliveryFee"] as? Double ?? 2.99,
            minOrderAmount: data["minOrderAmount"] as? Double ?? 10.0,
            estimatedDeliveryTime: data["estimatedDeliveryTime"] as? String ?? "20-30 min",
            ownerId: data["ownerId"] as? String ?? ""
        )
    }

    func getShops() -> [Shop] {
        shops.filter { $0.isOpen }
    }

    func getShop(id: String) -> Shop? {
        shops.first { $0.id == id }
    }

    func getShopsByCategory(_ category: ShopCategory) -> [Shop] {
        shops.filter { $0.category == category && $0.isOpen }
    }

    // MARK: - Products (Firestore)
    func loadProducts(forShop shopId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db.collection("products")
                .whereField("shopId", isEqualTo: shopId)
                .whereField("status", isEqualTo: "active")
                .getDocuments()

            var loadedProducts: [Product] = []

            for document in snapshot.documents {
                if let product = parseProduct(from: document) {
                    loadedProducts.append(product)
                }
            }

            // Merge with existing products
            for product in loadedProducts {
                if let index = products.firstIndex(where: { $0.id == product.id }) {
                    products[index] = product
                } else {
                    products.append(product)
                }
            }

            print("Loaded \(loadedProducts.count) products for shop \(shopId)")
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading products: \(error)")
        }

        isLoading = false
    }

    private func parseProduct(from document: DocumentSnapshot) -> Product? {
        let data = document.data() ?? [:]
        let id = document.documentID

        return Product(
            id: id,
            name: data["name"] as? String ?? "Product",
            description: data["description"] as? String ?? "",
            price: data["price"] as? Double ?? 0.0,
            imageURL: data["imageUrl"] as? String,
            category: data["category"] as? String ?? "Other",
            shopId: data["shopId"] as? String ?? "",
            isAvailable: (data["status"] as? String ?? "active") == "active",
            stock: data["stock"] as? Int ?? 0
        )
    }

    func getProducts(forShop shopId: String) -> [Product] {
        products.filter { $0.shopId == shopId && $0.isAvailable }
    }

    func getProduct(id: String) -> Product? {
        products.first { $0.id == id }
    }

    // MARK: - Orders (Firestore)
    func loadOrders() async {
        guard let userId = AuthService.shared.userProfile?.id else { return }

        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db.collection("orders")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            var loadedOrders: [Order] = []

            for document in snapshot.documents {
                if let order = parseOrder(from: document) {
                    loadedOrders.append(order)
                }
            }

            orders = loadedOrders
            print("Loaded \(orders.count) orders for user \(userId)")
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading orders: \(error)")
        }

        isLoading = false
    }

    func loadOrdersForShop(shopId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db.collection("orders")
                .whereField("shopId", isEqualTo: shopId)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            var loadedOrders: [Order] = []

            for document in snapshot.documents {
                if let order = parseOrder(from: document) {
                    loadedOrders.append(order)
                }
            }

            orders = loadedOrders
            print("Loaded \(orders.count) orders for shop \(shopId)")
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading shop orders: \(error)")
        }

        isLoading = false
    }

    private func parseOrder(from document: DocumentSnapshot) -> Order? {
        let data = document.data() ?? [:]
        let id = document.documentID

        // Parse items
        var orderItems: [OrderItem] = []
        if let itemsData = data["items"] as? [[String: Any]] {
            for itemData in itemsData {
                let item = OrderItem(
                    id: itemData["productId"] as? String ?? UUID().uuidString,
                    productId: itemData["productId"] as? String ?? "",
                    productName: itemData["productName"] as? String ?? itemData["name"] as? String ?? "Product",
                    price: itemData["price"] as? Double ?? 0.0,
                    quantity: itemData["quantity"] as? Int ?? 1
                )
                orderItems.append(item)
            }
        }

        // Parse dates
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
        let estimatedDelivery = (data["estimatedDeliveryTime"] as? Timestamp)?.dateValue()

        // Parse delivery location
        var deliveryLat = 48.8566
        var deliveryLng = 2.3522
        if let location = data["deliveryLocation"] as? [String: Any] {
            deliveryLat = location["latitude"] as? Double ?? 48.8566
            deliveryLng = location["longitude"] as? Double ?? 2.3522
        }

        // Parse status
        let statusString = data["status"] as? String ?? "pending"
        let status = OrderStatus(rawValue: statusString) ?? .pending

        return Order(
            id: id,
            userId: data["userId"] as? String ?? "",
            shopId: data["shopId"] as? String ?? "",
            shopName: data["shopName"] as? String ?? "Shop",
            driverId: data["driverId"] as? String,
            items: orderItems,
            status: status,
            subtotal: data["subtotal"] as? Double ?? 0.0,
            deliveryFee: data["deliveryFee"] as? Double ?? 5.0,
            total: data["total"] as? Double ?? 0.0,
            deliveryAddress: data["deliveryAddress"] as? String ?? "",
            deliveryLatitude: deliveryLat,
            deliveryLongitude: deliveryLng,
            createdAt: createdAt,
            updatedAt: updatedAt,
            estimatedDelivery: estimatedDelivery,
            notes: data["notes"] as? String,
            paymentStatus: data["paymentStatus"] as? String,
            paymentIntentId: data["paymentIntentId"] as? String
        )
    }

    func createOrder(_ orderRequest: CreateOrderRequest, paymentIntentId: String? = nil) async throws -> Order {
        isLoading = true
        defer { isLoading = false }

        guard let userId = AuthService.shared.userProfile?.id else {
            throw NSError(domain: "DataService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Utilisateur non connecté"])
        }

        let shop = getShop(id: orderRequest.shopId)
        let subtotal = orderRequest.items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
        let deliveryFee = shop?.deliveryFee ?? 2.99
        let total = subtotal + deliveryFee
        let reference = "ORD-\(Int(Date().timeIntervalSince1970))"

        let orderData: [String: Any] = [
            "userId": userId,
            "shopId": orderRequest.shopId,
            "shopName": shop?.name ?? "Shop",
            "shopAddress": shop?.address ?? "",
            "driverId": NSNull(),
            "reference": reference,
            "status": "pending",
            "items": orderRequest.items.map { [
                "productId": $0.productId,
                "productName": $0.productName,
                "price": $0.price,
                "quantity": $0.quantity
            ]},
            "subtotal": subtotal,
            "deliveryFee": deliveryFee,
            "total": total,
            "deliveryAddress": orderRequest.deliveryAddress,
            "deliveryLocation": [
                "latitude": orderRequest.deliveryLatitude,
                "longitude": orderRequest.deliveryLongitude
            ],
            "notes": orderRequest.notes ?? "",
            "paymentMethod": paymentIntentId != nil ? "card" : "cash",
            "paymentStatus": paymentIntentId != nil ? "paid" : "pending",
            "paymentIntentId": paymentIntentId ?? NSNull(),
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "estimatedDeliveryTime": Timestamp(date: Date().addingTimeInterval(30 * 60))
        ]

        let docRef = try await db.collection("orders").addDocument(data: orderData)

        let order = Order(
            id: docRef.documentID,
            userId: userId,
            shopId: orderRequest.shopId,
            shopName: shop?.name ?? "Shop",
            driverId: nil,
            items: orderRequest.items.map { OrderItem(id: $0.productId, productId: $0.productId, productName: $0.productName, price: $0.price, quantity: $0.quantity) },
            status: .pending,
            subtotal: subtotal,
            deliveryFee: deliveryFee,
            total: total,
            deliveryAddress: orderRequest.deliveryAddress,
            deliveryLatitude: orderRequest.deliveryLatitude,
            deliveryLongitude: orderRequest.deliveryLongitude,
            createdAt: Date(),
            updatedAt: Date(),
            estimatedDelivery: Date().addingTimeInterval(30 * 60),
            notes: orderRequest.notes,
            paymentStatus: paymentIntentId != nil ? "paid" : "pending",
            paymentIntentId: paymentIntentId
        )

        orders.insert(order, at: 0)
        return order
    }

    func updateOrderStatus(_ orderId: String, status: OrderStatus) async {
        do {
            try await db.collection("orders").document(orderId).updateData([
                "status": status.rawValue,
                "updatedAt": Timestamp(date: Date())
            ])

            if let index = orders.firstIndex(where: { $0.id == orderId }) {
                orders[index] = Order(
                    id: orders[index].id,
                    userId: orders[index].userId,
                    shopId: orders[index].shopId,
                    shopName: orders[index].shopName,
                    driverId: orders[index].driverId,
                    items: orders[index].items,
                    status: status,
                    subtotal: orders[index].subtotal,
                    deliveryFee: orders[index].deliveryFee,
                    total: orders[index].total,
                    deliveryAddress: orders[index].deliveryAddress,
                    deliveryLatitude: orders[index].deliveryLatitude,
                    deliveryLongitude: orders[index].deliveryLongitude,
                    createdAt: orders[index].createdAt,
                    updatedAt: Date(),
                    estimatedDelivery: orders[index].estimatedDelivery,
                    notes: orders[index].notes,
                    paymentStatus: orders[index].paymentStatus,
                    paymentIntentId: orders[index].paymentIntentId
                )
            }
            print("Order \(orderId) status updated to \(status.rawValue)")
        } catch {
            print("Error updating order status: \(error)")
        }
    }

    func getOrders(forUser userId: String) -> [Order] {
        orders.filter { $0.userId == userId }.sorted { $0.createdAt > $1.createdAt }
    }

    func getOrders(forShop shopId: String) -> [Order] {
        orders.filter { $0.shopId == shopId }.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Shop Resolution
    func resolveShopId(forOwner ownerId: String) async -> String? {
        do {
            let snapshot = try await db.collection("shops")
                .whereField("ownerId", isEqualTo: ownerId)
                .limit(to: 1)
                .getDocuments()
            return snapshot.documents.first?.documentID
        } catch {
            print("Error resolving shopId for owner \(ownerId): \(error)")
            return nil
        }
    }

    // MARK: - Driver (Firestore)
    func updateDriverLocation(latitude: Double, longitude: Double, heading: Double? = nil, speed: Double? = nil) async {
        guard let userId = AuthService.shared.userProfile?.id else { return }

        do {
            var locationData: [String: Any] = [
                "latitude": latitude,
                "longitude": longitude,
                "updatedAt": Timestamp(date: Date())
            ]
            if let heading = heading { locationData["heading"] = heading }
            if let speed = speed { locationData["speed"] = speed }

            // Update driver document
            try await db.collection("drivers").document(userId).updateData([
                "location": locationData,
                "lastSeenAt": Timestamp(date: Date())
            ])

            // Also update location in active orders assigned to this driver
            let activeDelivery = deliveries.first { $0.driverId == userId && $0.status != .delivered && $0.status != .available }
            if let delivery = activeDelivery {
                try await db.collection("orders").document(delivery.orderId).updateData([
                    "driverLocation": locationData
                ])
            }
        } catch {
            print("Error updating driver location: \(error)")
        }
    }

    func updateDriverStatus(_ status: String) async {
        guard let userId = AuthService.shared.userProfile?.id else { return }

        do {
            try await db.collection("drivers").document(userId).updateData([
                "status": status,
                "lastSeenAt": Timestamp(date: Date())
            ])
        } catch {
            print("Error updating driver status: \(error)")
        }
    }

    // MARK: - Deliveries
    func loadAvailableDeliveries() async {
        isLoading = true

        do {
            // Query orders with status "ready" - filter for no driver client-side
            let snapshot = try await db.collection("orders")
                .whereField("status", isEqualTo: "ready")
                .getDocuments()

            var loadedDeliveries: [Delivery] = []

            for document in snapshot.documents {
                let data = document.data()
                // Only include orders without a driver assigned
                let driverId = data["driverId"] as? String
                if driverId != nil && !driverId!.isEmpty { continue }

                if let order = parseOrder(from: document) {
                    let shop = getShop(id: order.shopId)
                    let delivery = Delivery(
                        id: document.documentID,
                        orderId: document.documentID,
                        driverId: nil,
                        shopName: order.shopName,
                        shopAddress: data["shopAddress"] as? String ?? shop?.address ?? "",
                        shopLatitude: shop?.latitude ?? 48.8566,
                        shopLongitude: shop?.longitude ?? 2.3522,
                        customerName: "Client",
                        customerAddress: order.deliveryAddress,
                        customerLatitude: order.deliveryLatitude,
                        customerLongitude: order.deliveryLongitude,
                        status: .available,
                        earnings: order.deliveryFee * 0.8,
                        distance: 2.5,
                        createdAt: order.createdAt,
                        pickedUpAt: nil,
                        deliveredAt: nil
                    )
                    loadedDeliveries.append(delivery)
                }
            }

            deliveries = loadedDeliveries
            print("Loaded \(deliveries.count) available deliveries")
        } catch {
            print("Error loading deliveries: \(error)")
        }

        isLoading = false
    }

    func getAvailableDeliveries() -> [Delivery] {
        deliveries.filter { $0.status == .available }
    }

    func getActiveDelivery(forDriver driverId: String) -> Delivery? {
        deliveries.first { $0.driverId == driverId && $0.status != .delivered && $0.status != .available }
    }

    func getCompletedDeliveries(forDriver driverId: String) -> [Delivery] {
        deliveries.filter { $0.driverId == driverId && $0.status == .delivered }
    }

    func acceptDelivery(_ deliveryId: String, driverId: String) async {
        do {
            let batch = db.batch()

            let orderRef = db.collection("orders").document(deliveryId)
            batch.updateData([
                "driverId": driverId,
                "updatedAt": Timestamp(date: Date())
            ], forDocument: orderRef)

            let driverRef = db.collection("drivers").document(driverId)
            batch.updateData([
                "status": "busy",
                "currentOrderId": deliveryId
            ], forDocument: driverRef)

            try await batch.commit()

            if let index = deliveries.firstIndex(where: { $0.id == deliveryId }) {
                deliveries[index].driverId = driverId
                deliveries[index].status = .accepted
            }

            print("Delivery \(deliveryId) accepted by driver \(driverId)")
        } catch {
            print("Error accepting delivery: \(error)")
        }
    }

    func updateDeliveryStatus(_ deliveryId: String, status: DeliveryStatus) async {
        if let index = deliveries.firstIndex(where: { $0.id == deliveryId }) {
            deliveries[index].status = status

            if status == .pickedUp {
                deliveries[index].pickedUpAt = Date()
            } else if status == .delivered {
                deliveries[index].deliveredAt = Date()
            }

            switch status {
            case .available, .accepted, .atShop:
                break  // No order status change — order stays at current status
            case .pickedUp:
                await updateOrderStatus(deliveries[index].orderId, status: .pickedUp)
            case .delivering:
                await updateOrderStatus(deliveries[index].orderId, status: .delivering)
            case .delivered:
                await updateOrderStatus(deliveries[index].orderId, status: .delivered)
            }
        }
    }

    // MARK: - Product Management
    func addProduct(_ product: Product) async throws {
        let productData: [String: Any] = [
            "name": product.name,
            "description": product.description,
            "price": product.price,
            "category": product.category,
            "shopId": product.shopId,
            "status": product.isAvailable ? "active" : "inactive",
            "stock": product.stock,
            "createdAt": Timestamp(date: Date())
        ]

        let docRef = try await db.collection("products").addDocument(data: productData)
        var newProduct = product
        newProduct = Product(
            id: docRef.documentID,
            name: product.name,
            description: product.description,
            price: product.price,
            imageURL: product.imageURL,
            category: product.category,
            shopId: product.shopId,
            isAvailable: product.isAvailable,
            stock: product.stock
        )
        products.append(newProduct)
    }

    func updateProduct(_ product: Product) async throws {
        try await db.collection("products").document(product.id).updateData([
            "name": product.name,
            "description": product.description,
            "price": product.price,
            "category": product.category,
            "status": product.isAvailable ? "active" : "inactive",
            "stock": product.stock
        ])

        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
        }
    }

    func deleteProduct(id: String) async throws {
        try await db.collection("products").document(id).delete()
        products.removeAll { $0.id == id }
    }

    // MARK: - Statistics
    func getMerchantStats(shopId: String, period: StatsPeriod = .today) -> MerchantStats {
        let shopOrders = orders.filter { $0.shopId == shopId }
        let calendar = Calendar.current
        let now = Date()

        let periodStart: Date
        switch period {
        case .today:
            periodStart = calendar.startOfDay(for: now)
        case .week:
            periodStart = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) ?? now
        case .month:
            periodStart = calendar.date(byAdding: .month, value: -1, to: calendar.startOfDay(for: now)) ?? now
        }

        let periodOrders = shopOrders.filter { $0.createdAt >= periodStart }

        return MerchantStats(
            todayOrders: periodOrders.count,
            todayRevenue: periodOrders.reduce(0) { $0 + $1.total },
            pendingOrders: shopOrders.filter { $0.status == .pending || $0.status == .confirmed || $0.status == .preparing }.count,
            totalProducts: products.filter { $0.shopId == shopId }.count
        )
    }

    func getDriverStats(driverId: String) -> DriverStats {
        let driverDeliveries = deliveries.filter { $0.driverId == driverId }
        let today = Calendar.current.startOfDay(for: Date())
        let todayDeliveries = driverDeliveries.filter { $0.status == .delivered && ($0.deliveredAt ?? Date.distantPast) >= today }

        return DriverStats(
            todayDeliveries: todayDeliveries.count,
            todayEarnings: todayDeliveries.reduce(0) { $0 + $1.earnings },
            totalDeliveries: driverDeliveries.filter { $0.status == .delivered }.count,
            rating: 4.8
        )
    }
}

// MARK: - Cart Manager
@MainActor
final class CartManager: ObservableObject {
    @Published var cart = Cart()
    @Published var currentShopId: String?
    @Published var currentShopName: String?

    func addToCart(_ product: Product, quantity: Int = 1) {
        if let currentShop = currentShopId, currentShop != product.shopId {
            cart.clear()
        }

        currentShopId = product.shopId
        currentShopName = DataService.shared.getShop(id: product.shopId)?.name

        let cartProduct = CartProduct(
            id: product.id,
            name: product.name,
            price: product.price,
            isRestricted: product.isRestricted,
            minimumAge: product.minimumAge
        )
        cart.add(cartProduct, quantity: quantity)
    }

    func removeFromCart(_ productId: String) {
        cart.remove(productId)
        if cart.isEmpty {
            currentShopId = nil
            currentShopName = nil
        }
    }

    func updateQuantity(_ productId: String, quantity: Int) {
        cart.updateQuantity(productId, quantity: quantity)
        if cart.isEmpty {
            currentShopId = nil
            currentShopName = nil
        }
    }

    func clearCart() {
        cart.clear()
        currentShopId = nil
        currentShopName = nil
    }

    var subtotal: Double {
        cart.items.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
    }

    var deliveryFee: Double {
        guard let shopId = currentShopId,
              let shop = DataService.shared.getShop(id: shopId) else { return 0 }
        return shop.deliveryFee
    }

    var total: Double {
        subtotal + deliveryFee
    }

    /// Returns true if cart contains any age-restricted products
    var hasRestrictedProducts: Bool {
        cart.items.contains { $0.product.isRestricted }
    }

    /// Returns the list of restricted product names in the cart
    var restrictedProductNames: [String] {
        cart.items.filter { $0.product.isRestricted }.map { $0.product.name }
    }

    /// Checks if user can checkout with restricted products (must be verified adult)
    func canCheckoutWithRestrictedProducts() -> Bool {
        guard hasRestrictedProducts else { return true }
        return KYCService.shared.verificationStatus == .approved
    }
}

struct Cart: Equatable {
    var items: [CartItem] = []
    var isEmpty: Bool { items.isEmpty }
    var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }

    mutating func add(_ product: CartProduct, quantity: Int = 1) {
        if let index = items.firstIndex(where: { $0.product.id == product.id }) {
            items[index].quantity += quantity
        } else {
            items.append(CartItem(product: product, quantity: quantity))
        }
    }

    mutating func remove(_ productId: String) {
        items.removeAll { $0.product.id == productId }
    }

    mutating func updateQuantity(_ productId: String, quantity: Int) {
        if quantity <= 0 {
            remove(productId)
        } else if let index = items.firstIndex(where: { $0.product.id == productId }) {
            items[index].quantity = quantity
        }
    }

    mutating func clear() {
        items.removeAll()
    }
}

struct CartItem: Identifiable, Equatable {
    let id = UUID().uuidString
    var product: CartProduct
    var quantity: Int
}

struct CartProduct: Identifiable, Equatable {
    let id: String
    var name: String
    var price: Double
    var isRestricted: Bool = false
    var minimumAge: Int? = nil
}

// MARK: - Location Manager
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?
    @Published var heading: Double?
    @Published var speed: Double?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // Update every 10 meters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let lastLocation = locations.last else { return }
        location = lastLocation.coordinate
        speed = lastLocation.speed >= 0 ? lastLocation.speed : nil
        // Use course for heading when moving
        if lastLocation.course >= 0 {
            heading = lastLocation.course
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Use true heading if available, otherwise magnetic
        if newHeading.trueHeading >= 0 {
            heading = newHeading.trueHeading
        } else if newHeading.magneticHeading >= 0 {
            heading = newHeading.magneticHeading
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startUpdating()
        }
    }

    func distanceFrom(_ coordinate: CLLocationCoordinate2D) -> Double? {
        guard let userLocation = location else { return nil }
        let from = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return from.distance(from: to) / 1000
    }
}

// MARK: - Demo Data (Fallback when API is unavailable)
struct DemoData {
    static let shops: [Shop] = [
        Shop(
            id: "shop1",
            name: "Bio Market Paris",
            description: "Produits bio et locaux de qualité",
            imageURL: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=400",
            address: "15 Rue de la Paix, 75002 Paris",
            latitude: 48.8698,
            longitude: 2.3311,
            category: .grocery,
            rating: 4.8,
            reviewCount: 124,
            isOpen: true,
            deliveryFee: 2.99,
            minOrderAmount: 15.0,
            estimatedDeliveryTime: "20-30 min",
            ownerId: "merchant1"
        ),
        Shop(
            id: "shop2",
            name: "Le Petit Boulanger",
            description: "Boulangerie artisanale traditionnelle",
            imageURL: "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400",
            address: "42 Avenue des Champs-Élysées, 75008 Paris",
            latitude: 48.8714,
            longitude: 2.3033,
            category: .bakery,
            rating: 4.9,
            reviewCount: 89,
            isOpen: true,
            deliveryFee: 1.99,
            minOrderAmount: 10.0,
            estimatedDeliveryTime: "15-25 min",
            ownerId: "merchant2"
        ),
        Shop(
            id: "shop3",
            name: "Pharmacie Centrale",
            description: "Pharmacie de garde 24h/24",
            imageURL: "https://images.unsplash.com/photo-1631549916768-4119b2e5f926?w=400",
            address: "8 Boulevard Haussmann, 75009 Paris",
            latitude: 48.8738,
            longitude: 2.3323,
            category: .pharmacy,
            rating: 4.6,
            reviewCount: 56,
            isOpen: true,
            deliveryFee: 3.99,
            minOrderAmount: 20.0,
            estimatedDeliveryTime: "25-35 min",
            ownerId: "merchant3"
        ),
        Shop(
            id: "shop4",
            name: "Fleurs & Nature",
            description: "Fleuriste éco-responsable",
            imageURL: "https://images.unsplash.com/photo-1487530811176-3780de880c2d?w=400",
            address: "23 Rue du Faubourg Saint-Honoré, 75008 Paris",
            latitude: 48.8704,
            longitude: 2.3145,
            category: .flowers,
            rating: 4.7,
            reviewCount: 42,
            isOpen: true,
            deliveryFee: 4.99,
            minOrderAmount: 25.0,
            estimatedDeliveryTime: "30-45 min",
            ownerId: "merchant4"
        )
    ]

    static let products: [Product] = [
        // Bio Market Paris products
        Product(id: "prod1", name: "Panier de légumes bio", description: "Assortiment de légumes de saison", price: 12.99, imageURL: "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=200", category: "Légumes", shopId: "shop1", isAvailable: true, stock: 25),
        Product(id: "prod2", name: "Lait d'amande bio", description: "1L - Sans sucres ajoutés", price: 3.49, imageURL: "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=200", category: "Boissons", shopId: "shop1", isAvailable: true, stock: 50),
        Product(id: "prod3", name: "Œufs fermiers x6", description: "Poules élevées en plein air", price: 4.99, imageURL: "https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=200", category: "Frais", shopId: "shop1", isAvailable: true, stock: 30),
        Product(id: "prod4", name: "Pain complet bio", description: "500g - Farine de blé ancien", price: 3.99, imageURL: "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=200", category: "Boulangerie", shopId: "shop1", isAvailable: true, stock: 15),

        // Le Petit Boulanger products
        Product(id: "prod5", name: "Croissant au beurre", description: "Pur beurre AOP", price: 1.50, imageURL: "https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=200", category: "Viennoiseries", shopId: "shop2", isAvailable: true, stock: 40),
        Product(id: "prod6", name: "Pain au chocolat", description: "Chocolat noir 70%", price: 1.70, imageURL: "https://images.unsplash.com/photo-1530610476181-d83430b64dcd?w=200", category: "Viennoiseries", shopId: "shop2", isAvailable: true, stock: 35),
        Product(id: "prod7", name: "Baguette tradition", description: "Fabrication artisanale", price: 1.30, imageURL: "https://images.unsplash.com/photo-1549931319-a545dcf3bc73?w=200", category: "Pains", shopId: "shop2", isAvailable: true, stock: 50),
        Product(id: "prod8", name: "Tarte aux pommes", description: "Part individuelle", price: 4.50, imageURL: "https://images.unsplash.com/photo-1568571780765-9276ac8b75a2?w=200", category: "Pâtisseries", shopId: "shop2", isAvailable: true, stock: 12),

        // Pharmacie products
        Product(id: "prod9", name: "Doliprane 1000mg", description: "Boîte de 8 comprimés", price: 2.99, imageURL: "https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=200", category: "Médicaments", shopId: "shop3", isAvailable: true, stock: 100),
        Product(id: "prod10", name: "Vitamine C 500mg", description: "30 comprimés effervescents", price: 8.99, imageURL: "https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=200", category: "Vitamines", shopId: "shop3", isAvailable: true, stock: 45),

        // Fleuriste products
        Product(id: "prod11", name: "Bouquet Romantique", description: "Roses rouges et gypsophile", price: 35.00, imageURL: "https://images.unsplash.com/photo-1487530811176-3780de880c2d?w=200", category: "Bouquets", shopId: "shop4", isAvailable: true, stock: 10),
        Product(id: "prod12", name: "Orchidée Phalaenopsis", description: "En pot céramique", price: 29.99, imageURL: "https://images.unsplash.com/photo-1567748157439-651aca2ff064?w=200", category: "Plantes", shopId: "shop4", isAvailable: true, stock: 8)
    ]
}

// MARK: - Notification Service
import UserNotifications

@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var pendingNotifications: [UNNotificationRequest] = []

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            print("Notification authorization: \(granted)")
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Send Notifications

    func sendLocalNotification(title: String, body: String, delay: TimeInterval = 1) {
        guard isAuthorized else {
            print("Notifications not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            } else {
                print("Notification scheduled: \(title)")
            }
        }
    }

    func sendOrderStatusNotification(order: Order) {
        let title: String
        let body: String

        switch order.status {
        case .confirmed:
            title = "Commande confirmée"
            body = "Votre commande #\(order.id.prefix(8)) a été confirmée par le marchand"
        case .preparing:
            title = "Préparation en cours"
            body = "Votre commande est en cours de préparation"
        case .ready:
            title = "Commande prête"
            body = "Votre commande est prête et attend un livreur"
        case .pickedUp:
            title = "Livreur en route"
            body = "Votre commande a été récupérée et arrive bientôt !"
        case .delivering:
            title = "Livraison en cours"
            body = "Le livreur est en chemin vers vous"
        case .delivered:
            title = "Commande livrée"
            body = "Votre commande a été livrée. Bon appétit !"
        case .cancelled:
            title = "Commande annulée"
            body = "Votre commande a été annulée"
        default:
            return
        }

        sendLocalNotification(title: title, body: body)
    }

    func sendNewOrderNotification(forMerchant shopName: String, orderTotal: Double) {
        sendLocalNotification(
            title: "Nouvelle commande !",
            body: "Vous avez reçu une commande de \(String(format: "%.2f", orderTotal))€"
        )
    }

    func sendDeliveryAvailableNotification(count: Int) {
        sendLocalNotification(
            title: "Livraisons disponibles",
            body: "\(count) nouvelle(s) livraison(s) à proximité"
        )
    }

    // MARK: - Clear Notifications

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("Failed to clear badge: \(error)")
            }
        }
    }

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        clearBadge()
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        print("Notification tapped: \(response.notification.request.identifier)")
        completionHandler()
    }
}

// MARK: - Favorites Manager
@MainActor
final class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()

    @Published var favoriteShopIds: Set<String> = []
    @Published var favoriteProductIds: Set<String> = []

    private let shopsFavoritesKey = "favoriteShops"
    private let productsFavoritesKey = "favoriteProducts"

    private init() {
        loadFavorites()
    }

    // MARK: - Shops

    func isFavorite(shopId: String) -> Bool {
        favoriteShopIds.contains(shopId)
    }

    func toggleFavorite(shopId: String) {
        if favoriteShopIds.contains(shopId) {
            favoriteShopIds.remove(shopId)
        } else {
            favoriteShopIds.insert(shopId)
        }
        saveFavorites()
    }

    func addFavoriteShop(_ shopId: String) {
        favoriteShopIds.insert(shopId)
        saveFavorites()
    }

    func removeFavoriteShop(_ shopId: String) {
        favoriteShopIds.remove(shopId)
        saveFavorites()
    }

    // MARK: - Products

    func isFavorite(productId: String) -> Bool {
        favoriteProductIds.contains(productId)
    }

    func toggleFavorite(productId: String) {
        if favoriteProductIds.contains(productId) {
            favoriteProductIds.remove(productId)
        } else {
            favoriteProductIds.insert(productId)
        }
        saveFavorites()
    }

    // MARK: - Persistence

    private func loadFavorites() {
        if let shopIds = UserDefaults.standard.array(forKey: shopsFavoritesKey) as? [String] {
            favoriteShopIds = Set(shopIds)
        }
        if let productIds = UserDefaults.standard.array(forKey: productsFavoritesKey) as? [String] {
            favoriteProductIds = Set(productIds)
        }
        print("Loaded \(favoriteShopIds.count) favorite shops, \(favoriteProductIds.count) favorite products")
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteShopIds), forKey: shopsFavoritesKey)
        UserDefaults.standard.set(Array(favoriteProductIds), forKey: productsFavoritesKey)
    }

    // MARK: - Get Favorite Shops

    func getFavoriteShops() -> [Shop] {
        DataService.shared.shops.filter { favoriteShopIds.contains($0.id) }
    }

    func getFavoriteProducts() -> [Product] {
        DataService.shared.products.filter { favoriteProductIds.contains($0.id) }
    }
}

// MARK: - Review Manager
@MainActor
final class ReviewManager: ObservableObject {
    static let shared = ReviewManager()

    @Published var reviews: [Review] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()

    private init() {}

    struct Review: Identifiable, Codable {
        let id: String
        let orderId: String
        let shopId: String
        let userId: String
        let userName: String
        let rating: Int // 1-5
        let comment: String
        let createdAt: Date

        var ratingStars: String {
            String(repeating: "★", count: rating) + String(repeating: "☆", count: 5 - rating)
        }
    }

    func submitReview(orderId: String, shopId: String, rating: Int, comment: String) async throws {
        guard let user = AuthService.shared.userProfile else {
            throw NSError(domain: "ReviewManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        isLoading = true

        let reviewData: [String: Any] = [
            "orderId": orderId,
            "shopId": shopId,
            "userId": user.id,
            "userName": user.name,
            "rating": rating,
            "comment": comment,
            "createdAt": Timestamp(date: Date())
        ]

        do {
            let docRef = try await db.collection("reviews").addDocument(data: reviewData)

            let newReview = Review(
                id: docRef.documentID,
                orderId: orderId,
                shopId: shopId,
                userId: user.id,
                userName: user.name,
                rating: rating,
                comment: comment,
                createdAt: Date()
            )

            reviews.append(newReview)

            // Update shop rating (simplified - in production would use Cloud Functions)
            await updateShopRating(shopId: shopId)

            NotificationService.shared.sendLocalNotification(
                title: "Merci pour votre avis !",
                body: "Votre évaluation a été enregistrée."
            )
        } catch {
            print("Error submitting review: \(error)")
            throw error
        }

        isLoading = false
    }

    func loadReviews(forShop shopId: String) async {
        isLoading = true

        do {
            let snapshot = try await db.collection("reviews")
                .whereField("shopId", isEqualTo: shopId)
                .order(by: "createdAt", descending: true)
                .limit(to: 20)
                .getDocuments()

            var loadedReviews: [Review] = []

            for document in snapshot.documents {
                let data = document.data()
                let review = Review(
                    id: document.documentID,
                    orderId: data["orderId"] as? String ?? "",
                    shopId: data["shopId"] as? String ?? "",
                    userId: data["userId"] as? String ?? "",
                    userName: data["userName"] as? String ?? "Anonyme",
                    rating: data["rating"] as? Int ?? 5,
                    comment: data["comment"] as? String ?? "",
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
                loadedReviews.append(review)
            }

            reviews = loadedReviews
        } catch {
            print("Error loading reviews: \(error)")
        }

        isLoading = false
    }

    func hasReviewed(orderId: String) -> Bool {
        reviews.contains { $0.orderId == orderId }
    }

    private func updateShopRating(shopId: String) async {
        // Calculate average rating for the shop
        let shopReviews = reviews.filter { $0.shopId == shopId }
        guard !shopReviews.isEmpty else { return }

        let averageRating = Double(shopReviews.reduce(0) { $0 + $1.rating }) / Double(shopReviews.count)

        try? await db.collection("shops").document(shopId).updateData([
            "rating": averageRating,
            "totalOrders": shopReviews.count
        ])
    }

    // Demo reviews for testing
    static let demoReviews: [Review] = [
        Review(id: "r1", orderId: "o1", shopId: "shop1", userId: "u1", userName: "Marie L.", rating: 5, comment: "Excellent ! Produits frais et livraison rapide.", createdAt: Date().addingTimeInterval(-86400)),
        Review(id: "r2", orderId: "o2", shopId: "shop1", userId: "u2", userName: "Pierre D.", rating: 4, comment: "Très bon service, je recommande.", createdAt: Date().addingTimeInterval(-172800)),
        Review(id: "r3", orderId: "o3", shopId: "shop2", userId: "u3", userName: "Sophie M.", rating: 5, comment: "Les meilleurs croissants de Paris !", createdAt: Date().addingTimeInterval(-259200))
    ]
}

// MARK: - Address Manager
@MainActor
final class AddressManager: ObservableObject {
    static let shared = AddressManager()

    @Published var addresses: [SavedAddress] = []
    @Published var selectedAddressId: String?

    private let userDefaultsKey = "savedAddresses"
    private let selectedAddressKey = "selectedAddressId"

    struct SavedAddress: Identifiable, Codable, Equatable {
        let id: String
        var label: String // "Maison", "Travail", etc.
        var fullAddress: String
        var street: String
        var city: String
        var postalCode: String
        var country: String
        var latitude: Double
        var longitude: Double
        var isDefault: Bool
        var instructions: String?

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        static func == (lhs: SavedAddress, rhs: SavedAddress) -> Bool {
            lhs.id == rhs.id
        }
    }

    private init() {
        loadAddresses()
    }

    var defaultAddress: SavedAddress? {
        addresses.first { $0.isDefault } ?? addresses.first
    }

    var selectedAddress: SavedAddress? {
        if let id = selectedAddressId {
            return addresses.first { $0.id == id }
        }
        return defaultAddress
    }

    func addAddress(_ address: SavedAddress) {
        var newAddress = address
        // If first address, make it default
        if addresses.isEmpty {
            newAddress = SavedAddress(
                id: address.id,
                label: address.label,
                fullAddress: address.fullAddress,
                street: address.street,
                city: address.city,
                postalCode: address.postalCode,
                country: address.country,
                latitude: address.latitude,
                longitude: address.longitude,
                isDefault: true,
                instructions: address.instructions
            )
        }
        addresses.append(newAddress)
        saveAddresses()
    }

    func updateAddress(_ address: SavedAddress) {
        if let index = addresses.firstIndex(where: { $0.id == address.id }) {
            addresses[index] = address
            saveAddresses()
        }
    }

    func deleteAddress(id: String) {
        addresses.removeAll { $0.id == id }
        if selectedAddressId == id {
            selectedAddressId = defaultAddress?.id
        }
        saveAddresses()
    }

    func setDefault(id: String) {
        for i in addresses.indices {
            addresses[i] = SavedAddress(
                id: addresses[i].id,
                label: addresses[i].label,
                fullAddress: addresses[i].fullAddress,
                street: addresses[i].street,
                city: addresses[i].city,
                postalCode: addresses[i].postalCode,
                country: addresses[i].country,
                latitude: addresses[i].latitude,
                longitude: addresses[i].longitude,
                isDefault: addresses[i].id == id,
                instructions: addresses[i].instructions
            )
        }
        saveAddresses()
    }

    func selectAddress(id: String) {
        selectedAddressId = id
        UserDefaults.standard.set(id, forKey: selectedAddressKey)
    }

    private func saveAddresses() {
        if let encoded = try? JSONEncoder().encode(addresses) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadAddresses() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([SavedAddress].self, from: data) {
            addresses = decoded
        }
        selectedAddressId = UserDefaults.standard.string(forKey: selectedAddressKey)
    }

    // Create address from components
    func createAddress(label: String, street: String, city: String, postalCode: String, country: String = "France", instructions: String? = nil, coordinate: CLLocationCoordinate2D? = nil) -> SavedAddress {
        let fullAddress = "\(street), \(postalCode) \(city), \(country)"
        return SavedAddress(
            id: UUID().uuidString,
            label: label,
            fullAddress: fullAddress,
            street: street,
            city: city,
            postalCode: postalCode,
            country: country,
            latitude: coordinate?.latitude ?? 48.8566,
            longitude: coordinate?.longitude ?? 2.3522,
            isDefault: false,
            instructions: instructions
        )
    }
}

// MARK: - Promo Code Manager
@MainActor
final class PromoCodeManager: ObservableObject {
    static let shared = PromoCodeManager()

    @Published var appliedPromoCode: PromoCode?
    @Published var isValidating = false
    @Published var errorMessage: String?

    struct PromoCode: Identifiable, Codable {
        let id: String
        let code: String
        let discountType: DiscountType
        let discountValue: Double
        let minOrderAmount: Double?
        let maxDiscount: Double?
        let expiresAt: Date?
        let usageLimit: Int?
        let usedCount: Int

        enum DiscountType: String, Codable {
            case percentage
            case fixed
        }

        var isValid: Bool {
            if let expiresAt = expiresAt, expiresAt < Date() {
                return false
            }
            if let limit = usageLimit, usedCount >= limit {
                return false
            }
            return true
        }

        func calculateDiscount(forAmount amount: Double) -> Double {
            if let minAmount = minOrderAmount, amount < minAmount {
                return 0
            }

            var discount: Double
            switch discountType {
            case .percentage:
                discount = amount * (discountValue / 100)
            case .fixed:
                discount = discountValue
            }

            if let maxDiscount = maxDiscount {
                discount = min(discount, maxDiscount)
            }

            return min(discount, amount)
        }
    }

    private init() {}

    func validatePromoCode(_ code: String, orderAmount: Double) async -> Bool {
        isValidating = true
        errorMessage = nil

        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Demo promo codes
        let validCodes: [String: PromoCode] = [
            "BIENVENUE": PromoCode(id: "p1", code: "BIENVENUE", discountType: .percentage, discountValue: 10, minOrderAmount: 15, maxDiscount: 5, expiresAt: nil, usageLimit: 1, usedCount: 0),
            "PROMO20": PromoCode(id: "p2", code: "PROMO20", discountType: .percentage, discountValue: 20, minOrderAmount: 30, maxDiscount: 15, expiresAt: Date().addingTimeInterval(86400 * 30), usageLimit: 100, usedCount: 45),
            "LIVRAISON": PromoCode(id: "p3", code: "LIVRAISON", discountType: .fixed, discountValue: 3.99, minOrderAmount: 20, maxDiscount: nil, expiresAt: nil, usageLimit: nil, usedCount: 0),
            "GREENDROP": PromoCode(id: "p4", code: "GREENDROP", discountType: .percentage, discountValue: 15, minOrderAmount: nil, maxDiscount: 10, expiresAt: nil, usageLimit: nil, usedCount: 0)
        ]

        let upperCode = code.uppercased()

        guard let promo = validCodes[upperCode] else {
            errorMessage = "Code promo invalide"
            isValidating = false
            return false
        }

        guard promo.isValid else {
            errorMessage = "Ce code promo a expiré ou n'est plus disponible"
            isValidating = false
            return false
        }

        if let minAmount = promo.minOrderAmount, orderAmount < minAmount {
            errorMessage = "Commande minimum de \(String(format: "%.2f", minAmount)) € requise"
            isValidating = false
            return false
        }

        appliedPromoCode = promo
        isValidating = false
        return true
    }

    func removePromoCode() {
        appliedPromoCode = nil
        errorMessage = nil
    }

    func getDiscount(forAmount amount: Double) -> Double {
        appliedPromoCode?.calculateDiscount(forAmount: amount) ?? 0
    }
}

// MARK: - Tip Manager
@MainActor
final class TipManager: ObservableObject {
    static let shared = TipManager()

    @Published var selectedTipOption: TipOption = .none
    @Published var customTipAmount: Double = 0

    enum TipOption: Equatable {
        case none
        case percentage(Int) // 5, 10, 15, 20
        case custom

        var displayName: String {
            switch self {
            case .none: return "Pas de pourboire"
            case .percentage(let value): return "\(value)%"
            case .custom: return "Personnalisé"
            }
        }
    }

    let tipOptions: [TipOption] = [.none, .percentage(5), .percentage(10), .percentage(15), .percentage(20), .custom]

    private init() {}

    func calculateTip(forAmount amount: Double) -> Double {
        switch selectedTipOption {
        case .none:
            return 0
        case .percentage(let percent):
            return amount * Double(percent) / 100
        case .custom:
            return customTipAmount
        }
    }

    func reset() {
        selectedTipOption = .none
        customTipAmount = 0
    }
}

// MARK: - Scheduled Delivery Manager
@MainActor
final class ScheduledDeliveryManager: ObservableObject {
    static let shared = ScheduledDeliveryManager()

    @Published var isScheduled = false
    @Published var scheduledDate: Date = Date()
    @Published var selectedTimeSlot: TimeSlot?

    struct TimeSlot: Identifiable, Equatable {
        let id: String
        let startTime: Date
        let endTime: Date
        let isAvailable: Bool

        var displayString: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
        }
    }

    private init() {}

    func getAvailableTimeSlots(for date: Date) -> [TimeSlot] {
        var slots: [TimeSlot] = []
        let calendar = Calendar.current

        // Generate time slots from 9:00 to 21:00
        for hour in stride(from: 9, to: 21, by: 1) {
            guard let startTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date),
                  let endTime = calendar.date(bySettingHour: hour + 1, minute: 0, second: 0, of: date) else {
                continue
            }

            // Check if slot is in the future (at least 1 hour from now)
            let isAvailable = startTime > Date().addingTimeInterval(3600)

            slots.append(TimeSlot(
                id: "\(date.formatted(date: .numeric, time: .omitted))-\(hour)",
                startTime: startTime,
                endTime: endTime,
                isAvailable: isAvailable
            ))
        }

        return slots
    }

    func reset() {
        isScheduled = false
        scheduledDate = Date()
        selectedTimeSlot = nil
    }
}

// MARK: - App Settings Manager
@MainActor
final class AppSettingsManager: ObservableObject {
    static let shared = AppSettingsManager()

    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "appLanguage") }
    }

    let availableLanguages = [
        ("fr", "Français"),
        ("en", "English"),
        ("es", "Español"),
        ("de", "Deutsch")
    ]

    private init() {
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.language = UserDefaults.standard.string(forKey: "appLanguage") ?? "fr"
    }

    func resetToDefaults() {
        isDarkMode = false
        notificationsEnabled = true
        soundEnabled = true
        language = "fr"
    }
}
