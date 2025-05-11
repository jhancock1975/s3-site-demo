const gpt4o = "gpt4o";
document.getElementById('execute-btn').addEventListener('click', () => {
  
  // Clear previous outputs
  document.getElementById('output-text').textContent = '';
  const canvasDiv = document.getElementById('render-canvas');
  canvasDiv.innerHTML = '';

  try {
    // Example: execute as JavaScript for text output
    const result = transduce(gpt4o);
  } catch (err) {
    document.getElementById('output-text').textContent = err;
  }
});

function transduce(command){
  console.log("in transduce");
  if (command === "gpt4o") {
    console.log("in gpt4o");
    queryGpt4o();
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
    document.getElementById('output-text').textContent = String(data.choices[0].message.content);
    return data;
  } catch (err) {
    console.error('Error calling GPT-4o:', err);
    throw err;
  }
}