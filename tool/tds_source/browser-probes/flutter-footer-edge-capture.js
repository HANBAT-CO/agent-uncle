// Color/shape expectations are asserted by widget + native-engine tests.
// This checks browser pointer delivery/activation and captures the same states.
return (async () => {
  const phase = new URLSearchParams(location.search).get('edgeCase');
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const host = () => document.querySelector('flt-semantics-host');
  for (let i = 0; i < 100; i++) {
    document.querySelector('flt-semantics-placeholder')?.click();
    if (host()?.textContent.includes('초기화')) break;
    await sleep(100);
  }
  if (!host()?.textContent.includes('초기화')) throw new Error('Flutter semantics not ready');
  const control = async label => {
    const node = [...host().querySelectorAll('[role="button"]')].find(n => n.textContent === label);
    if (!node) throw new Error(`Missing control ${label}`);
    node.click(); await sleep(180);
  };
  const point = label => {
    const nodes = [...host().querySelectorAll('flt-semantics')]
      .filter(n => n.textContent.split('\n').includes(label) || n.getAttribute('aria-label')?.includes(label))
      .map(n => n.getBoundingClientRect()).filter(r => r.width > 0 && r.height > 0)
      .sort((a,b) => a.width*a.height - b.width*b.height);
    if (!nodes[0]) throw new Error(`Missing semantic text geometry: ${label}`);
    // Flutter may merge the outer label into its full button rect. Its center
    // would hit the nested Footer. Target the top text row for outer-only input.
    return {x:nodes[0].x+nodes[0].width/2,
      y:nodes[0].y+(label === '바깥' ? Math.min(13,nodes[0].height/2) : nodes[0].height/2)};
  };
  const nested = !['from-only','repress'].includes(phase);
  if (phase === 'late' || phase === 'recaptured') {
    await control('안쪽 숨기기'); await control('안쪽 복원');
    if (phase === 'recaptured') await control('바깥 색상 변경');
  }
  const coordinates = point(nested ? phase === 'bubbled' ? '안쪽' : '바깥' : '명시');
  const surface = document.querySelector('flt-glass-pane');
  const send = (type,buttons) => surface.dispatchEvent(new PointerEvent(type, {
    bubbles:true,cancelable:true,pointerId:901,pointerType:'mouse',isPrimary:true,
    button:type === 'pointermove' ? -1 : 0,buttons,clientX:coordinates.x,clientY:coordinates.y,
  }));
  send('pointermove',0); send('pointerdown',1); await sleep(450);
  if (phase === 'repress') { send('pointerup',0); await sleep(450); send('pointerdown',1); await sleep(450); }
  if (phase === 'bubbled') { send('pointerup',0); await sleep(450); }
  const semantics = host().textContent;
  if (phase === 'repress' && !semantics.includes('클릭 1')) throw new Error(`Missing first click: ${semantics}`);
  if (phase === 'bubbled' && !semantics.includes('순서 안쪽 → 바깥')) throw new Error(`Wrong nested click order: ${semantics}`);
  return {phase,coordinates,semantics};
})();
