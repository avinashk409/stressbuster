const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');

const PROJECT_ID = "stressbuster-7b405";

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync("firestore.rules", "utf8"),
      host: "localhost",
      port: 8181
    },
  });
});

afterAll(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

describe("Firestore Security Rules", () => {
  // User Collection Tests
  describe("User Collection", () => {
    it("allows users to read any user profile", async () => {
      const userContext = testEnv.authenticatedContext("user_123", { role: "user" });
      const db = userContext.firestore();
      
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("users").doc("user_456").set({
          name: "Test User",
          role: "user",
          email: "test@example.com"
        });
      });

      await assertSucceeds(db.collection("users").doc("user_456").get());
    });

    it("allows users to update their own profile with allowed fields", async () => {
      const userId = "user_123";
      const userContext = await testEnv.authenticatedContext(userId, { role: "user" });
      const db = userContext.firestore();

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("users").doc(userId).set({
          name: "Original Name",
          email: "original@example.com",
          walletBalance: 1000
        });
      });

      await assertSucceeds(
        db.collection("users").doc(userId).update({
          name: "Updated Name",
          email: "updated@example.com",
          walletBalance: 1500
        })
      );
    });

    it("denies users from updating other users' profiles", async () => {
      const userContext = testEnv.authenticatedContext("user_123", { role: "user" });
      const db = userContext.firestore();

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("users").doc("user_456").set({
          name: "Other User",
          role: "user",
          email: "other@example.com"
        });
      });

      await assertFails(
        db.collection("users").doc("user_456").update({
          name: "Hacked Name"
        })
      );
    });
  });

  // Appointments Collection Tests
  describe("Appointments Collection", () => {
    it("allows users to read their own appointments", async () => {
      const userId = "user_123";
      const userContext = testEnv.authenticatedContext(userId, { role: "user" });
      const db = userContext.firestore();

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("appointments").doc("app_123").set({
          userId: userId,
          counselorId: "counselor_123",
          status: "scheduled",
          notes: "Test appointment"
        });
      });

      await assertSucceeds(db.collection("appointments").doc("app_123").get());
    });

    it("allows counselors to read all appointments", async () => {
      const counselorContext = await testEnv.authenticatedContext("counselor_123", { role: "counselor" });
      const db = counselorContext.firestore();

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("appointments").doc("app_123").set({
          userId: "user_123",
          counselorId: "counselor_123",
          status: "scheduled"
        });
        await context.firestore().collection("appointments").doc("app_456").set({
          userId: "user_456",
          counselorId: "counselor_123",
          status: "scheduled"
        });
      });

      const freshContext = await testEnv.authenticatedContext("counselor_123", { role: "counselor" });
      const freshDb = freshContext.firestore();
      await assertSucceeds(freshDb.collection("appointments").get());
    });

    it("allows users to create appointments", async () => {
      const userContext = testEnv.authenticatedContext("user_123", { role: "user" });
      const db = userContext.firestore();

      await assertSucceeds(
        db.collection("appointments").add({
          userId: "user_123",
          counselorId: "counselor_123",
          status: "scheduled",
          notes: "New appointment"
        })
      );
    });
  });

  // Sessions Collection Tests
  describe("Sessions Collection", () => {
    it("allows users to read their own sessions", async () => {
      const userId = "user_123";
      const userContext = testEnv.authenticatedContext(userId, { role: "user" });
      const db = userContext.firestore();

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("sessions").doc("session_123").set({
          userId: userId,
          counselorId: "counselor_123",
          status: "active",
          notes: "Test session"
        });
      });

      await assertSucceeds(db.collection("sessions").doc("session_123").get());
    });

    it("allows counselors to read their assigned sessions", async () => {
      const counselorContext = await testEnv.authenticatedContext("counselor_123", { role: "counselor" });
      const db = counselorContext.firestore();

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("sessions").doc("session_123").set({
          userId: "user_123",
          counselorId: "counselor_123",
          status: "active"
        });
        await context.firestore().collection("sessions").doc("session_456").set({
          userId: "user_456",
          counselorId: "counselor_123",
          status: "active"
        });
      });

      const freshContext = await testEnv.authenticatedContext("counselor_123", { role: "counselor" });
      const freshDb = freshContext.firestore();
      await assertSucceeds(freshDb.collection("sessions").get());
    });
  });

  // Payments Collection Tests
  describe("Payments Collection", () => {
    it("allows users to read their own payments", async () => {
      const userId = "user_123";
      const userContext = testEnv.authenticatedContext(userId, { role: "user" });
      const db = userContext.firestore();

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("payments").doc("payment_123").set({
          userId: userId,
          amount: 100,
          status: "completed"
        });
      });

      await assertSucceeds(db.collection("payments").doc("payment_123").get());
    });

    it("denies users from updating payments", async () => {
      const userContext = testEnv.authenticatedContext("user_123", { role: "user" });
      const db = userContext.firestore();

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("payments").doc("payment_123").set({
          userId: "user_123",
          amount: 100,
          status: "completed"
        });
      });

      await assertFails(
        db.collection("payments").doc("payment_123").update({
          status: "refunded"
        })
      );
    });
  });

  // Chat Messages Collection Tests
  describe("Chat Messages Collection", () => {
    it("allows users to read messages in their chats", async () => {
      const userId = "user_123";
      const userContext = await testEnv.authenticatedContext(userId, { role: "user" });
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("chats").doc("chat_123").set({
          participants: [userId, "counselor_123"]
        });
        await context.firestore().collection("chats").doc("chat_123")
          .collection("messages").doc("msg_123").set({
            senderId: "counselor_123",
            userId: userId,
            content: "Hello",
            timestamp: new Date()
          });
      });
      const freshContext = await testEnv.authenticatedContext(userId, { role: "user" });
      const freshDb = freshContext.firestore();
      await assertSucceeds(
        freshDb.collection("chats").doc("chat_123")
          .collection("messages").get()
      );
    });

    it("allows users to create messages in their chats", async () => {
      const userId = "user_123";
      const userContext = testEnv.authenticatedContext(userId, { role: "user" });
      const db = userContext.firestore();

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("chats").doc("chat_123").set({
          participants: [userId, "counselor_123"]
        });
      });

      await assertSucceeds(
        db.collection("chats").doc("chat_123")
          .collection("messages").add({
            senderId: userId,
            userId: userId,
            content: "Hello counselor",
            timestamp: new Date()
          })
      );
    });
  });
}); 