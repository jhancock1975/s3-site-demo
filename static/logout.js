function logout() {
  const clientId = "4mt7pq78npi8s55lsetnq1g5c7";
  const cognitoDomain = "https://us-east-13k54foqzh.auth.us-east-1.amazoncognito.com";
  const logoutUri = "https://taptupo.com";

  // Clear tokens from storage
  localStorage.removeItem("access_token");
  localStorage.removeItem("id_token");
  localStorage.removeItem("token_type");
  localStorage.removeItem("expires_in");

  // Redirect to Cognito logout
  window.location.href = `${cognitoDomain}/logout?client_id=${clientId}&logout_uri=${encodeURIComponent(logoutUri)}`;
}
