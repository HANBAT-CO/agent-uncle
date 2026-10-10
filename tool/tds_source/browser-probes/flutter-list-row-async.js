// Browser smoke check only. Effect-state assertions live in the widget/native
// tests; CanvasKit does not expose the painter state through browser semantics.
return (async () => {
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const labels = ['비동기 빛 → 깜빡임', '비동기 깜빡임 → 빛'];
  const button = label => [...document.querySelectorAll('flt-semantics-host [role="button"]')]
    .find(node => node.textContent === label);
  for (let i = 0; i < 50 && !labels.every(button); i++) await sleep(100);
  for (const label of labels) {
    const target = button(label);
    if (!target) throw new Error(`Async control missing: ${label}`);
    target.click();
    // Dark shine lasts 2500ms. Start the other ordering from an idle row.
    await sleep(2800);
    if (!button(label)) throw new Error(`Async control removed after activation: ${label}`);
  }
  return {activated: labels, semantics: document.querySelector('flt-semantics-host').textContent};
})();
