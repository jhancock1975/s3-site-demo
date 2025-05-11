async function sendCodeToBackend(code) {
  const API_BASE="https://4aaqrkm65b.execute-api.us-east-1.amazonaws.com/prod"
  try {
    const response = await fetch(`${API_BASE}/exchange`, {
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
