const gpt4o = "gpt4o";
const logout = "logout";
document.getElementById('execute-btn').addEventListener('click', () => {
  
  try {
    //call transducer with gpt4o message
    const result = transduce(gpt4o);
  } catch (err) {
    document.getElementById('output-text').textContent = err;
  }
});

document.getElementById('logout-btn').addEventListener('click', async () => {
  // 1) Sign out of Google on the client
  if (window.gapi && gapi.auth2) {
    try {
      const auth2 = gapi.auth2.getAuthInstance();
      if (auth2) {
        await auth2.signOut();
        auth2.disconnect();
        console.log('Google user signed out.');
      }
    } catch (err) {
      console.warn('Error signing out of Google:', err);
    }
  }

  // 2) Clear any local tokens you may have stored
  localStorage.removeItem('idToken');
  localStorage.removeItem('refreshToken');
  // …etc.

  // 3) Redirect to your AWS Cognito logout URL
  //    Replace these placeholders with your real values:
  const cognitoDomain = 'us-east-13k54foqzh.auth.us-east-1.amazoncognito.com';
  const clientId      = '4mt7pq78npi8s55lsetnq1g5c7';
  const logoutRedirect = encodeURIComponent(window.location.origin); 
  //    This should match one of your “Allowed logout URLs” in Cognito

  const logoutUrl =
    `https://${cognitoDomain}/logout`
    + `?client_id=${clientId}`
    + `&logout_uri=${logoutRedirect}`;

  window.location.href = logoutUrl;
});


function transduce(command){
  console.log("in transduce");
  if (command === gpt4o) {
    console.log("in gpt4o");
    queryGpt4o();
  } else if (command === logout) {

  } else{
    console.log("unknown transduce command");
  }
}

async function queryGpt4o() {
  console.log("in queryGpt4o");
  const promptText = document.getElementById('code-editor').value;
  try {
    const res = await fetch('https://api.taptupo.com/gpt-4o/gpt-4o', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt: promptText })
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }
    const data = await res.json();
    // Clear previous outputs
    document.getElementById('output-text').textContent = '';
    document.getElementById('render-canvas').innerHTML = '';
    document.getElementById('output-text').textContent = String(data.choices[0].message.content);
    return data;
  } catch (err) {
    console.error('Error calling GPT-4o:', err);
    throw err;
  }
}