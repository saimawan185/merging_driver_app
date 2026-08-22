/**
 * Builds a data-only FCM message for driver incoming ride/order requests.
 * Data-only + high priority lets the Flutter background handler show the
 * half-screen full-screen-intent UI when the app is closed.
 *
 * Canonical helper lives in Order Tracking Firebase Function:
 * functions/products/driver_incoming_order_fcm.js
 */
function str(value) {
  if (value === null || value === undefined) return "";
  return String(value);
}

function buildDriverIncomingOrderMessage({
  token,
  title,
  body,
  orderId,
  type,
  amount = "",
  pickup = "",
  destination = "",
  paymentMethod = "",
  distance = "",
  duration = "",
  vehicleLabel = "",
}) {
  if (!token) {
    throw new Error("buildDriverIncomingOrderMessage: missing fcm token");
  }

  return {
    token,
    data: {
      title: str(title || "New Order Request"),
      body: str(body || ""),
      orderId: str(orderId || ""),
      type: str(type || "order_request"),
      amount: str(amount),
      pickup: str(pickup),
      destination: str(destination),
      paymentMethod: str(paymentMethod),
      distance: str(distance),
      duration: str(duration),
      vehicleLabel: str(vehicleLabel),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: { priority: "high" },
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "alert",
      },
      payload: {
        aps: {
          alert: {
            title: str(title || "New Order Request"),
            body: str(body || ""),
          },
          sound: "notification_sound.wav",
          badge: 1,
          "content-available": 1,
        },
      },
    },
  };
}

module.exports = { buildDriverIncomingOrderMessage };
