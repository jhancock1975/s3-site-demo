<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>Echo Site</title>
</head>
<body>
  <h1>Echo Site</h1>
  <form id="echo-form">
    <input type="text" id="message" placeholder="Enter message" required />
    <button type="submit">Send</button>
  </form>
  <div id="response"></div>
  <script>
    const apiEndpoint = "${api_endpoint}";
    document.getElementById('echo-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const message = document.getElementById('message').value;
      const responseDiv = document.getElementById('response');
      try {
        const resp = await fetch(apiEndpoint + '/echo', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ message })
        });
        const data = await resp.json();
        responseDiv.textContent = data.echo;
      } catch (err) {
        responseDiv.textContent = 'Error: ' + err;
      }
    });
  </script>
</body>
</html>
