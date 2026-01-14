import * as admin from "firebase-admin";

admin.initializeApp();

// Export all function modules
export { onOrderStatusChange } from "./triggers/order-status-change";
export { onDriverLocationUpdate } from "./triggers/driver-location-update";
export { onOrderCreated } from "./triggers/order-created";
export { updateDriverLocation } from "./endpoints/update-driver-location";
export { updateDriverStatus } from "./endpoints/update-driver-status";
