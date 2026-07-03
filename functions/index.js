// Spiti Setu — push-notification triggers.
//
// Topic scheme (the app subscribes in lib/services/push_service.dart):
//   all_users        — every install (reserved for admin announcements)
//   user_<10digits>  — personal: booking/cancellation alerts for the phone
//                      that owns a ride
//   providers_ride   — drivers: a passenger broadcast a ride request
//   providers_stay   — hosts: a tourist broadcast a room request
//   providers_food   — cooks: someone broadcast a food request

const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
// Mumbai region — closest to Spiti; keep costs predictable.
setGlobalOptions({ region: "asia-south1", maxInstances: 5 });

/** Last 10 digits of a phone number (matches phone_utils.dart). */
const norm = (p) => {
  const d = String(p || "").replace(/\D/g, "");
  return d.length >= 10 ? d.slice(-10) : d;
};

const send = (topic, title, body) =>
  getMessaging()
    .send({ topic, notification: { title, body } })
    .catch((e) => console.error(`send to ${topic} failed:`, e.message));

// ── Seat booked / freed → notify the driver ─────────────────────────────
exports.onRideChange = onDocumentWritten("rides/{id}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!before || !after) return; // creation or deletion — nothing to diff

  const prev = new Set(before.bookedSeats || []);
  const cur = new Set(after.bookedSeats || []);
  const added = [...cur].filter((s) => !prev.has(s));
  const removed = [...prev].filter((s) => !cur.has(s));
  if (!added.length && !removed.length) return;

  const phone = norm(after.phone);
  if (!phone) return;
  const topic = `user_${phone}`;
  const route = `${after.from} → ${after.to} (${after.date})`;
  const bookings = after.seatBookings || [];

  const jobs = [];
  for (const s of added) {
    const b = bookings.find((x) => x && x.seatId === s) || {};
    if (b.byDriver) continue; // driver blocked it himself — no self-alert
    const who = b.name
      ? `${b.name}${b.phone ? ` (${b.phone})` : ""}`
      : "A passenger";
    jobs.push(send(topic, `🎫 Seat ${s} booked!`, `${who} booked seat ${s} on ${route}`));
  }
  if (removed.length) {
    jobs.push(
      send(
        topic,
        `Seat${removed.length > 1 ? "s" : ""} ${removed.join(", ")} freed`,
        `Booking cancelled / freed on ${route}. Seat is open again.`
      )
    );
  }
  await Promise.all(jobs);
});

// ── New seeker broadcasts → notify providers ────────────────────────────
exports.onPassengerRequest = onDocumentCreated("passenger_requests/{id}", async (event) => {
  const r = event.data.data();
  if (!r) return;
  await send(
    "providers_ride",
    "🚗 Passenger looking for a ride!",
    `${r.passengerName || "Someone"} needs ${r.seatsNeeded || 1} seat(s): ${r.from} → ${r.to} on ${r.date}. Open Spiti Setu to call them.`
  );
});

exports.onStayRequest = onDocumentCreated("stay_requests/{id}", async (event) => {
  const r = event.data.data();
  if (!r) return;
  await send(
    "providers_stay",
    "🏠 Tourist looking for a room!",
    `${r.seekerName || "Someone"} wants a stay in ${r.locationLooking || "Spiti"} for ${r.guestsCount || 1} guest(s), budget ₹${Math.round(r.budgetPerNight || 0)}/night.`
  );
});

exports.onFoodRequest = onDocumentCreated("food_requests/{id}", async (event) => {
  const r = event.data.data();
  if (!r) return;
  await send(
    "providers_food",
    "🍲 Someone is looking for food!",
    `${r.seekerName || "Someone"} wants ${r.cuisineWanted || "a meal"} in ${r.locationLooking || "Spiti"} for ${r.peopleCount || 1} — ${r.whenNeeded || "soon"}.`
  );
});
