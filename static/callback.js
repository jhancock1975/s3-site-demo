function parseHashFragment(hash) {
  const params = new URLSearchParams(hash.substring(1));
  const accessToken = params.get("access_token");
  const idToken = params.get("id_token");
  const expiresIn = params.get("expires_in");
  const tokenType = params.get("token_type");

  if (accessToken || idToken) {
    localStorage.setItem("access_token", accessToken);
    localStorage.setItem("id_token", idToken);
    localStorage.setItem("token_type", tokenType);
    localStorage.setItem("expires_in", expiresIn);

    window.location.href = "/";
  } else {
    document.getElementById("message").textContent = "No token found in the callback URL.";
  }
}

window.onload = function () {
  if (window.location.hash) {
    parseHashFragment(window.location.hash);
  } else {
    document.getElementById("message").textContent = "No hash fragment found in URL.";
  }
};
