package com.doordelights.rider

import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions

/**
 * Rejects an incoming order/ride in Firestore without opening the Flutter UI.
 */
object IncomingOrderRejectHelper {
    private const val TAG = "IncomingOrderReject"
    private const val STATUS_REJECTED = "Driver Rejected"

    fun rejectAsync(orderId: String, type: String, onDone: (Boolean) -> Unit) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
        if (uid.isNullOrBlank() || orderId.isBlank()) {
            Log.w(TAG, "rejectAsync missing uid/orderId")
            onDone(false)
            return
        }

        val db = FirebaseFirestore.getInstance()
        val normalized = type.lowercase()
        val collection = when {
            normalized.contains("cab") || normalized.contains("ride") -> "rides"
            normalized.contains("parcel") -> "parcel_orders"
            normalized.contains("rental") -> "rental_orders"
            else -> "vendor_orders"
        }

        val orderRef = db.collection(collection).document(orderId)
        val userRef = db.collection("users").document(uid)

        orderRef.get()
            .addOnSuccessListener { snap ->
                if (!snap.exists()) {
                    Log.w(TAG, "Order not found: $collection/$orderId")
                    clearDriverRequest(userRef, normalized) { onDone(false) }
                    return@addOnSuccessListener
                }

                val updates = hashMapOf<String, Any>(
                    "status" to STATUS_REJECTED,
                    "rejectedByDrivers" to FieldValue.arrayUnion(uid),
                )

                orderRef.set(updates, SetOptions.merge())
                    .addOnSuccessListener {
                        clearDriverRequest(userRef, normalized) { ok ->
                            Log.d(TAG, "Rejected $collection/$orderId ok=$ok")
                            onDone(true)
                        }
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "Failed to reject order", e)
                        onDone(false)
                    }
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to load order", e)
                onDone(false)
            }
    }

    private fun clearDriverRequest(
        userRef: com.google.firebase.firestore.DocumentReference,
        normalized: String,
        onDone: (Boolean) -> Unit,
    ) {
        val clear = hashMapOf<String, Any>()
        when {
            normalized.contains("cab") || normalized.contains("ride") -> {
                clear["ordercabRequestData"] = FieldValue.delete()
            }
            normalized.contains("parcel") -> {
                clear["orderParcelRequestData"] = FieldValue.delete()
            }
            else -> {
                clear["orderRequestData"] = FieldValue.delete()
            }
        }

        userRef.update(clear)
            .addOnSuccessListener { onDone(true) }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to clear driver request", e)
                onDone(false)
            }
    }
}
