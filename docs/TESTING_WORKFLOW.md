# Guide de Test Complet - GreenDrop

## Comptes de Test

| Rôle | Email | Mot de passe |
|------|-------|--------------|
| **Client 1** | `client1@pec5a.com` | `client123` |
| **Client 2** | `client2@pec5a.com` | `client123` |
| **Livreur 1** | `driver1@pec5a.com` | `driver123` |
| **Livreur 2** | `driver2@pec5a.com` | `driver123` |
| **Marchand 1** | `merchant1@pec5a.com` | `merchant123` |
| **Marchand 2** | `merchant2@pec5a.com` | `merchant123` |
| **Admin** | `admin@greendrop.com` | `admin123` |

---

## Données de Démo

### Boutiques (4)
1. **GreenLeaf Paris** - 1er arr. - Livraison: 2.99€
2. **Le Chanvre Doré** - Marais - Livraison: 1.99€
3. **CBD Factory Bastille** - 11e arr. - Livraison: 2.49€
4. **Herbal House Montmartre** - 18e arr. - Livraison: 2.99€

### Produits
- Fleurs CBD: 6.90€ - 9.00€
- Huiles CBD: 12.90€ - 49.90€
- Résines: 7.50€ - 14.90€
- Cosmétiques: 14.90€ - 39.90€

### Carte de Test Stripe
- **Numéro**: `4242 4242 4242 4242`
- **Date**: Toute date future
- **CVC**: 3 chiffres au choix

---

## WORKFLOW 1: Parcours Client Complet

### 1.1 Connexion
- [ ] Ouvrir l'application iOS
- [ ] Se connecter avec `client1@pec5a.com` / `client123`
- [ ] Vérifier l'affichage du dashboard client
- [ ] Autoriser la localisation si demandé

### 1.2 Navigation Boutiques
- [ ] Voir la liste des 4 boutiques
- [ ] Utiliser la recherche (taper "Green")
- [ ] Appliquer filtre par note (4+ étoiles)
- [ ] Appliquer filtre par frais de livraison (max 2.50€)
- [ ] Réinitialiser les filtres
- [ ] Ouvrir une boutique (GreenLeaf Paris)

### 1.3 Consultation Produits
- [ ] Voir la liste des produits
- [ ] Filtrer par catégorie (Fleurs CBD)
- [ ] Voir les détails d'un produit
- [ ] Vérifier prix, description, stock

### 1.4 Gestion Panier
- [ ] Ajouter un produit au panier
- [ ] Modifier la quantité (+/-)
- [ ] Ajouter un 2e produit
- [ ] Vérifier le sous-total
- [ ] Supprimer un article
- [ ] Vider le panier
- [ ] Ré-ajouter des produits pour continuer

### 1.5 Checkout
- [ ] Ouvrir le panier → Checkout
- [ ] Entrer/sélectionner adresse de livraison
- [ ] Ajouter des instructions (ex: "Digicode 1234")
- [ ] Voir le résumé de commande

### 1.6 Code Promo (Optionnel)
- [ ] Entrer un code promo invalide → Message d'erreur
- [ ] Entrer un code valide (si disponible)
- [ ] Vérifier la réduction appliquée
- [ ] Supprimer le code promo

### 1.7 Pourboire
- [ ] Sélectionner un pourboire prédéfini (2€)
- [ ] Changer pour un pourcentage (15%)
- [ ] Sélectionner montant personnalisé
- [ ] Vérifier le total mis à jour

### 1.8 Paiement
- [ ] Cliquer "Payer"
- [ ] Entrer carte test: `4242 4242 4242 4242`
- [ ] Date future, CVC: 123
- [ ] Confirmer le paiement
- [ ] Vérifier la confirmation de commande

### 1.9 Suivi de Commande
- [ ] Voir le statut "En attente"
- [ ] Voir la progression visuelle
- [ ] Voir l'heure estimée de livraison
- [ ] Voir les détails de la commande

### 1.10 Chat avec Livreur
- [ ] Attendre qu'un livreur soit assigné
- [ ] Ouvrir le chat
- [ ] Envoyer un message "Bonjour"
- [ ] Voir le message envoyé

### 1.11 Après Livraison
- [ ] Recevoir notification "Commande livrée"
- [ ] Noter la boutique (1-5 étoiles)
- [ ] Ajouter un commentaire
- [ ] Noter le livreur (1-5 étoiles)
- [ ] Ajouter un pourboire supplémentaire (optionnel)
- [ ] Soumettre l'avis

---

## WORKFLOW 2: Parcours Livreur Complet

### 2.1 Connexion
- [ ] Ouvrir l'application iOS
- [ ] Se connecter avec `driver1@pec5a.com` / `driver123`
- [ ] Vérifier l'affichage du dashboard livreur

### 2.2 Dashboard
- [ ] Voir les statistiques du jour (livraisons, gains)
- [ ] Voir la note moyenne
- [ ] Voir les conseils de performance

### 2.3 Statut En Ligne
- [ ] Toggle "En ligne" activé
- [ ] Vérifier l'indicateur vert
- [ ] Toggle "Hors ligne"
- [ ] Vérifier l'indicateur gris
- [ ] Remettre "En ligne"

### 2.4 Accepter une Livraison
- [ ] Aller dans l'onglet "Livraisons"
- [ ] Voir les livraisons disponibles
- [ ] Voir les détails (boutique, adresse, gain)
- [ ] Cliquer "Accepter la livraison"
- [ ] Vérifier la carte de livraison active

### 2.5 Progression de Livraison
- [ ] Voir l'itinéraire sur la carte miniature
- [ ] Cliquer "Carte" pour vue plein écran
- [ ] Fermer la carte
- [ ] Cliquer "Au magasin" (arrivé à la boutique)
- [ ] Cliquer "Récupérée" (commande récupérée)
- [ ] Cliquer "En route" (en direction du client)

### 2.6 Chat avec Client
- [ ] Cliquer "Chat"
- [ ] Voir les messages du client (si envoyés)
- [ ] Répondre "Je suis en route"
- [ ] Fermer le chat

### 2.7 Preuve de Livraison
- [ ] Arriver à destination
- [ ] Cliquer "Livrée"
- [ ] **Écran Preuve de Livraison apparaît**
- [ ] Prendre une photo de la livraison
- [ ] Collecter la signature du client (dessiner sur l'écran)
- [ ] Ajouter une note (optionnel): "Laissé à la porte"
- [ ] Soumettre la preuve
- [ ] Vérifier "Livraison terminée"

### 2.8 Historique & Gains
- [ ] Aller dans "Actions rapides" → "Historique"
- [ ] Voir les livraisons passées
- [ ] Aller dans "Gains"
- [ ] Voir les gains par jour/semaine/mois
- [ ] Aller dans "Pourboires"
- [ ] Voir le résumé des pourboires

---

## WORKFLOW 3: Vérification d'Identité (KYC)

### 3.1 Déclenchement
- [ ] Se connecter avec un nouveau compte OU client sans KYC
- [ ] Ajouter un produit CBD au panier
- [ ] Aller au checkout
- [ ] **Message "Vérification d'âge requise" apparaît**
- [ ] Le bouton "Payer" est désactivé

### 3.2 Processus KYC
- [ ] Cliquer "Vérifier mon identité"
- [ ] Remplir le formulaire:
  - Prénom: Test
  - Nom: Utilisateur
  - Date de naissance: (plus de 18 ans)
  - Type de document: Carte d'identité
  - Numéro: AB123456
- [ ] Prendre/uploader photo recto du document
- [ ] Prendre/uploader photo verso du document
- [ ] Prendre un selfie
- [ ] Soumettre la demande
- [ ] Voir statut "En attente de vérification"

### 3.3 Approbation (Admin)
- [ ] Ouvrir Firebase Console
- [ ] Aller dans Firestore → Collection "verifications"
- [ ] Trouver le document de l'utilisateur
- [ ] Changer `status` de "pending" à "approved"
- [ ] Sauvegarder

### 3.4 Vérification Approuvée
- [ ] Retourner dans l'app
- [ ] Rafraîchir ou rouvrir l'app
- [ ] Vérifier statut "Identité vérifiée"
- [ ] Retourner au checkout
- [ ] Le bouton "Payer" est maintenant actif
- [ ] Finaliser la commande

---

## WORKFLOW 4: Flux Complet Multi-Utilisateurs

> **Nécessite 2 appareils/simulateurs ou test séquentiel**

### Étape 1: Client crée une commande
- [ ] Client se connecte (`client1@pec5a.com`)
- [ ] Ajoute des produits au panier
- [ ] Passe commande et paie

### Étape 2: Marchand confirme
- [ ] Marchand se connecte (`merchant1@pec5a.com`)
- [ ] Voit la nouvelle commande
- [ ] Change statut: Confirmée → En préparation → Prête

### Étape 3: Livreur récupère
- [ ] Livreur se connecte (`driver1@pec5a.com`)
- [ ] Active statut "En ligne"
- [ ] Voit la livraison disponible
- [ ] Accepte la livraison

### Étape 4: Communication
- [ ] Client envoie message: "Vous arrivez quand?"
- [ ] Livreur reçoit et répond: "Dans 10 minutes"
- [ ] Client voit la réponse

### Étape 5: Livraison
- [ ] Livreur progresse: Au magasin → Récupérée → En route
- [ ] Client voit les mises à jour en temps réel
- [ ] Livreur arrive et capture preuve de livraison
- [ ] Commande marquée "Livrée"

### Étape 6: Finalisation
- [ ] Client reçoit notification
- [ ] Client note boutique et livreur
- [ ] Livreur voit la note reçue
- [ ] Livreur voit le pourboire (si donné)

---

## WORKFLOW 5: Cas d'Erreur

### 5.1 Paiement Échoué
- [ ] Aller au checkout
- [ ] Utiliser carte test échec: `4000 0000 0000 0002`
- [ ] Vérifier message d'erreur
- [ ] Réessayer avec carte valide

### 5.2 Code Promo Invalide
- [ ] Entrer code "FAUX123"
- [ ] Vérifier message "Code invalide"

### 5.3 Connexion Échouée
- [ ] Entrer mauvais mot de passe
- [ ] Vérifier message d'erreur
- [ ] Réessayer avec bon mot de passe

### 5.4 Livreur Hors Ligne
- [ ] Livreur passe "Hors ligne"
- [ ] Vérifier qu'il ne reçoit plus de livraisons
- [ ] Repasser "En ligne"

---

## WORKFLOW 6: Fonctionnalités Additionnelles

### 6.1 Gestion des Adresses
- [ ] Aller dans Profil → Adresses
- [ ] Ajouter une nouvelle adresse
- [ ] Définir comme adresse par défaut
- [ ] Modifier une adresse existante
- [ ] Supprimer une adresse

### 6.2 Livraison Programmée
- [ ] Au checkout, activer "Livraison programmée"
- [ ] Sélectionner une date
- [ ] Sélectionner un créneau horaire
- [ ] Vérifier dans le résumé

### 6.3 Historique des Commandes
- [ ] Aller dans "Mes commandes"
- [ ] Voir les commandes en cours
- [ ] Voir les commandes passées
- [ ] Ouvrir détails d'une commande
- [ ] Voir la preuve de livraison (si disponible)

### 6.4 Avis sur les Boutiques
- [ ] Ouvrir une boutique
- [ ] Voir la section "Avis"
- [ ] Lire les commentaires des autres clients
- [ ] Voir la distribution des notes

---

## Checklist Récapitulative

### Fonctionnalités Core
- [ ] Authentification (connexion/déconnexion)
- [ ] Navigation boutiques
- [ ] Recherche et filtres
- [ ] Gestion panier
- [ ] Checkout complet
- [ ] Paiement Stripe
- [ ] Suivi commande temps réel
- [ ] Chat client ↔ livreur
- [ ] Preuve de livraison
- [ ] Notation et avis
- [ ] Pourboires

### Vérification d'Identité
- [ ] Déclenchement sur produit 18+
- [ ] Formulaire KYC complet
- [ ] Upload documents
- [ ] Approbation admin
- [ ] Déblocage achat

### Rôles
- [ ] Parcours client fonctionnel
- [ ] Parcours livreur fonctionnel
- [ ] Dashboard marchand (si testé)

### Robustesse
- [ ] Gestion erreurs paiement
- [ ] Gestion erreurs réseau
- [ ] Validation formulaires

---

## Notes Techniques

### Firebase Console
- **URL**: https://console.firebase.google.com
- **Collections importantes**:
  - `users` - Profils utilisateurs
  - `orders` - Commandes
  - `shops` - Boutiques
  - `products` - Produits
  - `deliveries` - Livraisons
  - `verifications` - KYC
  - `chats/{orderId}/messages` - Messages

### Stripe Dashboard
- **URL**: https://dashboard.stripe.com/test
- Vérifier les paiements de test
- Voir les PaymentIntents créés

### Simulateur iOS
- Utiliser iPhone 15 Pro ou similaire
- Activer la localisation simulée si besoin
- Pour les photos: le simulateur utilise la bibliothèque

---

## Résolution de Problèmes

| Problème | Solution |
|----------|----------|
| "No such module Firebase" | File → Packages → Resolve Package Versions |
| Boutiques ne chargent pas | Vérifier `pnpm seed` exécuté |
| Paiement échoue toujours | Vérifier clés Stripe dans `.env.local` |
| KYC bloqué sur "pending" | Approuver manuellement dans Firestore |
| Chat ne fonctionne pas | Vérifier les règles Firestore |
| Localisation non disponible | Autoriser dans Réglages simulateur |
