document.addEventListener('DOMContentLoaded', () => {
  const loginBtn = document.getElementById('loginBtn');
  const logoutBtn = document.getElementById('logoutBtn');
  const editorContainer = document.getElementById('editorContainer');

  function updateAuthButtons() {
    const loggedIn = !!localStorage.getItem('id_token');
    loginBtn.style.display = loggedIn ? 'none' : 'inline-block';
    logoutBtn.style.display = loggedIn ? 'inline-block' : 'none';
  }

  function isAdmin() {
    return localStorage.getItem('userRole') === 'admin';
  }

  loginBtn.addEventListener('click', () => window.location.href = 'login.html');
  logoutBtn.addEventListener('click', () => window.location.href = 'logout.html');

  updateAuthButtons();
  if (isAdmin()) {
    editorContainer.classList.remove('hidden');
  }
  window.addEventListener('storage', updateAuthButtons);
});
