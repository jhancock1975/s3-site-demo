async function sendCodeToBackend(code) {
  try {
    const response = await fetch("/exchange", {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ code })
    });

    const data = await response.json();

    if (data.id_token) {
      localStorage.setItem("id_token", data.id_token);
      localStorage.setItem("access_token", data.access_token);
      window.location.href = "/";
    } else {
      document.getElementById("message").textContent = "Failed to login.";
      console.error(data);
    }
  } catch (err) {
    console.error("Error sending code to backend:", err);
    document.getElementById("message").textContent = "Error contacting backend.";
  }
}

window.onload = function () {
  const params = new URLSearchParams(window.location.search);
  const code = params.get("code");
  if (code) {
    sendCodeToBackend(code)      // same as you already have in callback.js
      .then(() => { /* redirect on success */ })
      .catch(() => { /* show error */ });
  } else {
    document.getElementById("message").textContent = "No authorization code found.";
  }
};
