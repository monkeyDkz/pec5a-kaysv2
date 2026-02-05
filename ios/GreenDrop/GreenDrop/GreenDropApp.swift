import SwiftUI
import SafariServices
import FirebaseCore

@main
struct GreenDropApp: App {
    @StateObject private var appState = AppState()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(appState.authService)
                .environmentObject(appState.cartManager)
                .environmentObject(appState.dataService)
        }
    }
}

// MARK: - App State
@MainActor
final class AppState: ObservableObject {
    let authService = AuthService.shared
    let cartManager = CartManager()
    let locationManager = LocationManager()
    let dataService = DataService.shared
    let notificationService = NotificationService.shared

    var currentUserRole: UserRole {
        guard let role = authService.userProfile?.role else { return .user }
        return UserRole(rawValue: role) ?? .user
    }

    init() {
        // Request notification permission on launch
        Task {
            _ = await notificationService.requestAuthorization()
        }

        // Observe auth changes to start/stop listeners
        setupAuthObserver()
    }

    private func setupAuthObserver() {
        // When user profile changes, setup appropriate listeners
        Task {
            for await _ in authService.$userProfile.values {
                await setupListenersForCurrentUser()
            }
        }
    }

    private var driverLocationTimer: Timer?

    func setupListenersForCurrentUser() async {
        guard let profile = authService.userProfile else {
            dataService.stopAllListeners()
            driverLocationTimer?.invalidate()
            driverLocationTimer = nil
            return
        }

        switch currentUserRole {
        case .user, .admin:
            // Client: listen to their orders
            dataService.startOrdersListener(forUser: profile.id)

        case .driver:
            // Driver: listen to available deliveries
            dataService.startDeliveriesListener(forDriver: profile.id)
            locationManager.requestPermission()
            locationManager.startUpdating()
            startDriverLocationTimer()

        case .merchant:
            // Merchant: listen to shop orders
            if let shopId = profile.shopId {
                dataService.startOrdersListener(forShop: shopId)
            } else {
                // Resolve shopId by ownerId
                if let shopId = await dataService.resolveShopId(forOwner: profile.id) {
                    dataService.startOrdersListener(forShop: shopId)
                }
            }
        }
    }

    private func startDriverLocationTimer() {
        driverLocationTimer?.invalidate()
        driverLocationTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                guard let location = self.locationManager.location else { return }
                await self.dataService.updateDriverLocation(
                    latitude: location.latitude,
                    longitude: location.longitude,
                    heading: self.locationManager.heading,
                    speed: self.locationManager.speed
                )
            }
        }
    }
}

// MARK: - User Role
enum UserRole: String {
    case user = "user"
    case driver = "driver"
    case merchant = "merchant"
    case admin = "admin"

    var displayName: String {
        switch self {
        case .user: return "Client"
        case .driver: return "Chauffeur"
        case .merchant: return "Marchand"
        case .admin: return "Administrateur"
        }
    }
}

// MARK: - Root View
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Group {
            if authService.isLoading {
                SplashView()
            } else if authService.isAuthenticated {
                MainView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .onAppear {
            print("🏠 RootView - isLoading: \(authService.isLoading), isAuthenticated: \(authService.isAuthenticated), userProfile: \(authService.userProfile?.email ?? "nil")")
        }
        .onChange(of: authService.isAuthenticated) { _, newValue in
            print("🔄 Auth changed - isAuthenticated: \(newValue), role: \(authService.userProfile?.role ?? "nil")")
        }
    }
}

// MARK: - Splash View
struct SplashView: View {
    var body: some View {
        ZStack {
            Color(hex: "#22C55E")
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)

                Text("GreenDrop")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
        }
    }
}

// MARK: - Main View
struct MainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        switch appState.currentUserRole {
        case .user:
            ClientTabView()
        case .driver:
            DriverTabView()
        case .merchant:
            MerchantTabView()
        case .admin:
            ClientTabView()
        }
    }
}

// MARK: - Tab Views
struct ClientTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var cartManager: CartManager

    var body: some View {
        TabView(selection: $selectedTab) {
            ClientHomeView()
                .tabItem { Label("Accueil", systemImage: "house.fill") }
                .tag(0)

            FavoritesView()
                .tabItem { Label("Favoris", systemImage: "heart.fill") }
                .tag(1)

            ClientOrdersView()
                .tabItem { Label("Commandes", systemImage: "bag.fill") }
                .tag(2)

            CartView()
                .tabItem { Label("Panier", systemImage: "cart.fill") }
                .tag(3)
                .badge(cartManager.cart.itemCount > 0 ? cartManager.cart.itemCount : 0)

            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.fill") }
                .tag(4)
        }
        .tint(Color(hex: "#22C55E"))
    }
}

struct DriverTabView: View {
    var body: some View {
        TabView {
            DriverDashboardView()
                .tabItem { Label("Dashboard", systemImage: "speedometer") }
            DriverDeliveriesView()
                .tabItem { Label("Livraisons", systemImage: "shippingbox.fill") }
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.fill") }
        }
        .tint(Color(hex: "#22C55E"))
    }
}

struct MerchantTabView: View {
    var body: some View {
        TabView {
            MerchantDashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
            MerchantOrdersView()
                .tabItem { Label("Commandes", systemImage: "list.clipboard.fill") }
            MerchantProductsView()
                .tabItem { Label("Produits", systemImage: "cube.box.fill") }
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.fill") }
        }
        .tint(Color(hex: "#22C55E"))
    }
}

// MARK: - Safari View (in-app browser for Stripe)
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1)
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showEditProfile = false
    @State private var isLoadingStripe = false
    @State private var stripeError: String?
    @State private var showStripeError = false
    @State private var stripeURL: URL?
    @State private var showStripeSafari = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(hex: "#22C55E"))

                        HStack(spacing: 8) {
                            Text(authService.userProfile?.name ?? "Utilisateur")
                                .font(.title2)
                                .fontWeight(.bold)

                            VerificationBadge()
                        }

                        Text(authService.userProfile?.email ?? "")
                            .foregroundColor(.secondary)

                        if let role = authService.userProfile?.role {
                            Text(UserRole(rawValue: role)?.displayName ?? role)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#22C55E").opacity(0.15))
                                .foregroundColor(Color(hex: "#22C55E"))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top)

                    // KYC Verification Section
                    KYCStatusView()
                        .padding(.horizontal)

                    // Stripe Connect Section (Merchants & Drivers)
                    if authService.userProfile?.role == "merchant" || authService.userProfile?.role == "driver" {
                        VStack(spacing: 0) {
                            if authService.userProfile?.stripeAccountId != nil {
                                // Already onboarded — show dashboard button
                                Button(action: {
                                    if authService.userProfile?.role == "driver" {
                                        openDriverDashboard()
                                    } else {
                                        openMerchantDashboard()
                                    }
                                }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "chart.bar.fill")
                                            .foregroundColor(Color(hex: "#6772E5"))
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Tableau de bord paiements")
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Text("Stripe Express")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if isLoadingStripe {
                                            ProgressView()
                                        } else {
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding()
                                }
                                .disabled(isLoadingStripe)
                            } else {
                                // Not onboarded — show form link
                                NavigationLink(destination: StripeOnboardingFormView()) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "creditcard.fill")
                                            .foregroundColor(Color(hex: "#6772E5"))
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Configurer les paiements")
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Text("Stripe Connect")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                        .padding(.horizontal)
                    }

                    // Info Section
                    VStack(spacing: 0) {
                        ProfileInfoRow(icon: "phone.fill", title: "Téléphone", value: authService.userProfile?.phone ?? "Non renseigné")
                        Divider().padding(.leading, 56)
                        ProfileInfoRow(icon: "mappin.circle.fill", title: "Adresse", value: authService.userProfile?.address ?? "Non renseignée")
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)

                    // Actions
                    VStack(spacing: 0) {
                        ProfileActionRow(icon: "pencil", title: "Modifier le profil", color: "#22C55E") {
                            showEditProfile = true
                        }
                        Divider().padding(.leading, 56)
                        NavigationLink(destination: AddressesListView()) {
                            ProfileActionRowStatic(icon: "mappin.circle.fill", title: "Mes adresses", color: "#3B82F6")
                        }
                        Divider().padding(.leading, 56)
                        NavigationLink(destination: SettingsView()) {
                            ProfileActionRowStatic(icon: "gearshape.fill", title: "Paramètres", color: "#6B7280")
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)

                    // Support Section
                    VStack(spacing: 0) {
                        NavigationLink(destination: FAQView()) {
                            ProfileActionRowStatic(icon: "questionmark.circle.fill", title: "Aide & FAQ", color: "#8B5CF6")
                        }
                        Divider().padding(.leading, 56)
                        NavigationLink(destination: ContactSupportView()) {
                            ProfileActionRowStatic(icon: "envelope.fill", title: "Contacter le support", color: "#22C55E")
                        }
                        Divider().padding(.leading, 56)
                        NavigationLink(destination: TermsOfServiceView()) {
                            ProfileActionRowStatic(icon: "doc.text.fill", title: "Conditions d'utilisation", color: "#6B7280")
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)

                    // Logout Button
                    Button(action: { try? authService.signOut() }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Déconnexion")
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Profil")
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .alert("Erreur", isPresented: $showStripeError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(stripeError ?? "Une erreur est survenue")
            }
            .sheet(isPresented: $showStripeSafari) {
                if let url = stripeURL {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
        }
    }

    private func openMerchantDashboard() {
        guard let shopId = authService.userProfile?.shopId else { return }
        isLoadingStripe = true

        Task {
            do {
                let url = try await PaymentService.shared.getDashboardURL(shopId: shopId)
                isLoadingStripe = false
                if let parsed = URL(string: url) {
                    stripeURL = parsed
                    showStripeSafari = true
                }
            } catch {
                isLoadingStripe = false
                stripeError = error.localizedDescription
                showStripeError = true
            }
        }
    }

    private func openDriverDashboard() {
        isLoadingStripe = true

        Task {
            do {
                let url = try await PaymentService.shared.getDriverDashboardURL()
                isLoadingStripe = false
                if let parsed = URL(string: url) {
                    stripeURL = parsed
                    showStripeSafari = true
                }
            } catch {
                isLoadingStripe = false
                stripeError = error.localizedDescription
                showStripeError = true
            }
        }
    }
}

// MARK: - Stripe Onboarding Form View
struct StripeOnboardingFormView: View {
    @EnvironmentObject var authService: AuthService

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var city = ""
    @State private var postalCode = ""
    @State private var iban = ""

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var stripeURL: URL?
    @State private var showStripeSafari = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "#6772E5"))

                    Text("Configurer les paiements")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Renseignez vos informations pour recevoir vos paiements automatiquement.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                // Form fields
                VStack(spacing: 16) {
                    // Name row
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Prenom")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Jean", text: $firstName)
                                .textContentType(.givenName)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nom")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Dupont", text: $lastName)
                                .textContentType(.familyName)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                    }

                    // Phone
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Telephone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("+33 6 12 34 56 78", text: $phone)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }

                    // Address
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Adresse")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("12 rue de la Paix", text: $address)
                            .textContentType(.streetAddressLine1)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }

                    // City + Postal code
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ville")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Paris", text: $city)
                                .textContentType(.addressCity)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Code postal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("75001", text: $postalCode)
                                .textContentType(.postalCode)
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        .frame(width: 120)
                    }

                    // IBAN
                    VStack(alignment: .leading, spacing: 6) {
                        Text("IBAN")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("FR76 3000 6000 0112 3456 7890 189", text: $iban)
                            .textContentType(.none)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }

                    Text("Vos informations bancaires sont securisees par Stripe. GreenDrop n'a jamais acces a votre IBAN.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal)

                // Submit button
                Button(action: { submitOnboarding() }) {
                    HStack(spacing: 12) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Image(systemName: "creditcard.fill")
                        Text("Finaliser sur Stripe")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#6772E5"))
                    .cornerRadius(14)
                }
                .disabled(isLoading)
                .padding(.horizontal)

                #if DEBUG
                // Test: open in Safari
                if let url = stripeURL {
                    Button(action: { UIApplication.shared.open(url) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "safari.fill")
                            Text("Ouvrir dans Safari (test)")
                        }
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                }
                #endif

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Paiements")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Erreur", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Une erreur est survenue")
        }
        .sheet(isPresented: $showStripeSafari) {
            if let url = stripeURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            prefillFromProfile()
        }
    }

    private func prefillFromProfile() {
        guard let profile = authService.userProfile else { return }
        let parts = profile.name.split(separator: " ", maxSplits: 1)
        if parts.count >= 1 { firstName = String(parts[0]) }
        if parts.count >= 2 { lastName = String(parts[1]) }
        phone = profile.phone ?? ""
        address = profile.address ?? ""
    }

    private func submitOnboarding() {
        isLoading = true

        let prefill = OnboardingPrefill(
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            address: address,
            city: city,
            postalCode: postalCode,
            iban: iban.replacingOccurrences(of: " ", with: "")
        )

        Task {
            do {
                let urlString: String
                if authService.userProfile?.role == "driver" {
                    urlString = try await PaymentService.shared.getDriverOnboardingURL(prefill: prefill)
                } else {
                    guard let shopId = authService.userProfile?.shopId else {
                        isLoading = false
                        errorMessage = "Shop introuvable"
                        showError = true
                        return
                    }
                    urlString = try await PaymentService.shared.getOnboardingURL(shopId: shopId, prefill: prefill)
                }

                isLoading = false
                if let parsed = URL(string: urlString) {
                    stripeURL = parsed
                    showStripeSafari = true
                }
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct ProfileActionRowStatic: View {
    let icon: String
    let title: String
    let color: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: color))
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct ProfileInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "#22C55E"))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
            }

            Spacer()
        }
        .padding()
    }
}

struct ProfileActionRow: View {
    let icon: String
    let title: String
    let color: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(Color(hex: color))
                    .frame(width: 24)

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations personnelles") {
                    TextField("Nom", text: $name)
                    TextField("Téléphone", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("Adresse de livraison") {
                    TextField("Adresse", text: $address, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Modifier le profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Enregistrer") {
                        authService.updateProfile(name: name, phone: phone, address: address)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                name = authService.userProfile?.name ?? ""
                phone = authService.userProfile?.phone ?? ""
                address = authService.userProfile?.address ?? ""
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
