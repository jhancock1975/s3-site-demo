// js/main.js
document.addEventListener('DOMContentLoaded', async () => {
  const idToken = localStorage.getItem('id_token');
  if (!idToken) return;               // not logged in
  const payload = JSON.parse(atob(idToken.split('.')[1]));
  const groups  = payload['cognito:groups'] || [];

  if (!groups.includes('Admins')) return;  // no admin rights

  // show the admin UI
  document.getElementById('logoutBtn').classList.remove('hidden');

  // wire up logout
  document.getElementById('logoutBtn').onclick = () => {
    localStorage.removeItem('id_token');
    window.location.reload();
  };

// Toggle logout/login
const logoutBtn = document.getElementById('logoutBtn');
logoutBtn.addEventListener('click', () => {
  if (logoutBtn.id === 'logoutBtn') {
    logoutBtn.textContent = 'Login';
    logoutBtn.id = 'loginBtn';
  } else {
    logoutBtn.textContent = 'Log Out';
    logoutBtn.id = 'logoutBtn';
  }
});

// Execute JS code from textarea
const executeBtn = document.getElementById('executeBtn');
executeBtn.addEventListener('click', () => {
  const code = document.getElementById('codeEditor').value;
  try {
    new Function(code)();
  } catch (err) {
    console.error(err);
    alert('Error: ' + err.message);
  }
});
});
