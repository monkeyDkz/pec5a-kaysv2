import { NextRequest, NextResponse } from "next/server";
import { adminAuth, adminDb } from "./firebase-admin";

export interface AuthenticatedRequest extends NextRequest {
  userId?: string;
  userRole?: "admin" | "user" | "merchant" | "driver";
}

/**
 * Middleware pour vérifier le token Firebase dans le header Authorization
 */
export async function verifyAuth(request: NextRequest): Promise<{ 
  userId: string; 
  userRole: "admin" | "user" | "merchant" | "driver";
} | null> {
  try {
    const authHeader = request.headers.get("Authorization");

    console.log("[Auth] Header present:", !!authHeader, authHeader ? `Bearer ${authHeader.substring(7, 20)}...` : "none");

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      console.log("[Auth] No valid Authorization header");
      return null;
    }

    const token = authHeader.split("Bearer ")[1];
    console.log("[Auth] Verifying token...");
    const decodedToken = await adminAuth.verifyIdToken(token);
    console.log("[Auth] Token verified for uid:", decodedToken.uid);
    
    // Récupérer le rôle de l'utilisateur depuis Firestore
    const userDoc = await adminDb.collection("users").doc(decodedToken.uid).get();
    
    if (!userDoc.exists) {
      return null;
    }

    const userData = userDoc.data();
    
    return {
      userId: decodedToken.uid,
      userRole: userData?.role || "user",
    };
  } catch (error: any) {
    console.error("[Auth] Verification failed:", error.code || error.message);
    return null;
  }
}

/**
 * Wrapper pour protéger une route avec authentification
 */
export function withAuth(
  handler: (request: NextRequest, auth: { userId: string; userRole: string }) => Promise<NextResponse>,
  options?: { requiredRole?: "admin" | "merchant" | "driver" }
) {
  return async (request: NextRequest) => {
    const auth = await verifyAuth(request);

    if (!auth) {
      return NextResponse.json(
        { error: "Unauthorized", message: "Token d'authentification invalide ou manquant" },
        { status: 401 }
      );
    }

    // Vérifier le rôle si requis
    if (options?.requiredRole && auth.userRole !== "admin" && auth.userRole !== options.requiredRole) {
      return NextResponse.json(
        { error: "Forbidden", message: `Accès réservé aux ${options.requiredRole}s` },
        { status: 403 }
      );
    }

    try {
      return await handler(request, auth);
    } catch (error: any) {
      console.error("API error:", error);
      return NextResponse.json(
        { error: "Internal Server Error", message: error.message },
        { status: 500 }
      );
    }
  };
}

/**
 * Helper pour gérer les erreurs communes
 */
export function handleApiError(error: any): NextResponse {
  console.error("API Error:", error);

  if (error.code === "permission-denied") {
    return NextResponse.json(
      { error: "Forbidden", message: "Vous n'avez pas la permission d'effectuer cette action" },
      { status: 403 }
    );
  }

  if (error.code === "not-found") {
    return NextResponse.json(
      { error: "Not Found", message: "Ressource introuvable" },
      { status: 404 }
    );
  }

  return NextResponse.json(
    { error: "Internal Server Error", message: error.message || "Une erreur est survenue" },
    { status: 500 }
  );
}
