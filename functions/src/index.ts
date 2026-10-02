import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as crypto from "crypto";

initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 10 });

const db = getFirestore();

const OTP_PEPPER = defineSecret("OTP_PEPPER");
const WHATSAPP_TOKEN = defineSecret("WHATSAPP_TOKEN");
const WHATSAPP_PHONE_ID = defineSecret("WHATSAPP_PHONE_ID");

const OTP_TTL_MS = 10 * 60 * 1000;
const OTP_MAX_ATTEMPTS = 5;
const OTP_MAX_PER_WINDOW = 3;
const OTP_WINDOW_MS = 5 * 60 * 1000;
const OTP_MAX_PER_DAY = 10;

const VERIFICATION_STATUSES = ["pending", "approved", "verified", "rejected", "expired"];
const GRAVE_REASONS = [
  "amenaza",
  "manejo_peligroso",
  "arma",
  "acoso",
];

/** Reportes graves apagan la insignia, no banean la cuenta. */
const BADGE_OFF_REASONS = GRAVE_REASONS;

function normalizePhone(raw: unknown): string {
  if (typeof raw !== "string") {
    throw new HttpsError("invalid-argument", "Celular invalido.");
  }
  let digits = raw.replace(/\D/g, "");
  if (digits.length === 8) {
    digits = `507${digits}`;
  }
  if (digits.length === 10 && digits.startsWith("507")) {
    digits = digits.slice(3);
  }
  if (!/^\d{8,15}$/.test(digits)) {
    throw new HttpsError("invalid-argument", "Celular invalido.");
  }
  return `+${digits}`;
}

function hashOtp(phone: string, code: string): string {
  return crypto
    .createHash("sha256")
    .update(`${OTP_PEPPER.value()}|${phone}|${code}`)
    .digest("hex");
}

function hashPhone(phone: string): string {
  return crypto.createHash("sha256").update(phone).digest("hex");
}

function safeEqual(a: string, b: string): boolean {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

async function sendWhatsappText(to: string, text: string): Promise<void> {
  if (!WHATSAPP_TOKEN.value() || !WHATSAPP_PHONE_ID.value()) {
    logger.warn("WHATSAPP_TOKEN/WHATSAPP_PHONE_ID sin configurar: mensaje NO enviado", { to });
    return;
  }
  const url = `https://graph.facebook.com/v21.0/${WHATSAPP_PHONE_ID.value()}/messages`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${WHATSAPP_TOKEN.value()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: to.replace(/\D/g, ""),
      type: "text",
      text: { body: text },
    }),
  });
  if (!res.ok) {
    logger.error("WhatsApp Business API fallo", { status: res.status, body: await res.text() });
    throw new HttpsError("unavailable", "No pudimos enviar el mensaje de WhatsApp.");
  }
}

async function assertStaff(uid: string): Promise<void> {
  const token = await getAuth().getUser(uid).catch(() => null);
  if (token?.customClaims?.staff === true) return;
  const staffDoc = await db.doc(`staff/${uid}`).get();
  if (staffDoc.exists && staffDoc.get("active") === true) return;
  throw new HttpsError("permission-denied", "Solo personal autorizado revisa verificaciones.");
}

/**
 * El chofer pide que le revisen los documentos. El movil NO escribe el status
 * (las reglas tampoco lo dejan): llama a esta Function y es el servidor quien
 * pone "pending" con las fotos que el mismo subio a Storage.
 */
export const requestDriverReview = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Entra a tu cuenta primero.");
  }

  const userSnap = await db.doc(`users/${uid}`).get();
  if (!userSnap.exists) {
    throw new HttpsError("failed-precondition", "Tu perfil todavia no esta guardado.");
  }
  if (userSnap.get("role") !== "driver") {
    throw new HttpsError("failed-precondition", "Solo los choferes piden verificacion de chofer.");
  }

  const vehicle = await db
    .collection("vehicles")
    .where("driverId", "==", uid)
    .limit(1)
    .get();
  if (vehicle.empty) {
    throw new HttpsError("failed-precondition", "Registra tu carro antes de pedir la verificacion.");
  }

  const documentos = Array.isArray(request.data?.documentos)
    ? (request.data.documentos as unknown[]).filter((d): d is string => typeof d === "string").slice(0, 8)
    : [];
  const nota = String(request.data?.nota ?? "").slice(0, 500);
  if (documentos.length === 0) {
    throw new HttpsError("invalid-argument", "Sube al menos una foto de tu licencia.");
  }
  for (const url of documentos) {
    if (!url.startsWith("https://firebasestorage.googleapis.com/") && !url.startsWith("https://storage.googleapis.com/")) {
      throw new HttpsError("invalid-argument", "Esa foto no viene de nuestro almacen.");
    }
    if (!url.includes(`/users/${uid}/verification/`)) {
      throw new HttpsError("permission-denied", "Esa foto no es tuya.");
    }
  }

  const ref = db.doc(`users/${uid}/verification/driver`);
  const actual = await ref.get();
  const status = String(actual.get("status") ?? "");
  // Si ya esta verificado no se degrada la insignia por accident.
  const nextBadge = status === "approved" || status === "verified" ? actual.get("badgeActive") : false;

  await ref.set(
    {
      status: "pending",
      documentos,
      nota,
      requestedAt: FieldValue.serverTimestamp(),
      requestedBy: uid,
      badgeActive: nextBadge,
      pendingHumanReview: true,
    },
    { merge: true },
  );

  return { ok: true, status: "pending" };
});

/** En Panama no hay API publica de licencias ni de cedulas: el cliente nunca escribe status. */
export const sendOtp = onCall(
  { secrets: [OTP_PEPPER, WHATSAPP_TOKEN, WHATSAPP_PHONE_ID] },
  async (request) => {
    const phone = normalizePhone(request.data?.phone);
    const phoneHash = hashPhone(phone);
    const now = Date.now();
    const limitRef = db.doc(`otpLimits/${phoneHash}`);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(limitRef);
      const data = snap.exists ? snap.data()! : { windowStart: 0, windowCount: 0, dayStart: 0, dayCount: 0 };
      const inWindow = now - (data.windowStart ?? 0) < OTP_WINDOW_MS;
      const windowCount = inWindow ? (data.windowCount ?? 0) : 1;
      const inDay = now - (data.dayStart ?? 0) < 24 * 60 * 60 * 1000;
      const dayCount = inDay ? (data.dayCount ?? 0) + 1 : 1;

      if (windowCount > OTP_MAX_PER_WINDOW) {
        throw new HttpsError("resource-exhausted", "Demasiados intentos. Espera 5 minutos.");
      }
      if (dayCount > OTP_MAX_PER_DAY) {
        throw new HttpsError("resource-exhausted", "Demasiados codigos hoy. Intenta manana.");
      }

      tx.set(
        limitRef,
        {
          phone,
          windowStart: inWindow ? data.windowStart : now,
          windowCount,
          dayStart: inDay ? data.dayStart : now,
          dayCount,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    const code = String(crypto.randomInt(0, 1000000)).padStart(6, "0");
    const otpRef = db.doc(`otps/${phoneHash}`);

    await otpRef.set(
      {
        phone,
        codeHash: hashOtp(phone, code),
        attempts: 0,
        maxAttempts: OTP_MAX_ATTEMPTS,
        consumed: false,
        createdAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(now + OTP_TTL_MS),
      },
      { merge: true },
    );

    await sendWhatsappText(
      phone,
      `GunaYala Ride: tu codigo es ${code}. Vale 10 minutos. No lo compartas.`,
    );

    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    return {
      sent: true,
      expiresInSeconds: OTP_TTL_MS / 1000,
      ...(isEmulator ? { devCode: code } : {}),
    };
  },
);

export const verifyOtp = onCall({ secrets: [OTP_PEPPER] }, async (request) => {
  const phone = normalizePhone(request.data?.phone);
  const code = typeof request.data?.code === "string" ? request.data.code.trim() : "";
  if (!/^\d{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "El codigo son 6 digitos.");
  }

  const otpRef = db.doc(`otps/${hashPhone(phone)}`);
  const uid = await db.runTransaction(async (tx) => {
    const snap = await tx.get(otpRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Pide un codigo nuevo.");
    }
    const data = snap.data()!;
    const now = Date.now();

    if (data.consumed === true) {
      throw new HttpsError("permission-denied", "Ese codigo ya se uso. Pide otro.");
    }
    const expiresAt = (data.expiresAt as Timestamp)?.toMillis?.() ?? 0;
    if (now > expiresAt) {
      throw new HttpsError("deadline-exceeded", "El codigo vencio. Pide uno nuevo.");
    }
    const attempts = (data.attempts ?? 0) + 1;
    if (attempts > (data.maxAttempts ?? OTP_MAX_ATTEMPTS)) {
      tx.set(otpRef, { attempts, blockedAt: FieldValue.serverTimestamp() }, { merge: true });
      throw new HttpsError("resource-exhausted", "Codigo bloqueado. Pide uno nuevo.");
    }
    if (!safeEqual(hashOtp(phone, code), String(data.codeHash))) {
      tx.set(otpRef, { attempts, lastFailedAt: FieldValue.serverTimestamp() }, { merge: true });
      throw new HttpsError("permission-denied", "Codigo incorrecto.");
    }

    tx.set(
      otpRef,
      { consumed: true, consumedAt: FieldValue.serverTimestamp(), attempts },
      { merge: true },
    );
    return hashPhone(phone);
  });

  const customUid = `u_${uid}`;
  try {
    await getAuth().getUser(customUid);
  } catch {
    await getAuth().createUser({ uid: customUid, phoneNumber: phone });
  }

  const token = await getAuth().createCustomToken(customUid, { phone });
  return { token, uid: customUid };
});

export const reviewDriverVerification = onCall(
  { secrets: [WHATSAPP_TOKEN, WHATSAPP_PHONE_ID] },
  async (request) => {
    const reviewer = request.auth?.uid;
    if (!reviewer) {
      throw new HttpsError("unauthenticated", "Inicia sesion.");
    }
    await assertStaff(reviewer);

    const targetUid = String(request.data?.uid ?? "");
    const status = String(request.data?.status ?? "");
    const note = String(request.data?.note ?? "").slice(0, 500);
    if (!targetUid) throw new HttpsError("invalid-argument", "Falta el chofer a revisar.");
    if (!VERIFICATION_STATUSES.includes(status)) {
      throw new HttpsError("invalid-argument", "Estado de verificacion invalido.");
    }
    if (status === "rejected" && note.trim().length < 5) {
      throw new HttpsError("invalid-argument", "Explica por que se rechaza (minimo 5 caracteres).");
    }

    const userSnap = await db.doc(`users/${targetUid}`).get();
    const phone = userSnap.exists ? String(userSnap.get("telefono") ?? "") : "";

    await db.doc(`users/${targetUid}/verification/driver`).set(
      {
        status,
        note,
        reviewedBy: reviewer,
        reviewedAt: FieldValue.serverTimestamp(),
        badgeActive: status === "approved" || status === "verified",
      },
      { merge: true },
    );

    if (phone) {
      const msg =
        status === "approved" || status === "verified"
          ? "GunaYala Ride: tu verificacion de chofer fue aprobada. Ya puedes publicar viajes."
          : status === "rejected"
            ? `GunaYala Ride: tu verificacion de chofer fue rechazada. Motivo: ${note}`
            : "GunaYala Ride: tu verificacion de chofer quedo en revision.";
      await sendWhatsappText(phone, msg);
    }

    return { ok: true, status };
  },
);

async function vehicleSeats(vehicleId: string): Promise<number> {
  const snap = await db.doc(`vehicles/${vehicleId}`).get();
  if (!snap.exists) {
    throw new HttpsError("failed-precondition", "El carro de este viaje ya no existe.");
  }
  const seats = Number(snap.get("seats"));
  if (!Number.isFinite(seats) || seats <= 0) {
    throw new HttpsError("failed-precondition", "El carro no tiene asientos validos.");
  }
  return seats;
}

type RequestLike = { riderId?: string; seats?: number; status?: string };

export const onSeatAccepted = onDocumentUpdated(
  "rides/{rideId}/requests/{requestId}",
  async (event) => {
    const before = event.data?.before.data() as RequestLike | undefined;
    const after = event.data?.after.data() as RequestLike | undefined;
    if (!before || !after) return;
    if (after.status !== "accepted" || before.status === "accepted") return;

    const rideId = event.params.rideId as string;
    const rideRef = db.doc(`rides/${rideId}`);

    await db.runTransaction(async (tx) => {
      const rideSnap = await tx.get(rideRef);
      if (!rideSnap.exists) return;
      const ride = rideSnap.data()!;
      if (ride.status === "completed" || ride.status === "cancelled") {
        throw new HttpsError("failed-precondition", "Ese viaje ya no acepta cupos.");
      }

      const seats = Math.max(1, Number(after.seats) || 1);
      const physical = await vehicleSeats(String(ride.vehicleId));
      const offered = Number(ride.seatsTotal) || 0;
      const reserved = Number(ride.seatsReserved) || 0;

      if (offered > physical) {
        throw new HttpsError("failed-precondition", "Los cupos ofrecidos superan los asientos del carro.");
      }
      // El tope son los cupos OFRECIDOS (seatsTotal), no los asientos del
      // carro: si el chofer ofrece 4 de 14, cuatro es lo que se puede vender.
      if (reserved + seats > offered) {
        throw new HttpsError("resource-exhausted", "No quedan cupos en este viaje.");
      }

      const riderIds: string[] = Array.isArray(ride.riderIds) ? ride.riderIds : [];
      if (!riderIds.includes(String(after.riderId))) {
        riderIds.push(String(after.riderId));
      }

      tx.update(rideRef, {
        seatsReserved: reserved + seats,
        riderIds,
        seatsUpdatedAt: FieldValue.serverTimestamp(),
      });
    });
  },
);

export const onSeatReleased = onDocumentUpdated(
  "rides/{rideId}/requests/{requestId}",
  async (event) => {
    const before = event.data?.before.data() as RequestLike | undefined;
    const after = event.data?.after.data() as RequestLike | undefined;
    if (!before || !after) return;
    if (before.status !== "accepted") return;
    if (after.status !== "cancelled" && after.status !== "rejected") return;

    const rideRef = db.doc(`rides/${event.params.rideId as string}`);

    await db.runTransaction(async (tx) => {
      const rideSnap = await tx.get(rideRef);
      if (!rideSnap.exists) return;
      const ride = rideSnap.data()!;
      const seats = Math.max(1, Number(after.seats) || 1);
      const reserved = Number(ride.seatsReserved) || 0;
      const riderId = String(after.riderId ?? "");
      const riderIds: string[] = (Array.isArray(ride.riderIds) ? ride.riderIds : []).filter(
        (id) => id !== riderId,
      );

      tx.update(rideRef, {
        seatsReserved: Math.max(0, reserved - seats),
        riderIds,
        seatsUpdatedAt: FieldValue.serverTimestamp(),
      });

      if (riderId) {
        tx.set(
          db.doc(`users/${riderId}`),
          { stats: { ridesTaken: FieldValue.increment(-1) } },
          { merge: true },
        );
      }
    });
  },
);

export const onRideFinished = onDocumentUpdated("rides/{rideId}", async (event) => {
  const before = event.data?.before.data() as Record<string, unknown> | undefined;
  const after = event.data?.after.data() as Record<string, unknown> | undefined;
  if (!before || !after) return;
  if (after.status !== "completed" || before.status === "completed") return;
  if (after.riderConfirmed !== true) return;

  const rideId = event.params.rideId as string;
  const rideRef = db.doc(`rides/${rideId}`);
  const driverId = String(after.driverId);
  const riderIds: string[] = Array.isArray(after.riderIds) ? (after.riderIds as string[]) : [];
  const batch = db.batch();

  for (const riderId of riderIds) {
    batch.set(
      db.doc(`reviews/${rideId}_${riderId}`),
      {
        rideId,
        driverId,
        driverName: after.driverName ?? "",
        riderId,
        rating: null,
        comment: "",
        createdAt: FieldValue.serverTimestamp(),
        completedAt: after.confirmedByRiderAt ?? null,
      },
      { merge: true },
    );
    batch.set(
      db.doc(`users/${riderId}`),
      { stats: { ridesTaken: FieldValue.increment(1) } },
      { merge: true },
    );
  }

  batch.set(
    rideRef,
    { reviewsOpenedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  batch.set(
    db.doc(`users/${driverId}`),
    { stats: { ridesGiven: FieldValue.increment(1) } },
    { merge: true },
  );
  await batch.commit();
});

export const onSafetyReport = onDocumentCreated("reports/{reportId}", async (event) => {
  const report = event.data?.data();
  if (!report) return;
  const reason = String(report.reason ?? "");
  const reportedId = String(report.reportedId ?? "");
  if (!reportedId || !BADGE_OFF_REASONS.includes(reason)) return;

  const ref = db.doc(`users/${reportedId}/verification/driver`);
  const snap = await ref.get();
  if (snap.exists && snap.get("status") === "pending") return;

  await ref.set(
    {
      badgeActive: false,
      badgeSuspended: true,
      badgeSuspendedReason: reason,
      badgeSuspendedAt: FieldValue.serverTimestamp(),
      pendingHumanReview: true,
    },
    { merge: true },
  );

  logger.warn("Insignia de chofer apagada por reporte grave", { reportedId, reason });
});