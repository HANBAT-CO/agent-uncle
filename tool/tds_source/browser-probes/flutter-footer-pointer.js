// Run on the native Flutter gallery's ?family=list-footer-colors.
// Accessibility clicks invoke semantics without raw pointer feedback. Dispatch
// to the Flutter event surface to separately exercise the native pointer path.
return (async () => {
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const surface = document.querySelector('flt-glass-pane');
  if (!surface) throw new Error('Flutter event surface is not ready');
  const send = (type, buttons) => surface.dispatchEvent(new PointerEvent(type, {
    bubbles:true, cancelable:true, pointerId:501, pointerType:'mouse',
    isPrimary:true, button:type === 'pointermove' ? -1 : 0, buttons,
    clientX:180, clientY:54,
  }));
  send('pointermove',0);
  send('pointerdown',1);
  await sleep(350);
  send('pointerup',0);
  await sleep(350);
  const text = document.querySelector('flt-semantics-host')?.textContent ?? '';
  if (!text.includes('클릭 1')) throw new Error(`Raw Footer click missing: ${text}`);
  return 'One raw mouse press/release delivered through the Flutter surface';
})();
