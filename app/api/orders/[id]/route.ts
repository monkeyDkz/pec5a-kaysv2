import { NextRequest, NextResponse } from "next/server";
import { withAuth, handleApiError } from "@/lib/api-middleware";
import { adminDb } from "@/lib/firebase-admin";

/**
 * GET /api/orders/[id] - Récupérer les détails d'une commande
 */
export async function GET(
  request: NextRequest,
  context: { params: { id: string } }
) {
  return withAuth(async (req: NextRequest, auth) => {
    try {
      const orderId = context.params.id;
    const orderDoc = await adminDb.collection("orders").doc(orderId).get();

    if (!orderDoc.exists) {
      return NextResponse.json(
        { error: "Not Found", message: "Commande introuvable" },
        { status: 404 }
      );
    }

    const order = orderDoc.data();

    // Vérifier les permissions
    if (auth.userRole !== "admin" && order?.userId !== auth.userId) {
      return NextResponse.json(
        { error: "Forbidden", message: "Accès non autorisé" },
        { status: 403 }
      );
    }

    return NextResponse.json({
      success: true,
      order: {
        id: orderDoc.id,
        ...order,
        createdAt: order?.createdAt?.toDate?.()?.toISOString() || order?.createdAt,
        updatedAt: order?.updatedAt?.toDate?.()?.toISOString() || order?.updatedAt,
        estimatedDeliveryTime: order?.estimatedDeliveryTime?.toDate?.()?.toISOString() || order?.estimatedDeliveryTime,
      },
    });
  } catch (error) {
    return handleApiError(error);
  }
  })(request);
}

/**
 * PATCH /api/orders/[id] - Mettre à jour le statut d'une commande
 */
export async function PATCH(
  request: NextRequest,
  context: { params: { id: string } }
) {
  return withAuth(async (req: NextRequest, auth) => {
    try {
      const orderId = context.params.id;
    const body = await request.json();
    const { status, driverId } = body;

    if (!status) {
      return NextResponse.json(
        { error: "Bad Request", message: "Le champ 'status' est requis" },
        { status: 400 }
      );
    }

    const orderDoc = await adminDb.collection("orders").doc(orderId).get();
    if (!orderDoc.exists) {
      return NextResponse.json(
        { error: "Not Found", message: "Commande introuvable" },
        { status: 404 }
      );
    }

    const order = orderDoc.data();

    // Vérifier les permissions
    const isAdmin = auth.userRole === "admin";
    const isDriver = auth.userRole === "driver" && order?.driverId === auth.userId;
    const isMerchant = auth.userRole === "merchant" && order?.shopId; // TODO: vérifier merchantId

    if (!isAdmin && !isDriver && !isMerchant) {
      return NextResponse.json(
        { error: "Forbidden", message: "Vous n'avez pas la permission de modifier cette commande" },
        { status: 403 }
      );
    }

    // Mettre à jour la commande
    const updates: any = {
      status,
      updatedAt: new Date(),
    };

    if (driverId) {
      updates.driverId = driverId;
    }

    await adminDb.collection("orders").doc(orderId).update(updates);

    // Log d'activité
    await adminDb.collection("activities").add({
      type: "order_status_updated",
      orderId,
      userId: auth.userId,
      description: `Statut mis à jour: ${status}`,
      timestamp: new Date(),
    });

    // TODO: Envoyer notification push à l'utilisateur

    return NextResponse.json({
      success: true,
      message: "Commande mise à jour",
    });
  } catch (error) {
    return handleApiError(error);
  }
  })(request);
}
