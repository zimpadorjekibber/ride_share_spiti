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

// ── Lost & Found → notify everyone ──────────────────────────────────────
exports.onLostFound = onDocumentCreated("lost_found/{id}", async (event) => {
  const r = event.data.data();
  if (!r) return;
  const lost = (r.type || "lost") === "lost";
  await send(
    "all_users",
    lost ? `🔍 LOST: ${r.title || "an item"}` : `🎒 FOUND: ${r.title || "an item"}`,
    `${lost ? "Kho gaya" : "Mila hai"} — ${r.location || "Spiti"}${r.date ? ` (${r.date})` : ""}. ` +
      `${lost ? "Dikhe to" : "Aapka hai to"} call karein: ${r.phone || "Spiti Setu app kholen"}`
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

// ── Scheduled cleanup ───────────────────────────────────────────────────
//
// Two things used to pile up in Firestore forever:
//
//   1. Broadcast requests (ride / room / food). The app hid them after 24h
//      client-side, but the documents stayed — the collection grew without
//      bound and every client kept re-downloading the whole thing.
//   2. Rides whose departure date has passed. Every client used to delete
//      these itself on every snapshot, so N phones raced to delete the same
//      M documents (N×M writes, plus a permission error for each loser).
//
// Both are now handled here, once a day, by one trusted caller.

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

/** Requests older than this go. Matches LocalStorageService.requestValidity. */
const REQUEST_TTL_HOURS = 24;

/** 'YYYY-MM-DD' for today in IST — rides are dated in the driver's local time. */
const todayIST = () =>
  new Date(Date.now() + 5.5 * 3600 * 1000).toISOString().slice(0, 10);

/** Deletes in batches of 400 (Firestore's hard limit is 500 writes/batch). */
const deleteAll = async (db, docs) => {
  for (let i = 0; i < docs.length; i += 400) {
    const batch = db.batch();
    docs.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  return docs.length;
};

/**
 * createdAt is a Timestamp on every new write, but documents written before
 * the app switched to server timestamps hold an ISO string. Anything we
 * cannot date is treated as expired — it can only predate that switch.
 */
const createdAtMillis = (v) => {
  if (!v) return 0;
  if (v instanceof Timestamp) return v.toMillis();
  if (typeof v === "number") return v;
  if (typeof v === "string") {
    const t = Date.parse(v);
    return Number.isNaN(t) ? 0 : t;
  }
  return 0;
};

exports.cleanupExpired = onSchedule(
  { schedule: "every day 03:30", timeZone: "Asia/Kolkata" },
  async () => {
    const db = getFirestore();
    const cutoff = Date.now() - REQUEST_TTL_HOURS * 3600 * 1000;
    const summary = {};

    // 1. Stale broadcast requests.
    for (const coll of ["passenger_requests", "stay_requests", "food_requests"]) {
      const snap = await db.collection(coll).get();
      const stale = snap.docs.filter(
        (d) => createdAtMillis(d.data().createdAt) < cutoff
      );
      summary[coll] = await deleteAll(db, stale);
    }

    // 2. Rides whose departure day is over. `date` is a 'YYYY-MM-DD' string,
    //    so a string comparison is also a date comparison. Rides with a
    //    missing or malformed date are left alone — same rule as the app's
    //    Ride.isExpired, which never expires an unparseable date.
    const rides = await db.collection("rides").where("date", "<", todayIST()).get();
    summary.rides = await deleteAll(
      db,
      rides.docs.filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d.data().date || ""))
    );

    console.log("cleanupExpired removed:", summary);
  }
);
