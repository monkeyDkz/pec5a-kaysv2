import { NextRequest, NextResponse } from "next/server";
import { withAuth, handleApiError } from "@/lib/api-middleware";
import { adminDb } from "@/lib/firebase-admin";

/**
 * GET /api/orders/my - Récupérer les commandes de l'utilisateur connecté
 */
export const GET = withAuth(async (request: NextRequest, auth) => {
  try {
    const { searchParams } = new URL(request.url);
    const status = searchParams.get("status");

    let query = adminDb.collection("orders").where("userId", "==", auth.userId);

    // Filtrer par status si fourni
    if (status) {
      query = query.where("status", "==", status) as any;
    }

    const snapshot = await query.orderBy("createdAt", "desc").get();

    const orders = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || doc.data().createdAt,
      updatedAt: doc.data().updatedAt?.toDate?.()?.toISOString() || doc.data().updatedAt,
      estimatedDeliveryTime: doc.data().estimatedDeliveryTime?.toDate?.()?.toISOString() || doc.data().estimatedDeliveryTime,
    }));

    return NextResponse.json({
      success: true,
      orders,
    });
  } catch (error) {
    return handleApiError(error);
  }
});
