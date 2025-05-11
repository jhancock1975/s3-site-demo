document.getElementById('execute-btn').addEventListener('click', () => {
  const code = document.getElementById('code-editor').value;
  // Clear previous outputs
  document.getElementById('output-text').textContent = '';
  const canvasDiv = document.getElementById('render-canvas');
  canvasDiv.innerHTML = '';

  try {
    // Example: execute as JavaScript for text output
    const result = eval(code);
    document.getElementById('output-text').textContent = String(result);
    testFunc();
  } catch (err) {
    document.getElementById('output-text').textContent = err;
  }

  // If your code draws on a canvas, you could do:
  // const canvas = document.createElement('canvas');
  // canvas.width = canvasDiv.clientWidth;
  // canvas.height = canvasDiv.clientHeight;
  // canvasDiv.appendChild(canvas);
  // const ctx = canvas.getContext('2d');
  // /* run user graphics code with ctx */
});

function testFunc(){
  console.log("testFunc");
  return "testFunc";
}