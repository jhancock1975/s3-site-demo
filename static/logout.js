(function() {
  //Wipe local tokens
  ['id_token','access_token','refresh_token'].forEach(k => localStorage.removeItem(k));


  // 2) Build the Cognito logout URL
  const CLIENT_ID     = "4mt7pq78npi8s55lsetnq1g5c7";
  const COGNITO_DOMAIN= "us-east-13k54foqzh.auth.us-east-1.amazoncognito.com";
  const REDIRECT_URI  = "https://taptupo.com/loggedout.html";  // where you want users to land after logout

  const logoutUrl = 
    `https://${COGNITO_DOMAIN}/logout?` +
    `client_id=${encodeURIComponent(CLIENT_ID)}` +
    `&logout_uri=${encodeURIComponent(REDIRECT_URI)}`;

  // 3) Redirect browser to kill the Cognito session
  window.location.replace(logoutUrl);

  // 4) In case replace() is blocked, update the link
  document.getElementById("continue-link").href = logoutUrl;
})();
