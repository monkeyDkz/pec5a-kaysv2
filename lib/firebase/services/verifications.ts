import {
  collection,
  doc,
  getDocs,
  getDoc,
  addDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  onSnapshot,
  serverTimestamp,
  Timestamp,
  arrayUnion,
  type Unsubscribe,
} from "firebase/firestore"
import { db } from "../config"
import { COLLECTIONS } from "../collections"
import type {
  Verification,
  VerificationAttachment,
  VerificationHistoryEntry,
  VerificationHistoryAction,
} from "@/lib/types"

const getCrypto = () => {
  try {
    return (globalThis as { crypto?: Crypto }).crypto
  } catch {
    return undefined
  }
}

const generateHistoryId = () => {
  const cryptoRef = getCrypto()
  if (cryptoRef?.randomUUID) {
    return cryptoRef.randomUUID()
  }
  return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
}

const convertTimestampValue = (value: any): string | undefined => {
  if (!value) return undefined
  if (value instanceof Timestamp) {
    return value.toDate().toISOString()
  }
  if (typeof value === "string") {
    const parsed = new Date(value)
    return Number.isNaN(parsed.getTime()) ? value : parsed.toISOString()
  }
  if (typeof value === "object" && "toDate" in value && typeof value.toDate === "function") {
    return value.toDate().toISOString()
  }
  if (typeof value === "object" && "seconds" in value && "nanoseconds" in value) {
    return new Timestamp(value.seconds as number, value.nanoseconds as number).toDate().toISOString()
  }
  return undefined
}

const normalizeAttachments = (
  docId: string,
  rawAttachments: any[] | undefined,
  fallbackUrl: string,
  verificationType: Verification["type"]
): VerificationAttachment[] => {
  if (Array.isArray(rawAttachments) && rawAttachments.length > 0) {
    return rawAttachments.map((attachment, index) => ({
      id: attachment?.id || `${docId}-attachment-${index}`,
      label: attachment?.label || attachment?.name || `Document ${index + 1}`,
      url: attachment?.url || fallbackUrl,
      mimeType: attachment?.mimeType || attachment?.type,
      size: attachment?.size,
    }))
  }

  if (fallbackUrl) {
    return [
      {
        id: `${docId}-primary`,
        label: verificationType === "license" ? "Driver License" : "Document",
        url: fallbackUrl,
        mimeType: "image/jpeg",
      },
    ]
  }

  return []
}

const normalizeHistoryEntries = (
  docId: string,
  rawHistory: any[] | undefined
): VerificationHistoryEntry[] => {
  if (!Array.isArray(rawHistory) || rawHistory.length === 0) {
    return []
  }

  return rawHistory
    .map((entry, index) => {
      const timestamp =
        convertTimestampValue(entry?.timestamp || entry?.createdAt || entry?.performedAt) ||
        new Date().toISOString()

      return {
        id: entry?.id || `${docId}-history-${index}`,
        action: (entry?.action as VerificationHistoryAction) || "note",
        actor: entry?.actor || entry?.reviewerEmail || "system",
        message: entry?.message ?? entry?.reason ?? null,
        timestamp,
      }
    })
    .sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime())
}

const sanitizeAttachmentsForWrite = (attachments?: VerificationAttachment[]) => {
  if (!Array.isArray(attachments)) return []
  return attachments
    .filter((attachment) => Boolean(attachment?.url))
    .map((attachment, index) => ({
      id: attachment.id || `${generateHistoryId()}-${index}`,
      label: attachment.label || `Document ${index + 1}`,
      url: attachment.url,
      mimeType: attachment.mimeType || null,
      size: attachment.size || null,
    }))
}

const buildHistoryEntry = (
  action: VerificationHistoryAction,
  actor: string,
  message?: string | null
) => ({
  id: generateHistoryId(),
  action,
  actor,
  message: message ?? null,
  timestamp: serverTimestamp(),
})

// Convert Firestore document to Verification type
const convertVerification = (docSnapshot: any): Verification => {
  const data = docSnapshot.data()
  const fallbackDocumentUrl = data.documentUrl || ""
  const attachments = normalizeAttachments(docSnapshot.id, data.attachments, fallbackDocumentUrl, data.type)
  const history = normalizeHistoryEntries(docSnapshot.id, data.history)
  const primaryDocumentUrl = fallbackDocumentUrl || attachments[0]?.url || ""

  return {
    id: docSnapshot.id,
    userId: data.userId,
    type: data.type,
    status: data.status,
    documentUrl: primaryDocumentUrl,
    submittedAt: convertTimestampValue(data.submittedAt) || new Date().toISOString(),
    reviewedAt: convertTimestampValue(data.reviewedAt),
    reviewedBy: data.reviewedBy,
    attachments,
    history,
    rejectionReason: data.rejectionReason || null,
  }
}

// Get all verifications
export const getVerifications = async (): Promise<Verification[]> => {
  const verificationsRef = collection(db, COLLECTIONS.VERIFICATIONS)
  const q = query(verificationsRef, orderBy("submittedAt", "desc"))
  const snapshot = await getDocs(q)
  return snapshot.docs.map(convertVerification)
}

// Get verification by ID
export const getVerificationById = async (id: string): Promise<Verification | null> => {
  const docRef = doc(db, COLLECTIONS.VERIFICATIONS, id)
  const docSnap = await getDoc(docRef)
  if (docSnap.exists()) {
    return convertVerification(docSnap)
  }
  return null
}

// Get verifications by user ID
export const getVerificationsByUserId = async (userId: string): Promise<Verification[]> => {
  const verificationsRef = collection(db, COLLECTIONS.VERIFICATIONS)
  const q = query(verificationsRef, where("userId", "==", userId))
  const snapshot = await getDocs(q)
  return snapshot.docs.map(convertVerification)
}

// Get verifications by status
export const getVerificationsByStatus = async (
  status: Verification["status"]
): Promise<Verification[]> => {
  const verificationsRef = collection(db, COLLECTIONS.VERIFICATIONS)
  const q = query(verificationsRef, where("status", "==", status))
  const snapshot = await getDocs(q)
  return snapshot.docs.map(convertVerification)
}

// Get verifications by type
export const getVerificationsByType = async (
  type: Verification["type"]
): Promise<Verification[]> => {
  const verificationsRef = collection(db, COLLECTIONS.VERIFICATIONS)
  const q = query(verificationsRef, where("type", "==", type))
  const snapshot = await getDocs(q)
  return snapshot.docs.map(convertVerification)
}

// Create verification
export const createVerification = async (
  verificationData: Omit<Verification, "id" | "submittedAt">
): Promise<string> => {
  const verificationsRef = collection(db, COLLECTIONS.VERIFICATIONS)
  const { attachments, ...rest } = verificationData
  const sanitizedAttachments = sanitizeAttachmentsForWrite(attachments)
  const docRef = await addDoc(verificationsRef, {
    ...rest,
    attachments: sanitizedAttachments,
    history: [buildHistoryEntry("submitted", verificationData.userId, null)],
    submittedAt: serverTimestamp(),
    rejectionReason: null,
  })
  return docRef.id
}

// Update verification
export const updateVerification = async (
  id: string,
  verificationData: Partial<Verification>
): Promise<void> => {
  const docRef = doc(db, COLLECTIONS.VERIFICATIONS, id)
  await updateDoc(docRef, verificationData)
}

// Approve verification
export const approveVerification = async (
  id: string,
  reviewerEmail: string
): Promise<void> => {
  const docRef = doc(db, COLLECTIONS.VERIFICATIONS, id)
  await updateDoc(docRef, {
    status: "approved",
    reviewedAt: serverTimestamp(),
    reviewedBy: reviewerEmail,
    rejectionReason: null,
    history: arrayUnion(buildHistoryEntry("approved", reviewerEmail, "Verification approved")),
  })
}

// Reject verification
export const rejectVerification = async (
  id: string,
  reviewerEmail: string,
  reason?: string
): Promise<void> => {
  const docRef = doc(db, COLLECTIONS.VERIFICATIONS, id)
  await updateDoc(docRef, {
    status: "rejected",
    reviewedAt: serverTimestamp(),
    reviewedBy: reviewerEmail,
    rejectionReason: reason,
    history: arrayUnion(buildHistoryEntry("rejected", reviewerEmail, reason || "Verification rejected")),
  })
}

// Delete verification
export const deleteVerification = async (id: string): Promise<void> => {
  const docRef = doc(db, COLLECTIONS.VERIFICATIONS, id)
  await deleteDoc(docRef)
}

// Subscribe to verifications (real-time updates)
export const subscribeToVerifications = (
  callback: (verifications: Verification[]) => void,
  onError?: (error: Error) => void
): Unsubscribe => {
  const verificationsRef = collection(db, COLLECTIONS.VERIFICATIONS)
  const q = query(verificationsRef, orderBy("submittedAt", "desc"))
  
  return onSnapshot(
    q,
    (snapshot) => {
      const verifications = snapshot.docs.map(convertVerification)
      callback(verifications)
    },
    (error) => {
      console.error("Error subscribing to verifications:", error)
      onError?.(error)
    }
  )
}

// Subscribe to pending verifications
export const subscribeToPendingVerifications = (
  callback: (verifications: Verification[]) => void
): Unsubscribe => {
  const verificationsRef = collection(db, COLLECTIONS.VERIFICATIONS)
  const q = query(
    verificationsRef,
    where("status", "==", "pending"),
    orderBy("submittedAt", "desc")
  )
  
  return onSnapshot(q, (snapshot) => {
    const verifications = snapshot.docs.map(convertVerification)
    callback(verifications)
  })
}

// Get verification statistics
export const getVerificationStats = async () => {
  const verifications = await getVerifications()
  
  return {
    total: verifications.length,
    pending: verifications.filter((v) => v.status === "pending").length,
    approved: verifications.filter((v) => v.status === "approved").length,
    rejected: verifications.filter((v) => v.status === "rejected").length,
  }
}
