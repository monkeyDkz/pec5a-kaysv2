# 🚀 PEC5A - Plateforme de Gestion de Livraisons

Application web d'administration pour gérer les livraisons, chauffeurs, commandes et zones légales en temps réel. Développée avec **Next.js 15**, **Firebase**, **TypeScript** et **MapCN**.

---

## 📋 Prérequis

Avant de commencer, assurez-vous d'avoir installé :

- **Node.js** >= 18.x ([Télécharger](https://nodejs.org/))
- **pnpm** >= 8.x (gestionnaire de paquets)
  ```bash
  npm install -g pnpm
  ```
- Un compte **Firebase** ([console.firebase.google.com](https://console.firebase.google.com))

---

## 🔧 Installation

### 1. Cloner le projet

```bash
cd chemin/vers/votre/dossier
# Le projet est déjà dans pec5a/
```

### 2. Installer les dépendances

```bash
cd pec5a
pnpm install
```

---

## ⚙️ Configuration Firebase

### 1. Créer un projet Firebase

1. Allez sur [Firebase Console](https://console.firebase.google.com)
2. Créez un nouveau projet (ex: `pec5a-demo`)
3. Activez **Authentication** → Email/Password
4. Activez **Firestore Database** → Mode production
5. Activez **Storage** (pour les photos/documents)

### 2. Obtenir les credentials Firebase

#### A) Configuration Web (Frontend)

1. Dans Firebase Console → **Project Settings** ⚙️
2. Section **Your apps** → Cliquez sur **Web** `</>`
3. Enregistrez l'app (ex: "PEC5A Web")
4. Copiez les valeurs de configuration

#### B) Configuration Admin SDK (Backend/Seed)

1. Dans Firebase Console → **Project Settings** ⚙️ → **Service accounts**
2. Cliquez sur **Generate new private key**
3. Téléchargez le fichier JSON
4. Conservez les valeurs `client_email` et `private_key`

### 3. Créer le fichier `.env.local`

Créez un fichier `.env.local` à la racine du projet :

```env
# Firebase Web Config (Frontend)
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXX
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=votre-projet.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=votre-projet-id
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=votre-projet.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=123456789012
NEXT_PUBLIC_FIREBASE_APP_ID=1:123456789012:web:abcdef123456

# Firebase Admin SDK (Backend - pour seed script)
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@votre-projet.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nVotreCléPrivée...\n-----END PRIVATE KEY-----\n"
```

⚠️ **Important :** Gardez les guillemets pour `FIREBASE_PRIVATE_KEY` et conservez les `\n`

---

## 🌱 Initialiser la base de données

### 1. Lancer le script de seed

Le script va créer 7 utilisateurs, 3 boutiques, 7 produits, 2 chauffeurs et 3 commandes :

```bash
pnpm seed
```

**Temps d'exécution :** ~10-15 secondes

### 2. Comptes créés

Le script créera automatiquement ces comptes :

| Rôle | Email | Mot de passe |
|------|-------|--------------|
| **Admin** | admin@greendrop.com | admin123 |
| Marchand 1 | merchant1@pec5a.com | merchant123 |
| Marchand 2 | merchant2@pec5a.com | merchant123 |
| Chauffeur 1 | driver1@pec5a.com | driver123 |
| Chauffeur 2 | driver2@pec5a.com | driver123 |
| Client 1 | client1@pec5a.com | client123 |
| Client 2 | client2@pec5a.com | client123 |

---

## 🚀 Lancer l'application

### Mode développement

```bash
pnpm dev
```

L'application sera disponible sur : **http://localhost:3000**

### Mode production

```bash
# Build
pnpm build

# Lancer
pnpm start
```

---

## 🎯 Utilisation de l'application

### 1. Connexion Admin

1. Ouvrez **http://localhost:3000**
2. Connectez-vous avec :
   - **Email :** admin@greendrop.com
   - **Mot de passe :** admin123

### 2. Navigation

L'interface admin comprend :

- **📊 Dashboard** - Vue d'ensemble (KPIs, graphiques, activité récente)
- **👥 Utilisateurs** - Gestion des comptes (admin, marchands, clients, chauffeurs)
- **📦 Commandes** - Suivi des livraisons en temps réel
- **✅ Vérifications** - Validation des documents (identité, véhicules, etc.)
- **⚠️ Litiges** - Résolution des réclamations clients
- **🗺️ Zones légales** - Dessin de zones de livraison/interdites
- **🚗 Chauffeurs** - Tracking GPS et gestion de la flotte
- **⚙️ Configuration** - Paramètres système

### 3. Fonctionnalités de démo

#### 🎬 Simulation de chauffeurs (pour présentation)

Sur la page **Chauffeurs** :

1. Cliquez sur le bouton **"Démo Live"** (en haut à droite)
2. Les chauffeurs commencent à se déplacer automatiquement sur la carte
3. Leurs statuts changent aléatoirement (en ligne, occupé, pause, hors ligne)
4. Pour arrêter : cliquez sur **"Arrêter simulation"**

**Utilité :** Montre un système "live" sans avoir besoin de vraie géolocalisation mobile

#### 🗺️ Zones légales interactives

Sur la page **Zones légales** :

1. Cliquez sur **"Nouvelle zone"**
2. Dessinez sur la carte en cliquant pour placer des points
3. Fermez le polygone en cliquant sur le premier point
4. Configurez le type (livraison autorisée / zone interdite)
5. Sauvegardez

#### 📱 Profil administrateur

Cliquez sur l'avatar en haut à droite :

- **Modifier le profil** - Changer le nom
- **Changer le mot de passe** - Sécurité du compte
- **Notifications** - Activer/désactiver les alertes
- **Déconnexion**

---

## 📂 Structure du projet

```
pec5a/
├── app/                          # Pages Next.js 15 (App Router)
│   ├── dashboard/               # Tableau de bord
│   ├── drivers/                 # Gestion chauffeurs + carte
│   ├── orders/                  # Commandes et suivi
│   ├── users/                   # Gestion utilisateurs
│   ├── verifications/           # Validation documents
│   ├── disputes/                # Litiges clients
│   ├── legal-zones/             # Zones de livraison
│   ├── config/                  # Configuration système
│   └── login/                   # Page de connexion
│
├── components/
│   ├── admin/                   # Composants admin (sidebar, topbar, modals, etc.)
│   └── ui/                      # Composants UI shadcn/ui + MapCN
│
├── lib/
│   ├── firebase/                # Configuration Firebase
│   │   ├── config.ts           # Initialisation Firebase
│   │   ├── auth-context.tsx    # Contexte d'authentification
│   │   ├── collections.ts      # Noms des collections Firestore
│   │   └── services/           # Services (users, drivers, orders, simulation)
│   ├── types.ts                 # Types TypeScript partagés
│   ├── utils.ts                 # Utilitaires (cn, formatage, etc.)
│   └── language-context.tsx     # Multi-langue (FR/EN)
│
├── hooks/                       # Hooks React personnalisés
│   ├── use-drivers.ts          # Hook pour les chauffeurs
│   ├── use-orders.ts           # Hook pour les commandes
│   └── use-toast.ts            # Notifications toast
│
├── scripts/
│   └── seed.ts                  # Script de peuplement de la base de données
│
├── public/                      # Assets statiques
├── styles/                      # CSS globaux
│
├── .env.local                   # Variables d'environnement (à créer)
├── package.json                 # Dépendances npm
├── tsconfig.json               # Configuration TypeScript
└── next.config.mjs             # Configuration Next.js
```

---

## 🛠️ Technologies utilisées

### Frontend
- **Next.js 15** - Framework React avec App Router
- **TypeScript** - Typage statique
- **Tailwind CSS** - Framework CSS utility-first
- **shadcn/ui** - Composants UI accessibles
- **MapCN** (MapLibre GL) - Cartographie interactive sans clé API
- **Recharts** - Graphiques et visualisations

### Backend
- **Firebase Authentication** - Gestion des utilisateurs
- **Firestore** - Base de données NoSQL temps réel
- **Firebase Storage** - Stockage de fichiers

### DevOps
- **pnpm** - Gestionnaire de paquets rapide
- **tsx** - Exécution TypeScript pour scripts

---

## 🎓 Commandes utiles

```bash
# Développement
pnpm dev                    # Lancer en mode dev
pnpm build                  # Build production
pnpm start                  # Lancer en mode production
pnpm lint                   # Vérifier le code

# Base de données
pnpm seed                   # Peupler la base avec données de démo

# Dépendances
pnpm install                # Installer les dépendances
pnpm add [package]          # Ajouter une dépendance
```

---

## 🐛 Résolution de problèmes

### Erreur : "Firebase config not found"
- Vérifiez que `.env.local` existe à la racine
- Vérifiez que toutes les variables `NEXT_PUBLIC_FIREBASE_*` sont définies

### Erreur : "Permission denied" lors du seed
- Vérifiez `FIREBASE_CLIENT_EMAIL` et `FIREBASE_PRIVATE_KEY`
- Assurez-vous que la clé privée a bien les `\n` et les guillemets

### La carte ne s'affiche pas
- Vérifiez la connexion internet (MapCN utilise des tuiles en ligne)
- Ouvrez la console (F12) pour voir les erreurs MapLibre

### Les chauffeurs ne bougent pas en simulation
- Cliquez sur le bouton **"Démo Live"** vert
- Vérifiez que Firestore n'a pas d'erreurs de permission dans la console

### Erreur de build TypeScript
```bash
# Nettoyer et réinstaller
rm -rf node_modules .next
pnpm install
pnpm build
```

---

## 📄 Données de démo

Le script seed crée automatiquement :

### Boutiques (Paris)
- **Bio Market Paris** - 45 Boulevard Saint-Germain, 75005
- **Épicerie du Marais** - 12 Rue des Rosiers, 75004
- **Délices de Montmartre** - 78 Rue Lepic, 75018

### Produits français
- Tomates Bio d'Île-de-France (2.5€/kg)
- Pommes de Normandie (3.2€/kg)
- Baguette Tradition (1.2€)
- Croissants Pur Beurre (1.5€/pce)
- Miel de Lavande de Provence (12€/pot)
- Huile d'Olive AOC Provence (15€/bouteille)
- Eau Minérale Évian (0.9€/bouteille)

### Chauffeurs
- **Thomas Bernard** - Moto (AB-123-CD) - Position : Paris Centre
- **Lucas Petit** - Voiture (EF-456-GH) - Position : Paris Nord

---

## 🎯 Pour la présentation

### Checklist avant la démo

- [ ] Firebase configuré et seed exécuté
- [ ] Connecté avec admin@greendrop.com
- [ ] Dashboard ouvert et fonctionnel
- [ ] Page Chauffeurs prête (avec bouton "Démo Live")
- [ ] Page Zones légales testée

### Scénario de démo suggéré

1. **Dashboard** (30s) - Montrer les KPIs et graphiques
2. **Chauffeurs** (2min) - Lancer la simulation live, montrer le tracking
3. **Zones légales** (1min) - Dessiner une zone sur la carte
4. **Commandes** (1min) - Filtrer et voir les détails
5. **Profil** (30s) - Montrer les paramètres admin

---

## 📧 Support

Pour toute question sur le projet :
- Consultez la [documentation Firebase](https://firebase.google.com/docs)
- Consultez la [documentation Next.js](https://nextjs.org/docs)
- Consultez la [documentation MapCN](https://mapcn.dev)

---

## 📝 Licence

Projet académique - PEC5A © 2026

---

**Développé avec ❤️ pour la démonstration académique**
