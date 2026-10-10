// Run on the native Flutter gallery family=list-footer-contexts, with semantics
// enabled. Only raw pointer delivery/controls are asserted here. Color/shape
// assertions run in widget/native tests; the canvas semantics cannot prove them.
return (async () => {
  const phase = new URLSearchParams(location.search).get('contextCase');
  if (!['cleanup', 'restore', 'late', 'alias'].includes(phase)) {
    throw new Error(`Unknown Footer context case: ${phase}`);
  }
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const semantics = () => document.querySelector('flt-semantics-host');
  for (let i = 0; i < 50 && !semantics()?.textContent.includes('누름 설정만 변경'); i++) await sleep(100);
  const control = async label => {
    const node = [...semantics().querySelectorAll('[role="button"]')]
      .find(button => button.textContent === label);
    if (!node) throw new Error(`Missing context control: ${label}`);
    node.click();
    await sleep(180);
  };
  const surface = document.querySelector('flt-glass-pane');
  if (!surface) throw new Error('Flutter event surface is not ready');
  const send = (type, buttons) => surface.dispatchEvent(new PointerEvent(type, {
    bubbles:true, cancelable:true, pointerId:801, pointerType:'mouse', isPrimary:true,
    button:type === 'pointermove' ? -1 : 0, buttons, clientX:180, clientY:54,
  }));
  if (phase === 'late') {
    await control('선 색상으로 초기화');
    await control('하위 텍스트 추가');
  }
  if (phase === 'alias') await control('별칭 초기화');
  send('pointermove', 0);
  send('pointerdown', 1);
  await sleep(450);
  if (phase === 'alias') await control('동일 색상 별칭');
  send('pointerup', 0);
  await sleep(450);
  if (phase === 'cleanup' || phase === 'restore') await control('누름 설정만 변경');
  if (phase === 'restore') await control('두 설정 변경');
  const text = semantics()?.textContent ?? '';
  if (!text.includes('클릭 1')) throw new Error(`Footer pointer click missing or repeated: ${text}`);
  if (phase === 'late' && !/^상속\s*명시\s*추가/.test(text)) throw new Error(`Late text is missing: ${text}`);
  return {phase, semantics:text};
})();
