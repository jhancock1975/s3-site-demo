document.addEventListener('DOMContentLoaded', () => {
  if (!document.getElementById('markdownEditor')) return;

  const easyMDE = new EasyMDE({
    element: document.getElementById('markdownEditor'),
    placeholder: 'Write your Markdown here...'
  });

  document.getElementById('saveMd').addEventListener('click', () => {
    const md = easyMDE.value();
    document.getElementById('output').textContent = md;
  });
});
