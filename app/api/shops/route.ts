import { NextRequest, NextResponse } from "next/server";
import { withAuth, handleApiError } from "@/lib/api-middleware";
import { adminDb } from "@/lib/firebase-admin";

/**
 * Calculer la distance en km entre deux coordonnées (formule Haversine)
 */
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Rayon de la Terre en km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * GET /api/shops - Récupérer la liste des boutiques avec filtres
 */
export const GET = withAuth(async (request: NextRequest) => {
  try {
    const { searchParams } = new URL(request.url);
    const category = searchParams.get("category");
    const search = searchParams.get("search");
    const lat = searchParams.get("lat");
    const lng = searchParams.get("lng");
    const radius = parseFloat(searchParams.get("radius") || "10"); // 10km par défaut

    let query = adminDb.collection("shops");

    // Filtrer par catégorie
    if (category) {
      query = query.where("category", "==", category) as any;
    }

    const snapshot = await query.get();

    let shops = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    // Filtrer par recherche texte
    if (search) {
      const searchLower = search.toLowerCase();
      shops = shops.filter(
        (shop: any) =>
          shop.name?.toLowerCase().includes(searchLower) ||
          shop.description?.toLowerCase().includes(searchLower)
      );
    }

    // Filtrer par distance géographique
    if (lat && lng) {
      const userLat = parseFloat(lat);
      const userLng = parseFloat(lng);

      shops = shops
        .map((shop: any) => {
          const distance = calculateDistance(
            userLat,
            userLng,
            shop.location?.latitude || 0,
            shop.location?.longitude || 0
          );
          return { ...shop, distance };
        })
        .filter((shop: any) => shop.distance <= radius)
        .sort((a: any, b: any) => a.distance - b.distance);
    }

    return NextResponse.json({
      success: true,
      shops,
    });
  } catch (error) {
    return handleApiError(error);
  }
});
