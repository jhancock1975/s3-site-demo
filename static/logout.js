const clientId = "YOUR_COGNITO_APP_CLIENT_ID";
const logoutUri = "https://your-domain.com";
const cognitoDomain = "https://your-cognito-domain.auth.YOUR-REGION.amazoncognito.com";

// Clear tokens from storage
localStorage.removeItem("access_token");
localStorage.removeItem("id_token");
localStorage.removeItem("token_type");
localStorage.removeItem("expires_in");

// Redirect to Cognito logout
window.location.href = `${cognitoDomain}/logout?client_id=${clientId}&logout_uri=${encodeURIComponent(logoutUri)}`;
