import React from 'react';
import { createRoot } from 'react-dom/client';
import * as TDS from '@toss/tds-mobile';
import { TDSMobileAITProvider } from '@toss/tds-mobile-ait';

const { TDSMobileProvider, Button, Text, Badge, Switch, Checkbox, TextButton, Border, Loader } = TDS;
const parameters = new URLSearchParams(location.search);
const theme = parameters.get('theme') ?? 'light';
const state = parameters.get('state') ?? 'initial';
const size = parameters.get('size') ?? 'xlarge';
const family = parameters.get('family') ?? 'buttons';
const scale = Number(parameters.get('scale') ?? 100);
const userAgent = { isAndroid: parameters.get('os') !== 'ios', isIOS: parameters.get('os') === 'ios', isTossApp: false, fontScale: scale, colorPreference: theme };
document.body.style.backgroundColor = theme === 'dark' ? '#17171c' : '#fff';
window.tdsReference = { version: '2.5.1', runtimeExports: Object.keys(TDS).sort(), events: [] };

function SheetHookOwner() {
  const sheet = TDS.useBottomSheet({ closeOnDestroy: false });
  React.useEffect(() => {
    window.tdsReference.openHookSheet = () => sheet.open({header:'훅 바텀시트',children:<div style={{height:100}}>소유자 수명 확인</div>});
  }, [sheet]);
  return null;
}

function SheetHookFixture() {
  const [mounted, setMounted] = React.useState(true);
  React.useEffect(() => { window.tdsReference.destroyHookOwner = () => setMounted(false); }, []);
  return mounted ? <SheetHookOwner /> : null;
}

function LoaderEventsFixture() {
  const [count, setCount] = React.useState(0);
  React.useEffect(() => { window.tdsReference.setLoaderCount = setCount; }, []);
  return <TDS.GlobalConfigProvider config={{
    onLoadingStart: () => window.tdsReference.events.push('start'),
    onLoadingFinish: () => window.tdsReference.events.push('finish'),
  }}>
    {Array.from({length:count}, (_,i) => <TDS.Loader key={i} label={`로딩 ${i}`} />)}
  </TDS.GlobalConfigProvider>;
}

function ButtonLifecycleFixture() {
  const [config, setConfig] = React.useState({
    loading: false, disabled: false, inert: false,
    variant: parameters.get('variant') ?? 'fill',
  });
  React.useEffect(() => {
    window.tdsReference.updateButton = patch => setConfig(previous => ({...previous, ...patch}));
  }, []);
  return <Button {...config} data-case="button-lifecycle"
    onClick={() => window.tdsReference.events.push('click')}>확인하기</Button>;
}

function HighlightFixture() {
  const [open, setOpen] = React.useState(parameters.get('open') !== 'false');
  React.useEffect(() => { window.tdsReference.setHighlightOpen = setOpen; }, []);
  const props = {
    padding: Number(parameters.get('padding') ?? 8),
    message: '여기에서 새로운 기능을\n확인할 수 있어요',
    messageXAlignment: parameters.get('align') ?? undefined,
    messageYAlignment: parameters.get('side') ?? undefined,
    onClick: () => window.tdsReference.events.push('click'),
  };
  const rect = {x: Number(parameters.get('x') ?? 40), y: Number(parameters.get('y') ?? 160), width: 160, height: 48};
  if (state === 'ui') return <TDS.HighlightUI {...props} {...rect}
    style={{position:'fixed',inset:0}} closeAriaLabel="닫기" />;
  return <div style={{position:'fixed',left:rect.x,top:rect.y,width:rect.width}}>
    <TDS.Highlight {...props} open={open} delay={Number(parameters.get('delay') ?? 0)}
      onClose={() => { window.tdsReference.events.push('close'); if (state !== 'reject') setOpen(false); }}
      onExited={() => window.tdsReference.events.push('exited')}>
      <button id="highlight-target" style={{width:rect.width,height:rect.height}} onClick={() => window.tdsReference.events.push('target')}>대상</button>
    </TDS.Highlight>
  </div>;
}

function FullTooltipFixture() {
  const [config, setConfig] = React.useState({
    open: parameters.get('controlled') === 'false' ? undefined : state !== 'closed',
    floating: parameters.get('floating') === 'true',
    placement: parameters.get('side') ?? undefined,
    anchorPositionByRatio: parameters.has('ratio') ? Number(parameters.get('ratio')) : undefined,
    anchorOverlapped: parameters.get('overlap') === 'true',
    offset: parameters.has('offset') ? Number(parameters.get('offset')) : undefined,
    messageAlign: parameters.get('align') ?? 'center',
    message: state === 'resized' ? '첫 번째 안내\n두 번째 안내\n세 번째 안내' : state === 'multiline' ? '새로운 기능을 확인하고\n안내를 계속 읽어 보세요' : '새로운 기능을 확인해 보세요',
    duration: Number(parameters.get('duration') ?? 30),
  });
  React.useEffect(() => {
    window.tdsReference.updateFullTooltip = patch => setConfig(previous => ({...previous, ...patch}));
  }, []);
  const onClose = React.useCallback(() => window.tdsReference.events.push('close'), []);
  const onClickOutside = React.useCallback(() => window.tdsReference.events.push('outside'), []);
  return <div data-case="full-tooltip-host" style={{marginLeft:-24,marginRight:-24,paddingTop:100}}>
    <TDS.FullTooltip {...config} onClose={onClose} onClickOutside={onClickOutside}>
      <div data-case="target" style={{height:48,background:'#f2f4f6',textAlign:'center'}}>대상</div>
    </TDS.FullTooltip>
  </div>;
}

function WikiViewportFixture() {
  const [top, setTop] = React.useState(Number(parameters.get('y') ?? 650));
  React.useEffect(() => { window.tdsReference.setWikiY = setTop; }, []);
  return <div style={{height:2000,position:'relative'}}>
    <TDS.Text typography="t5" as="div" data-case="wiki-anchor" style={{position:'absolute',top,width:230}}>
      <TDS.WikiText hasPaddingAnimation={parameters.get('padding') !== 'false'}
        onClick={() => window.tdsReference.events.push('click')}
        description={'첫 번째 줄의 설명이에요.\n두 번째 줄의 설명도 확인해요.'}>
        금융 용어
      </TDS.WikiText>
    </TDS.Text>
  </div>;
}

function ListFooterColorsFixture() {
  const [config, setConfig] = React.useState({
    theme, generation: 0, textColor: undefined, iconColor: undefined,
    children: [{id:'inherit', label:'상속'}, {id:'custom', label:'명시', color:'#f04452'}],
    icons: [{id:'inherit-icon'}, {id:'custom-icon', color:'#3182f6'}],
  });
  React.useEffect(() => {
    window.tdsReference.updateFooter = patch => setConfig(previous => ({...previous, ...patch}));
  }, []);
  const text = item => <TDS.ListFooter.Text key={item.id} data-case={item.id} color={item.color}>
    {item.label}
  </TDS.ListFooter.Text>;
  return <TDS.ColorSchemeArea theme={config.theme} asChild>
    <div data-case="footer-color-host" style={{background:config.theme === 'dark' ? '#17171c' : '#fff'}}>
      <TDS.ListFooter key={config.generation} data-case="footer" onClick={() => window.tdsReference.events.push('footer-click')}
        textColor={config.textColor} iconColor={config.iconColor}
        icon={config.iconName ?? <span>{config.icons.map(item => <TDS.ListFooter.Icon key={item.id}
          data-case={item.id} name="icon-arrow-right-mono" color={item.color} />)}</span>}>
        <span>{config.children.map(item => item.wrap
          ? <span key={item.id} data-case={`${item.id}-wrapper`}>{text(item)}</span> : text(item))}</span>
      </TDS.ListFooter>
    </div>
  </TDS.ColorSchemeArea>;
}

function ListFooterNestedFixture() {
  const [config, setConfig] = React.useState({
    theme, generation:0, outer:'blue500', inner:'red500', showInner:true,
    outerIcon:'green500', innerIcon:'orange500', innerGeneration:0,
  });
  React.useEffect(() => {
    window.tdsReference.updateNestedFooter = patch => setConfig(previous => ({...previous, ...patch}));
  }, []);
  const adaptive = name => `var(--adaptive${name[0].toUpperCase()}${name.slice(1)})`;
  return <TDS.ColorSchemeArea theme={config.theme} asChild>
    <div data-case="nested-footer-host">
      <TDS.ListFooter key={config.generation} data-case="outer-footer"
        onClick={() => window.tdsReference.events.push('outer-click')}>
        <div style={{width:'100%',textAlign:'center'}}>
          <TDS.ListFooter.Text data-case="outer-text" color={adaptive(config.outer)}>바깥</TDS.ListFooter.Text>
          <TDS.ListFooter.Icon data-case="outer-icon" name="icon-arrow-right-mono" color={adaptive(config.outerIcon)} />
          {config.showInner && <ul style={{margin:0,padding:0,listStyle:'none'}}>
            <TDS.ListFooter key={config.innerGeneration} data-case="inner-footer"
              onClick={() => window.tdsReference.events.push('inner-click')}>
              <TDS.ListFooter.Text data-case="inner-text" color={adaptive(config.inner)}>안쪽</TDS.ListFooter.Text>
              <TDS.ListFooter.Icon data-case="inner-icon" name="icon-arrow-right-mono" color={adaptive(config.innerIcon)} />
            </TDS.ListFooter>
          </ul>}
        </div>
      </TDS.ListFooter>
    </div>
  </TDS.ColorSchemeArea>;
}

// Isolate block typography and direct Footer slots from inline fixture layout.
// All rendering still comes from the unmodified, pinned React package.
function VisualTypographyFixture() {
  const fontWeight = parameters.get('weight') ?? 'regular';
  const label = state === 'multiline' ? '토스 Ag 012\n둘째 줄 xyz' : '토스 Ag 012';
  const types = parameters.get('types') === 'all'
    ? ['t1','st1','st2','st3','t2','st4','st5','st6','t3','st7',
      't4','st8','st9','t5','st10','t6','st11','t7','st12','st13']
    : ['t7','t5','t2','t1'];
  return types.map(typography => <div key={typography}
    data-case={`type-${typography}`} style={{marginBottom:16}}>
    <TDS.Text as="div" display="block" typography={typography} fontWeight={fontWeight}
      style={{whiteSpace:'pre-line'}}>{label}</TDS.Text>
  </div>);
}

function VisualFooterFixture() {
  const variant = parameters.get('variant') ?? 'default';
  const width = Number(parameters.get('width') ?? 342);
  return <div style={{width}}>
    <TDS.ListFooter data-case="visual-footer"
      onClick={() => window.tdsReference.events.push('footer-click')}
      icon={variant === 'shadow' ? undefined : 'icon-arrow-right-mono'}
      shadow={variant === 'shadow' ? <TDS.ListFooter.Shadow style={{opacity:1}} /> : undefined}>
      {variant === 'shadow' ? <div style={{height:120,width:'100%'}} />
        : variant === 'multiline' ? '글자와 화살표의 위치를 확인하고 다음 안내를 읽어요' : '더 보기 Ag'}
    </TDS.ListFooter>
  </div>;
}

function Fixture() {
  const [checked, setChecked] = React.useState(parameters.get('checked') === 'true');
  const [tab, setTab] = React.useState(0);
  const [progress, setProgress] = React.useState(0);
  const [rowConfig, setRowConfig] = React.useState({theme, width: undefined, height: undefined});
  const effectRow = React.useRef(null);
  const runRowCommands = commands => {
    for (const [effect, value] of commands ?? []) {
      window.tdsReference.events.push(effect);
      effectRow.current[effect](value);
    }
  };
  React.useEffect(() => {
    // AIT installs light tokens at :root. Toast's motion wrapper portals into
    // body, outside ColorSchemeArea. Mirror the ORIGINAL area's emitted CSS
    // variables to the standalone fixture host, as a dark-capable host would.
    // No native tokens or package source modifications are used here.
    const fixtureStyle = document.getElementById('fixture').style;
    for (const property of fixtureStyle) {
      if (property.startsWith('--')) document.documentElement.style.setProperty(property, fixtureStyle.getPropertyValue(property));
    }
    window.tdsReference.ready = document.fonts.ready.then(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    window.tdsReference.rowEffect = (effect, value) => effectRow.current[effect](value);
    window.tdsReference.updateRow = patch => setRowConfig(previous => ({...previous, ...patch}));
    window.tdsReference.setProgress = setProgress;
    window.tdsReference.setChecked = setChecked;
  }, []);
  return <TDSMobileAITProvider><TDSMobileProvider userAgent={userAgent}>
    <TDS.ColorSchemeArea theme={theme} asChild><div id="fixture" style={{ padding: 24, width: 390, boxSizing: 'border-box', background: theme === 'dark' ? '#17171c' : '#fff', fontFamily: 'Toss Product Sans' }}>
      {family === 'sheet-hook' && <SheetHookFixture />}
      {family === 'loading-events' && <LoaderEventsFixture />}
      {family === 'button-lifecycle' && <ButtonLifecycleFixture />}
      {family === 'highlight' && <HighlightFixture />}
      {family === 'wiki-viewport' && <WikiViewportFixture />}
      {family === 'full-tooltip' && <FullTooltipFixture />}
      {family === 'visual-typography' && <VisualTypographyFixture />}
      {family === 'visual-footer' && <VisualFooterFixture />}
      {family === 'progress' && <TDS.ProgressBar progress={progress} size="bold" />}
      {family === 'switch' && <Switch checked={checked}
        disabled={state === 'disabled'} inert={state === 'inert'}
        hasTouchEffect={state !== 'no-effect'}
        onClick={() => window.tdsReference.events.push('click')}
        onChange={(_,next) => {
          window.tdsReference.events.push(['change', next]);
          if (state !== 'reject') setChecked(next);
        }} />}
      {family === 'checkbox' && ['Circle', 'Line', 'LineTransparent'].map(variant => {
        const Component = Checkbox[variant];
        return <div key={variant} data-case={variant} style={{marginBottom:24}}>
          <Component checked={checked} disabled={state === 'disabled'} inert={state === 'inert'}
            inputType={state === 'radio' ? 'radio' : 'checkbox'}
            onChange={event => {
              window.tdsReference.events.push(['change',event.target.checked]);
              if (state !== 'reject') setChecked(event.target.checked);
            }}
            onCheckedChange={next => window.tdsReference.events.push(['checked',next])}
          >동의하기</Component>
        </div>;
      })}
      {family === 'text-buttons' && ['xsmall','small','medium','large','xlarge','xxlarge'].map(buttonSize =>
        <div key={buttonSize} data-case={buttonSize} style={{display:'flex',marginBottom:24,width:state === 'multiline' ? 130 : undefined}}>
          <TextButton size={buttonSize} variant={parameters.get('variant') ?? 'arrow'}
            arrowPlacement={parameters.get('placement') ?? 'block'} disabled={state === 'disabled'}
            color={parameters.get('color') ?? undefined}
            onClick={() => window.tdsReference.events.push('click')}>
            {state === 'multiline' ? '자세한 내용을 확인하기' : '확인하기'}
          </TextButton>
        </div>)}
      {family === 'buttons' && ['primary','danger','dark','light'].flatMap(color => ['fill','weak'].map(variant =>
        <div key={`${color}-${variant}`} data-case={`${color}-${variant}`} style={{ marginBottom: 16, background: color === 'light' ? '#4e5968' : undefined }}>
          <Button size={size} color={color} variant={variant} disabled={state.includes('disabled')} loading={state.includes('loading')}>확인하기</Button>
        </div>))}
      {family === 'typography' && ['t1','t2','t3','t4','t5','t6','t7','st13'].map(typography => <div key={typography} data-case={typography}><Text typography={typography}>토스 디자인 Toss 0123</Text></div>)}
      {family === 'controls' && <>
        <Switch checked={checked} onChange={(_,next) => setChecked(next)} />
        <Checkbox.Circle checked={checked} onChange={e => setChecked(e.target.checked)} />
        <Checkbox.Line checked={checked} onChange={e => setChecked(e.target.checked)} />
        <Border />
        <TextButton size="medium" variant="arrow">확인하기</TextButton>
        <Loader />
      </>}
      {family === 'badges' && ['xsmall','small','medium','large'].flatMap(size => ['blue','teal','green','red','yellow','elephant'].map(color =>
        <div key={`${size}-${color}`} style={{ marginBottom: 8 }}><Badge size={size} color={color} variant="weak">배지</Badge></div>))}
      {family === 'fields' && ['box','line','big','hero'].map(variant => <TDS.TextField key={variant} variant={variant}
        label="이름" labelOption="sustain" value={state === 'empty' ? '' : '토스 디자인'} placeholder="이름을 입력하세요" help="도움말"
        hasError={state === 'error'} disabled={state === 'disabled'} onChange={() => {}} />)}
      {family === 'toast' && <>
        <TDS.Toast position="top" open duration={Infinity} text="변경 사항을 저장했어요" />
        <TDS.Toast position="bottom" open duration={Infinity}
          text={state === 'multiline' ? '토스 디자인 시스템으로 네이티브 Flutter 위젯을 만들고 원본과 비교하고 있어요' : '변경 사항을 저장했어요'}
          button={state === 'action' ? <TDS.Toast.Button>실행 취소</TDS.Toast.Button> : undefined} />
      </>}
      {family === 'lists' && <TDS.List>
        <TDS.ListHeader title={<TDS.ListHeader.TitleParagraph>내 계좌</TDS.ListHeader.TitleParagraph>}
          description={<TDS.ListHeader.DescriptionParagraph>자산을 확인해요</TDS.ListHeader.DescriptionParagraph>}
          right={<TDS.ListHeader.RightText>전체 보기</TDS.ListHeader.RightText>} />
        {['1RowTypeA','2RowTypeA','2RowTypeD','3RowTypeA'].map(type => <TDS.ListRow key={type}
          border="indented" withArrow disabled={state === 'disabled'}
          contents={<TDS.ListRow.Texts type={type} top="토스뱅크" middle="입출금 통장" bottom="계좌 정보를 확인해요" />}
          right={<TDS.ListRow.Texts type="Right1RowTypeA" top="12,000원" />} />)}
        <TDS.TableRow align="space-between" left="은행" right="토스뱅크" leftRatio={40} />
        <TDS.ListFooter>더 보기</TDS.ListFooter>
      </TDS.List>}
      {family === 'list-footer-colors' && <ListFooterColorsFixture />}
      {family === 'list-footer-nested' && <ListFooterNestedFixture />}
      {family === 'list-effects' && <TDS.ColorSchemeArea theme={rowConfig.theme} asChild>
        <div data-case="list-effect-host" style={{width: rowConfig.width, background: rowConfig.theme === 'dark' ? '#17171c' : '#fff'}}
          onMouseDown={() => runRowCommands(rowConfig.ancestorDown)} onTouchStart={() => runRowCommands(rowConfig.ancestorDown)}
          onMouseUp={() => runRowCommands(rowConfig.ancestorUp)} onTouchEnd={() => runRowCommands(rowConfig.ancestorUp)}>
          <TDS.ListRow key={rowConfig.generation} ref={effectRow} border="indented"
            disabled={rowConfig.disabled} withTouchEffect={rowConfig.withTouchEffect}
            onClick={rowConfig.clickable === false ? undefined : () => runRowCommands(rowConfig.click)}
            onMouseDown={() => runRowCommands(rowConfig.rowDown)} onTouchStart={() => runRowCommands(rowConfig.rowDown)}
            onMouseUp={() => runRowCommands(rowConfig.rowUp)} onTouchEnd={() => runRowCommands(rowConfig.rowUp)}
            contents={<div data-case="list-effect-content" style={{height: rowConfig.height}}
              onMouseDown={() => runRowCommands(rowConfig.childDown)} onTouchStart={() => runRowCommands(rowConfig.childDown)}
              onMouseUp={() => runRowCommands(rowConfig.childUp)} onTouchEnd={() => runRowCommands(rowConfig.childUp)}>
              <TDS.ListRow.Texts type="2RowTypeA" top="토스뱅크" bottom="입출금 통장" />
            </div>} />
        </div>
        {parameters.get('async') === 'true' && <TDS.TextButton size="medium" data-case="async-event-trigger" onClick={async () => {
          const first = rowConfig.asyncBlinkFirst ? 'blink' : 'shine';
          const second = rowConfig.asyncBlinkFirst ? 'shine' : 'blink';
          effectRow.current[first](first === 'blink' ? .3 : 1);
          await Promise.resolve();
          effectRow.current[second](second === 'blink' ? .3 : 1);
        }}>비동기 실행</TDS.TextButton>}
      </TDS.ColorSchemeArea>}
      {family === 'wiki' && <TDS.Text typography="t5" as="div" style={{width:230}}>
        <TDS.WikiText description="이 단어의 자세한 설명을 확인해요.">
          {state === 'multiline' ? '여러 줄로 이어지는 아주 긴 금융 용어의 뜻을 확인해요' : '금융 용어'}
        </TDS.WikiText>
      </TDS.Text>}
      {family === 'slider-tooltip' && <div style={{paddingTop:100}}>
        <TDS.Slider defaultValue={25} tooltip={<TDS.SliderTooltip />} label={{min:'0',mid:'50',max:'100'}} />
      </div>}
      {family === 'sheet-select' && <div style={{margin:-24}}>
        <TDS.BottomSheet.Header>계좌를 선택해요</TDS.BottomSheet.Header>
        <TDS.BottomSheet.HeaderDescription>사용할 계좌를 선택해 주세요.</TDS.BottomSheet.HeaderDescription>
        <TDS.BottomSheet.Select value={tab === 0 ? 'a' : 'b'}
          animation={state !== 'static'} animationDelay={state === 'delayed' ? .5 : 0}
          onChange={e => { window.tdsReference.events.push([e.target.value,e.target.checked]); setTab(e.target.value === 'a' ? 0 : 1); }}
          options={[
            {name:'토스뱅크',value:'a'}, {name:'다른 계좌',value:'b'},
            {name:'사용할 수 없는 계좌',value:'c',disabled:true},
            {name:'체크 표시를 숨긴 계좌',value:'d',hideUnCheckedCheckBox:true},
          ]} />
      </div>}
      {family === 'sheet' && <TDS.BottomSheet open onClose={() => window.tdsReference.events.push('close')}
        header={<TDS.BottomSheet.Header>계좌를 선택해요</TDS.BottomSheet.Header>}
        headerDescription={<TDS.BottomSheet.HeaderDescription>사용할 계좌를 선택해 주세요.</TDS.BottomSheet.HeaderDescription>}
        cta={state !== 'no-cta' ? <TDS.BottomSheet.CTA background={state === 'none' ? 'none' : state === 'background' ? 'default' : undefined}>확인</TDS.BottomSheet.CTA> : undefined}>
        <TDS.BottomSheet.Select animation={false} value="a" onChange={() => {}}
          options={Array.from({length:state === 'long' ? 14 : 3},(_,i) => ({name:`계좌 ${i+1}`,value:i === 0 ? 'a' : `${i}`}))} />
      </TDS.BottomSheet>}
      {family === 'list-assets' && <>
        <TDS.ListHeader title={<TDS.ListHeader.TitleParagraph>내 계좌</TDS.ListHeader.TitleParagraph>}
          right={<TDS.ListHeader.RightIconButton name="icon-star-mono" aria-label="즐겨찾기" />} />
        {['squircle','card','original','circle-background','circle-masking'].map(shape =>
          <TDS.ListRow key={shape} left={<TDS.ListRow.AssetIcon name="icon-star-mono" shape={shape} color="#3182f6" paddingX />}
            contents={<TDS.ListRow.Texts type="2RowTypeA" top="토스뱅크" bottom="입출금 통장" />} />)}
        <TDS.ListRow left={<TDS.ListRow.AssetText acc={<span style={{display:'block',width:11,height:11,background:'#3182f6'}} />}>T</TDS.ListRow.AssetText>}
          contents={<TDS.ListRow.Texts type="1RowTypeA" top="보조 배지가 있는 계좌" />} />
        <TDS.ListRow left={<TDS.ListRow.FillIcon name="icon-star-mono" shape="circle-background" />}
          contents={<TDS.ListRow.Texts type="1RowTypeA" top="관심 계좌" />} />
      </>}
      {family === 'menus' && <>
        <TDS.Menu.Dropdown header="계좌 관리">
          <TDS.Menu.DropdownItem onClick={()=>{}}>내 계좌 확인</TDS.Menu.DropdownItem>
          <TDS.Menu.DropdownItem left={<TDS.Menu.DropdownIcon name="icn-delete"/>} onClick={()=>{}}>계좌 삭제</TDS.Menu.DropdownItem>
          <TDS.Menu.DropdownItem right={<TDS.Menu.DropdownIcon name="icon-arrow-right-mono"/>} onClick={()=>{}}>자세히 보기</TDS.Menu.DropdownItem>
        </TDS.Menu.Dropdown>
        <div style={{height:32}} />
        <TDS.Menu.Dropdown header="표시 설정">
          <TDS.Menu.DropdownCheckItem checked onCheckedChange={()=>{}}>선택한 계좌</TDS.Menu.DropdownCheckItem>
          <TDS.Menu.DropdownCheckItem checked={false} onCheckedChange={()=>{}}>모든 계좌</TDS.Menu.DropdownCheckItem>
        </TDS.Menu.Dropdown>
      </>}
      {family === 'menu-trigger' && <TDS.Menu.Trigger defaultOpen
        onOpen={() => window.tdsReference.events.push('open')}
        onClose={() => window.tdsReference.events.push('close')}
        dropdown={<TDS.Menu.Dropdown><TDS.Menu.DropdownItem onClick={() => window.tdsReference.events.push('item')}>내 계좌 확인</TDS.Menu.DropdownItem></TDS.Menu.Dropdown>}>
        <button>메뉴 열기</button>
      </TDS.Menu.Trigger>}
      {family === 'tooltips' && ['small','medium','large'].flatMap(size => ['top','bottom'].map(placement =>
        <div key={`${size}-${placement}`} style={{display:'flex',height:180}}>
          {['none','left','right'].map(clipToEnd => <div key={clipToEnd} style={{flex:1,display:'flex',alignItems:'center',justifyContent:'center'}}>
            <TDS.Tooltip open size={size} placement={placement} clipToEnd={clipToEnd}
              anchorPositionByRatio={clipToEnd === 'none' ? .5 : clipToEnd === 'left' ? 0 : 1} message="도움말">
              <div style={{width:80,height:20}} />
            </TDS.Tooltip>
          </div>)}
        </div>))}
      {family === 'paragraphs' && <>
        {[13,15,17].map(size => <div key={size} data-case={`subtitle-${size}`} style={{marginBottom:24}}><TDS.Top.SubtitleParagraph size={size}>
          {'내 자산 '}<TDS.Top.SubtitleParagraph.Icon name="icon-arrow-right-mono" />{' '}
          <TDS.Top.SubtitleParagraph.Badge color="blue" variant="weak">새 소식</TDS.Top.SubtitleParagraph.Badge>{' '}
          <TDS.Top.SubtitleParagraph.Link onClick={() => {}}>자세히 보기</TDS.Top.SubtitleParagraph.Link>
        </TDS.Top.SubtitleParagraph></div>)}
        {['xsmall','small','medium','large'].map(size => <div key={size} data-case={`badge-${size}`} style={{marginBottom:16}}>
          <TDS.Badge size={size} color="blue" variant="weak">배지 크기</TDS.Badge>
        </div>)}
        <TDS.Paragraph typography="t5">
          <TDS.Paragraph.Text>여러 줄에 걸쳐서 이어지는 문장과 <TDS.Paragraph.Text typography="t3" fontWeight="bold">조금 더 크게 강조하는 구간</TDS.Paragraph.Text></TDS.Paragraph.Text>
          <TDS.Paragraph.Text>도 같은 문단 안에서 자연스럽게 흘러가야 해요.</TDS.Paragraph.Text>
        </TDS.Paragraph>
      </>}
      {family === 'compounds' && <>
        <TDS.Top title={<TDS.Top.TitleParagraph>내 자산을 확인해요</TDS.Top.TitleParagraph>}
          subtitleTop={<TDS.Top.SubtitleParagraph size={13}>토스 디자인</TDS.Top.SubtitleParagraph>}
          subtitleBottom={<TDS.Top.SubtitleParagraph size={15}>모든 계좌를 한곳에서</TDS.Top.SubtitleParagraph>}
          right={<TDS.Top.RightArrow />}
          lower={<TDS.Top.LowerCTA type="2-button" leftButton={<TDS.Top.LowerCTAButton>확인</TDS.Top.LowerCTAButton>} rightButton={<TDS.Top.LowerCTAButton color="dark" variant="weak">나중에</TDS.Top.LowerCTAButton>} />} />
        <div style={{height:16}} />
        <div style={{display:'flex',justifyContent:'flex-start'}}><TDS.Bubble background="grey">궁금한 점을 물어보세요</TDS.Bubble></div>
        <div style={{height:16}} />
        <div style={{display:'flex',justifyContent:'flex-end'}}><TDS.Bubble background="blue">내 자산을 확인하고 싶어요</TDS.Bubble></div>
        <div style={{height:16}} />
        <TDS.ListRow left={<TDS.ListRow.LeftText type="border">1</TDS.ListRow.LeftText>} contents={<TDS.ListRow.Text>첫 번째 계좌</TDS.ListRow.Text>} />
        <TDS.ListRow left={<TDS.ListRow.LeftText type="border">2</TDS.ListRow.LeftText>} contents={<TDS.ListRow.Text>두 번째 계좌</TDS.ListRow.Text>} />
        <div style={{height:16}} />
        <TDS.Paragraph.Link typography="t6" onClick={() => {}}>이용 약관 보기</TDS.Paragraph.Link>
      </>}
      {family === 'bottom-cta' && <div style={{margin:-24}}>
        <TDS.BottomCTA.Single disabled={state === 'disabled'} topAccessory="안전하게 보관해요" bottomAccessory="언제든 변경할 수 있어요">확인</TDS.BottomCTA.Single>
        <div style={{height:16}} />
        <TDS.BottomCTA.Double background="none" leftButton={<TDS.Button color="dark" variant="weak">나중에</TDS.Button>}
          rightButton={<TDS.Button>확인하기</TDS.Button>} />
        <div style={{height:16}} />
        <TDS.BottomCTA.Double leftButton={<TDS.Button color="dark" variant="weak">다음에 다시 확인할게요</TDS.Button>}
          rightButton={<TDS.Button>지금 바로 확인할게요</TDS.Button>} />
        <TDS.BottomCTA.Double background="none" leftButton={null} rightButton={null} bottomAccessory="버튼 없이 안내만 표시해요" />
      </div>}
      {family === 'keypad' && <div style={{margin:-24}}><TDS.NumberKeypad onKeyClick={() => {}} onBackspaceClick={() => {}} /></div>}
      {family === 'secure-keypad' && <div style={{margin:-24}}><TDS.FullSecureKeypad onKeyClick={() => {}} onBackspaceClick={() => {}} onSpaceClick={() => {}} onSubmit={() => {}} submitDisabled={state === 'disabled'} /></div>}
      {family === 'extended-controls' && <>
        {['tiny','small','medium','large'].map(size => <div key={size} style={{marginBottom:24}}><TDS.NumericSpinner size={size} defaultNumber={5}/></div>)}
        {['small','large'].map(size => <div key={size} style={{marginBottom:24}}><TDS.SegmentedControl size={size} defaultValue="a">
          <TDS.SegmentedControl.Item value="a">전체</TDS.SegmentedControl.Item><TDS.SegmentedControl.Item value="b">진행 중</TDS.SegmentedControl.Item><TDS.SegmentedControl.Item value="c">완료</TDS.SegmentedControl.Item>
        </TDS.SegmentedControl></div>)}
        {['small','large'].map(size => <div key={size} style={{marginBottom:24}}><TDS.Tab size={size} onChange={setTab}>
          {['전체','진행 중','완료'].map((text,i) => <TDS.Tab.Item key={text} selected={tab===i}>{text}</TDS.Tab.Item>)}
        </TDS.Tab></div>)}
        {['light','normal','bold'].map(size => <div key={size} style={{marginBottom:24}}><TDS.ProgressBar size={size} progress={.4}/></div>)}
      </>}
    </div></TDS.ColorSchemeArea>
  </TDSMobileProvider></TDSMobileAITProvider>;
}
createRoot(document.getElementById('root')).render(<Fixture />);
