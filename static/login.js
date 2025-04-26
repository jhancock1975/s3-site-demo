function login() {
  const clientId = "4mt7pq78npi8s55lsetnq1g5c7";
  const cognitoDomain = "https://us-east-13k54foqzh.auth.us-east-1.amazoncognito.com";
  const redirectUri = "https://taptupo.com/callback.html";
  const responseType = "code";
  const scope = "email openid profile";
  const identityProvider = "Google";

  const loginUrl = `${cognitoDomain}/oauth2/authorize?identity_provider=${identityProvider}&redirect_uri=${encodeURIComponent(redirectUri)}&response_type=${responseType}&client_id=${clientId}&scope=${encodeURIComponent(scope)}`;

  window.location.href = loginUrl;
}
