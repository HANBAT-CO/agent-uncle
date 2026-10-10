// Paired capture state for the first-frame press/release regression.
return (async () => {
  await window.tdsReference.ready;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  const target = document.querySelector('[data-case="footer"]');
  target.dispatchEvent(new MouseEvent('mousedown',{bubbles:true,button:0,buttons:1}));
  window.dispatchEvent(new MouseEvent('mouseup',{bubbles:true,button:0}));
  await sleep(500);
  window.tdsReference.updateFooter({children:[
    {id:'inherit',label:'상속'},
    {id:'custom',label:'명시',color:'#03b26c',wrap:true},
  ]});
  await sleep(650);
  const colors = [...document.querySelectorAll('.tds-mobile-list-footer__text')]
    .map(node => getComputedStyle(node).color);
  const scale = new DOMMatrixReadOnly(getComputedStyle(
    document.querySelector('.tds-mobile-list-footer__content')).transform).a;
  if (colors.some(color => color !== 'rgb(3, 178, 108)') || scale !== 1) {
    throw new Error(`Fresh tap leaked a source press snapshot: ${colors} scale=${scale}`);
  }
  return {colors,scale};
})();
