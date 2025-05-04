// js/main.js
document.addEventListener('DOMContentLoaded', async () => {
  const idToken = localStorage.getItem('id_token');
  if (!idToken) return;               // not logged in
  const payload = JSON.parse(atob(idToken.split('.')[1]));
  const groups  = payload['cognito:groups'] || [];

  if (!groups.includes('Admins')) return;  // no admin rights

  // show the admin UI
  document.getElementById('adminUI').classList.remove('hidden');
  document.getElementById('logoutBtn').classList.remove('hidden');

  // wire up logout
  document.getElementById('logoutBtn').onclick = () => {
    localStorage.removeItem('id_token');
    window.location.reload();
  };

  // load existing posts
  const postList = document.getElementById('postList');
  const posts = await fetch('/api/posts').then(r => r.json());
  posts.forEach(p => {
    let li = document.createElement('li');
    li.textContent = p.title;
    li.onclick = () => loadPost(p);
    postList.appendChild(li);
  });

  // new post
  document.getElementById('newPostBtn').onclick = () => {
    currentPost = { id: null, title: 'Untitled', body: '' };
    easyMDE.value('');
  };
});
