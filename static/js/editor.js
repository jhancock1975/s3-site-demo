// js/editor.js
let easyMDE, currentPost = null;

document.addEventListener('DOMContentLoaded', () => {
  if (!document.getElementById('markdownEditor')) return;

  easyMDE = new EasyMDE({
    element: document.getElementById('markdownEditor'),
    placeholder: 'Write your Markdown here…',
    spellChecker: false
  });

  document.getElementById('previewPostBtn').onclick = () => {
    const md = easyMDE.value();
    document.getElementById('previewPane').textContent = md;
    document.getElementById('previewPane').classList.toggle('hidden', !md);
  };

  document.getElementById('savePostBtn').onclick = async () => {
    const body  = easyMDE.value();
    const title = prompt('Title for this post:', currentPost.title);
    const payload = { title, body, id: currentPost.id };

    const res = await fetch('/api/posts', {
      method: currentPost.id ? 'PUT' : 'POST',
      headers: {
        'Content-Type':'application/json',
        'Authorization': localStorage.getItem('id_token')
      },
      body: JSON.stringify(payload)
    });
    if (!res.ok) return alert('Save failed');
    const saved = await res.json();
    currentPost = saved;
    alert('Post saved successfully!');
    window.location.reload();  // or just update the list
  };

  document.getElementById('viewNormalBtn').onclick = () => {
    window.location.href = '/';  // or clear the admin flag
  };
});
