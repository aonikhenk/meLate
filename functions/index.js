// Cloud Function: cuando se crea un latido, envía la notificación push
// al teléfono receptor. Repite el aviso 3 veces si nadie responde.
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
admin.initializeApp();

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

exports.onBeat = onDocumentCreated(
  { document: "beats/{id}", timeoutSeconds: 120 },
  async (event) => {
    const b = event.data.data();
    const user = await admin.firestore().doc(`users/${b.to}`).get();
    const token = user.get("token");
    if (!token) return;

    const msg = {
      token,
      data: { kind: b.kind, mood: b.mood, from: b.from },
      notification: {
        title:
          b.kind === "auto" ? "💓 Tomó su teléfono"
          : b.kind === "reply" ? (b.mood === "happy" ? "💖 Respondió feliz" : "💔 Respondió triste")
          : (b.mood === "happy" ? "💖 Latido feliz" : "💔 Latido triste"),
        body: b.kind === "beat" ? "Abre MeLate y responde" : "",
      },
      android: { priority: "high", notification: { channelId: "latido" } },
      apns: { payload: { aps: { sound: "default" } } },
    };

    await admin.messaging().send(msg);

    // Respuestas y automáticos no requieren respuesta: se borran.
    if (b.kind !== "beat") {
      await event.data.ref.delete();
      return;
    }

    // Reintenta cada 30 s (3 veces) mientras no responda.
    for (let i = 0; i < 3; i++) {
      await sleep(30000);
      const now = await event.data.ref.get();
      if (!now.exists || now.get("answered")) return;
      await admin.messaging().send(msg);
    }
  }
);
