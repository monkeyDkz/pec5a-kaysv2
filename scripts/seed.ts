/**
 * Seed Script for PEC5A - Academic Demo
 * 
 * This script populates Firestore with demo data for presentation
 * 
 * Run: pnpm seed
 */

import { config } from 'dotenv';
import { resolve } from 'path';

// Load environment variables from .env or .env.local
config({ path: resolve(__dirname, '../.env.local') });
config({ path: resolve(__dirname, '../.env') });

import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

console.log('🔍 Checking environment variables...');
console.log('Project ID:', process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID);
console.log('Client Email:', process.env.FIREBASE_CLIENT_EMAIL);
console.log('Private Key exists:', !!process.env.FIREBASE_PRIVATE_KEY);
console.log('Private Key length:', process.env.FIREBASE_PRIVATE_KEY?.length || 0);

// Initialize Firebase Admin
if (!getApps().length) {
  initializeApp({
    credential: cert({
      projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

const db = getFirestore();
const auth = getAuth();

// Demo data
const DEMO_USERS = [
  {
    email: 'admin@greendrop.com',
    password: 'admin123',
    name: 'Admin Principal',
    role: 'admin',
    status: 'verified',
    phone: '+33 6 12 34 56 78',
  },
  {
    email: 'merchant1@pec5a.com',
    password: 'merchant123',
    name: 'Pierre Dubois',
    role: 'merchant',
    status: 'verified',
    phone: '+33 6 23 45 67 89',
  },
  {
    email: 'merchant2@pec5a.com',
    password: 'merchant123',
    name: 'Sophie Martin',
    role: 'merchant',
    status: 'verified',
    phone: '+33 6 34 56 78 90',
  },
  {
    email: 'driver1@pec5a.com',
    password: 'driver123',
    name: 'Thomas Bernard',
    role: 'driver',
    status: 'verified',
    phone: '+33 6 45 67 89 01',
  },
  {
    email: 'driver2@pec5a.com',
    password: 'driver123',
    name: 'Lucas Petit',
    role: 'driver',
    status: 'verified',
    phone: '+33 6 56 78 90 12',
  },
  {
    email: 'client1@pec5a.com',
    password: 'client123',
    name: 'Marie Lefebvre',
    role: 'user',
    status: 'verified',
    phone: '+33 6 67 89 01 23',
  },
  {
    email: 'client2@pec5a.com',
    password: 'client123',
    name: 'Antoine Moreau',
    role: 'user',
    status: 'verified',
    phone: '+33 6 78 90 12 34',
  },
];

const DEMO_SHOPS = [
  {
    ownerId: '', // Will be set dynamically
    name: 'Bio Market Paris',
    ownerName: 'Pierre Dubois',
    status: 'active',
    approvalStatus: 'approved',
    address: '45 Boulevard Saint-Germain, 75005 Paris',
    contactEmail: 'contact@biomarket.fr',
    contactPhone: '+33 1 42 12 34 56',
    categories: ['Fruits & Légumes', 'Bio', 'Local'],
    rating: 4.7,
    totalOrders: 245,
    totalProducts: 0,
  },
  {
    ownerId: '',
    name: 'Épicerie du Marais',
    ownerName: 'Sophie Martin',
    status: 'active',
    approvalStatus: 'approved',
    address: '12 Rue des Rosiers, 75004 Paris',
    contactEmail: 'epicerie@marais.fr',
    contactPhone: '+33 1 48 87 65 43',
    categories: ['Épicerie', 'Snacks', 'Boissons'],
    rating: 4.5,
    totalOrders: 189,
    totalProducts: 0,
  },
  {
    ownerId: '',
    name: 'Délices de Montmartre',
    ownerName: 'Sophie Martin',
    status: 'pending',
    approvalStatus: 'pending',
    address: '78 Rue Lepic, 75018 Paris',
    contactEmail: 'contact@delices-montmartre.fr',
    contactPhone: '+33 1 46 06 12 34',
    categories: ['Pâtisserie', 'Boulangerie'],
    rating: 0,
    totalOrders: 0,
    totalProducts: 0,
  },
];

const DEMO_PRODUCTS = [
  // Bio Market Paris
  {
    shopId: '',
    shopName: 'Bio Market Paris',
    name: 'Tomates Bio d\'Île-de-France',
    description: 'Tomates fraîches cultivées localement sans pesticides',
    sku: 'BIO-TOM-001',
    category: 'Fruits & Légumes',
    tags: ['bio', 'local', 'frais'],
    price: 4.5,
    stock: 150,
    minStock: 20,
    status: 'active',
    featured: true,
    imageUrl: 'https://images.unsplash.com/photo-1546094096-0df4bcaaa337?w=400',
  },
  {
    shopId: '',
    shopName: 'Bio Market Paris',
    name: 'Pommes de Normandie',
    description: 'Pommes juteuses et croquantes de Normandie',
    sku: 'BIO-POM-002',
    category: 'Fruits & Légumes',
    tags: ['fruits', 'local', 'normandie'],
    price: 3.5,
    stock: 200,
    minStock: 30,
    status: 'active',
    featured: true,
    imageUrl: 'https://images.unsplash.com/photo-1547514701-42782101795e?w=400',
  },
  {
    shopId: '',
    shopName: 'Bio Market Paris',
    name: 'Huile d\'Olive de Provence',
    description: 'Huile d\'olive premium AOP de Provence',
    sku: 'BIO-OIL-003',
    category: 'Épicerie',
    tags: ['bio', 'premium', 'provence'],
    price: 12.0,
    stock: 45,
    minStock: 10,
    status: 'active',
    featured: false,
    imageUrl: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400',
  },
  {
    shopId: '',
    shopName: 'Bio Market Paris',
    name: 'Miel de Lavande',
    description: 'Miel naturel de lavande récolté en Provence',
    sku: 'BIO-HON-004',
    category: 'Épicerie',
    tags: ['miel', 'naturel', 'artisanal'],
    price: 8.5,
    stock: 30,
    minStock: 5,
    status: 'active',
    featured: true,
    imageUrl: 'https://images.unsplash.com/photo-1587049352846-4a222e784386?w=400',
  },
  // Épicerie du Marais
  {
    shopId: '',
    shopName: 'Épicerie du Marais',
    name: 'Baguette Tradition',
    description: 'Baguette tradition cuite au four tous les matins',
    sku: 'EPM-BAG-001',
    category: 'Boulangerie',
    tags: ['frais', 'quotidien', 'artisanal'],
    price: 1.2,
    stock: 80,
    minStock: 20,
    status: 'active',
    featured: true,
    imageUrl: 'https://images.unsplash.com/photo-1549931319-a545dcf3bc73?w=400',
  },
  {
    shopId: '',
    shopName: 'Épicerie du Marais',
    name: 'Croissants Pur Beurre',
    description: 'Croissants pur beurre AOC faits maison',
    sku: 'EPM-CRO-002',
    category: 'Boulangerie',
    tags: ['viennoiserie', 'beurre', 'petit-déjeuner'],
    price: 1.5,
    stock: 50,
    minStock: 15,
    status: 'active',
    featured: false,
    imageUrl: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=400',
  },
  {
    shopId: '',
    shopName: 'Épicerie du Marais',
    name: 'Eau Minérale Évian 1.5L',
    description: 'Eau minérale naturelle des Alpes',
    sku: 'EPM-EAU-003',
    category: 'Boissons',
    tags: ['eau', 'hydratation'],
    price: 1.5,
    stock: 120,
    minStock: 30,
    status: 'active',
    featured: false,
    imageUrl: 'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=400',
  },
];

const DEMO_DRIVERS = [
  {
    id: '',
    name: 'Thomas Bernard',
    email: 'driver1@pec5a.com',
    phone: '+33 6 45 67 89 01',
    status: 'online',
    vehicleType: 'moto',
    vehiclePlate: 'AB-123-CD',
    rating: 4.8,
    completedDeliveries: 342,
    location: {
      lat: 48.8566,
      lng: 2.3522,
      updatedAt: new Date().toISOString(),
    },
    lastSeenAt: new Date().toISOString(),
  },
  {
    id: '',
    name: 'Lucas Petit',
    email: 'driver2@pec5a.com',
    phone: '+33 6 56 78 90 12',
    status: 'busy',
    vehicleType: 'voiture',
    vehiclePlate: 'EF-456-GH',
    rating: 4.6,
    completedDeliveries: 267,
    location: {
      lat: 48.8606,
      lng: 2.3376,
      updatedAt: new Date().toISOString(),
    },
    lastSeenAt: new Date().toISOString(),
  },
];

const DEMO_ORDERS = [
  {
    userId: '',
    shopId: '',
    status: 'delivered',
    priority: 'normal',
    reference: 'ORD-2025-001',
    total: 42.5,
    currency: 'EUR',
    driverId: '',
    driverName: 'Thomas Bernard',
    driverPhone: '+33 6 45 67 89 01',
    pickupAddress: '45 Boulevard Saint-Germain, 75005 Paris',
    dropoffAddress: '123 Rue de Rivoli, 75001 Paris',
    expectedDelivery: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
    deliveredAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
    items: [],
  },
  {
    userId: '',
    shopId: '',
    status: 'shipped',
    priority: 'high',
    reference: 'ORD-2025-002',
    total: 28.0,
    currency: 'EUR',
    driverId: '',
    driverName: 'Lucas Petit',
    driverPhone: '+33 6 56 78 90 12',
    pickupAddress: '12 Rue des Rosiers, 75004 Paris',
    dropoffAddress: '56 Avenue des Champs-Élysées, 75008 Paris',
    expectedDelivery: new Date(Date.now() + 1 * 60 * 60 * 1000).toISOString(),
    items: [],
  },
  {
    userId: '',
    shopId: '',
    status: 'paid',
    priority: 'urgent',
    reference: 'ORD-2025-003',
    total: 52.0,
    currency: 'EUR',
    pickupAddress: '45 Boulevard Saint-Germain, 75005 Paris',
    dropoffAddress: '89 Boulevard Haussmann, 75009 Paris',
    expectedDelivery: new Date(Date.now() + 3 * 60 * 60 * 1000).toISOString(),
    items: [],
  },
];

async function clearCollection(collectionName: string) {
  console.log(`🗑️  Clearing ${collectionName}...`);
  const snapshot = await db.collection(collectionName).get();
  const batch = db.batch();
  snapshot.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
  console.log(`✅ Cleared ${snapshot.size} documents from ${collectionName}`);
}

async function seedUsers() {
  console.log('\n👥 Creating users...');
  
  const userIds: Record<string, string> = {};
  
  for (const userData of DEMO_USERS) {
    try {
      // Create auth user
      const userRecord = await auth.createUser({
        email: userData.email,
        password: userData.password,
        displayName: userData.name,
        emailVerified: true,
      });
      
      userIds[userData.email] = userRecord.uid;
      
      // Create Firestore profile
      await db.collection('users').doc(userRecord.uid).set({
        email: userData.email,
        name: userData.name,
        role: userData.role,
        status: userData.status,
        phone: userData.phone,
        createdAt: Timestamp.now(),
      });
      
      console.log(`✅ Created user: ${userData.name} (${userData.role})`);
    } catch (error: any) {
      if (error.code === 'auth/email-already-exists') {
        const existingUser = await auth.getUserByEmail(userData.email);
        userIds[userData.email] = existingUser.uid;
        console.log(`⚠️  User already exists: ${userData.email}`);
      } else {
        console.error(`❌ Error creating user ${userData.email}:`, error.message);
      }
    }
  }
  
  return userIds;
}

async function seedShops(userIds: Record<string, string>) {
  console.log('\n🏪 Creating shops...');
  
  const shopIds: string[] = [];
  
  for (const shopData of DEMO_SHOPS) {
    const ownerEmail = shopData.ownerName === 'Pierre Dubois' 
      ? 'merchant1@pec5a.com' 
      : 'merchant2@pec5a.com';
    
    const shopDoc = await db.collection('shops').add({
      ...shopData,
      ownerId: userIds[ownerEmail],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    
    shopIds.push(shopDoc.id);
    console.log(`✅ Created shop: ${shopData.name}`);
  }
  
  return shopIds;
}

async function seedProducts(shopIds: string[]) {
  console.log('\n📦 Creating products...');
  
  for (const productData of DEMO_PRODUCTS) {
    const shopIndex = productData.shopName === 'Bio Market Paris' ? 0 : 1;
    
    await db.collection('products').add({
      ...productData,
      shopId: shopIds[shopIndex],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    
    console.log(`✅ Created product: ${productData.name}`);
  }
  
  // Update shop product counts
  for (const shopId of shopIds.slice(0, 2)) {
    const productsCount = DEMO_PRODUCTS.filter(
      p => p.shopName === (shopId === shopIds[0] ? 'Bio Market Paris' : 'Épicerie du Marais')
    ).length;
    
    await db.collection('shops').doc(shopId).update({
      totalProducts: productsCount,
    });
  }
}

async function seedDrivers(userIds: Record<string, string>) {
  console.log('\n🚗 Creating drivers...');
  
  const driverIds: string[] = [];
  
  for (const driverData of DEMO_DRIVERS) {
    const driverId = userIds[driverData.email];
    
    await db.collection('drivers').doc(driverId).set({
      ...driverData,
      id: driverId,
      createdAt: Timestamp.now(),
    });
    
    driverIds.push(driverId);
    console.log(`✅ Created driver: ${driverData.name}`);
  }
  
  return driverIds;
}

async function seedOrders(userIds: Record<string, string>, shopIds: string[], driverIds: string[]) {
  console.log('\n📋 Creating orders...');
  
  DEMO_ORDERS[0].userId = userIds['client1@pec5a.com'];
  DEMO_ORDERS[0].shopId = shopIds[0];
  DEMO_ORDERS[0].driverId = driverIds[0];
  
  DEMO_ORDERS[1].userId = userIds['client2@pec5a.com'];
  DEMO_ORDERS[1].shopId = shopIds[1];
  DEMO_ORDERS[1].driverId = driverIds[1];
  
  DEMO_ORDERS[2].userId = userIds['client1@pec5a.com'];
  DEMO_ORDERS[2].shopId = shopIds[0];
  
  for (const orderData of DEMO_ORDERS) {
    await db.collection('orders').add({
      ...orderData,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    
    console.log(`✅ Created order: ${orderData.reference}`);
  }
}

async function main() {
  console.log('🌱 Starting seed process...\n');
  
  try {
    // Clear existing data (optional - comment out if you want to keep existing data)
    // await clearCollection('users');
    // await clearCollection('shops');
    // await clearCollection('products');
    // await clearCollection('drivers');
    // await clearCollection('orders');
    
    const userIds = await seedUsers();
    const shopIds = await seedShops(userIds);
    await seedProducts(shopIds);
    const driverIds = await seedDrivers(userIds);
    await seedOrders(userIds, shopIds, driverIds);
    
    console.log('\n✅ Seed completed successfully!');
    console.log('\n📝 Demo Credentials:');
    console.log('Admin: admin@greendrop.com / admin123');
    console.log('Merchant 1: merchant1@pec5a.com / merchant123');
    console.log('Merchant 2: merchant2@pec5a.com / merchant123');
    console.log('Driver 1: driver1@pec5a.com / driver123');
    console.log('Driver 2: driver2@pec5a.com / driver123');
    console.log('Client 1: client1@pec5a.com / client123');
    console.log('Client 2: client2@pec5a.com / client123');
    
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Seed failed:', error);
    process.exit(1);
  }
}

main();
