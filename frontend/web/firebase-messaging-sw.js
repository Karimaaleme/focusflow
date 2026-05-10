importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCpttwg8J122go6VExbDTrzDEgp-VlY2Go",
  authDomain: "focusfloww.firebaseapp.com",
  projectId: "focusfloww",
  storageBucket: "focusfloww.firebasestorage.app",
  messagingSenderId: "585210053030",
  appId: "1:585210053030:web:0541c5bae9ff4e08070f67"
});

const messaging = firebase.messaging();

// Show notification when app is in the background / closed
messaging.onBackgroundMessage(function(payload) {
  const title = payload.notification?.title ?? "FocusFlow";
  const options = {
    body: payload.notification?.body ?? "",
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
  };
  return self.registration.showNotification(title, options);
});
