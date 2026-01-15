import { NextRequest, NextResponse } from "next/server";
import { withAuth, handleApiError } from "@/lib/api-middleware";
import { adminDb } from "@/lib/firebase-admin";

/**
 * POST /api/orders - Créer une nouvelle commande
 */
export const POST = withAuth(async (request: NextRequest, auth) => {
  try {
    const body = await request.json();
    const { shopId, items, deliveryAddress, deliveryLocation, paymentMethod, notes } = body;

    // Validation
    if (!shopId || !items || !Array.isArray(items) || items.length === 0) {
      return NextResponse.json(
        { error: "Bad Request", message: "shopId et items sont requis" },
        { status: 400 }
      );
    }

    if (!deliveryAddress || !deliveryLocation?.latitude || !deliveryLocation?.longitude) {
      return NextResponse.json(
        { error: "Bad Request", message: "Adresse de livraison complète requise" },
        { status: 400 }
      );
    }

    // Vérifier que la boutique existe
    const shopDoc = await adminDb.collection("shops").doc(shopId).get();
    if (!shopDoc.exists) {
      return NextResponse.json(
        { error: "Not Found", message: "Boutique introuvable" },
        { status: 404 }
      );
    }

    // Calculer le total
    let total = 0;
    for (const item of items) {
      const productDoc = await adminDb.collection("products").doc(item.productId).get();
      if (!productDoc.exists) {
        return NextResponse.json(
          { error: "Not Found", message: `Produit ${item.productId} introuvable` },
          { status: 404 }
        );
      }
      const product = productDoc.data();
      total += product!.price * item.quantity;
    }

    // Ajouter frais de livraison (exemple: 5€)
    const deliveryFee = 5.0;
    total += deliveryFee;

    // Créer la commande
    const orderRef = adminDb.collection("orders").doc();
    const orderData = {
      id: orderRef.id,
      reference: `ORD-${Date.now()}`,
      userId: auth.userId,
      shopId,
      items,
      total,
      deliveryFee,
      status: "pending",
      paymentMethod: paymentMethod || "cash",
      paymentStatus: "pending",
      deliveryAddress,
      deliveryLocation,
      notes: notes || "",
      estimatedDeliveryTime: new Date(Date.now() + 30 * 60 * 1000), // +30 min
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    await orderRef.set(orderData);

    // Créer log d'activité
    await adminDb.collection("activities").add({
      type: "order_created",
      orderId: orderRef.id,
      userId: auth.userId,
      description: `Commande ${orderData.reference} créée`,
      timestamp: new Date(),
    });

    return NextResponse.json({
      success: true,
      order: orderData,
    });
  } catch (error) {
    return handleApiError(error);
  }
});
