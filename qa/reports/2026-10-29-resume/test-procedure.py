import pathlib,sys,datetime
import subprocess,pathlib,xml.etree.ElementTree as E,re,time,json,sys
adb='/home/changer/.local/share/mini-voip-free/android-sdk/platform-tools/adb'
base=pathlib.Path('qa/reports/2026-10-28-call'); tag=sys.argv[1] if len(sys.argv)>1 else 'first-call'
def run(dev,*a,timeout=45):return subprocess.run([adb,'-s',dev,*a],capture_output=True,timeout=timeout)
def tree(dev):
 r=run(dev,'shell','uiautomator','dump','/data/local/tmp/calltest-ui.xml')
 if r.returncode: raise RuntimeError(r.stderr.decode())
 raw=run(dev,'shell','cat','/data/local/tmp/calltest-ui.xml').stdout
 return E.fromstring(raw),raw
def click(dev,n):
 x,y,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')));run(dev,'shell','input','tap',str((x+x2)//2),str((y+y2)//2))
def pbx(cmd,name):
 r=subprocess.run(['sg','docker','-c',f'docker exec smi-pbx asterisk -rx "{cmd}"'],capture_output=True)
 (base/f'{tag}-{name}.txt').write_bytes(r.stdout+r.stderr)
 return r.stdout.decode()
def capture(dev,suffix):
 root,raw=tree(dev)
 for n in root.iter('node'):
  if n.get('password')=='true': n.set('text','[REDACTED]')
 (base/f'{tag}-{suffix}.xml').write_bytes(E.tostring(root,encoding='utf-8'))
 (base/f'{tag}-{suffix}.png').write_bytes(run(dev,'exec-out','screencap','-p').stdout)
 return root

base=pathlib.Path('qa/reports/2026-10-29-resume');tag='post-reboot-controls';stage=sys.argv[1];caller='emulator-5554';callee='emulator-5556';statefile=base/'control-stages.json';state=json.loads(statefile.read_text()) if statefile.exists() else {}
def save(value):
 value['observedAtUtc']=datetime.datetime.now(datetime.timezone.utc).isoformat();state[stage]=value;statefile.write_text(json.dumps(state,indent=2));print(json.dumps(value),flush=True)
def stats_rows(s):return [l.split() for l in s.splitlines() if re.match(r'\s*[0-9a-f]{8}\s+10[12]-',l)]
def snap(dev,name):
 r=run(dev,'exec-out','screencap','-p');assert r.returncode==0 and r.stdout.startswith(b'\x89PNG');(base/f'{tag}-{name}.png').write_bytes(r.stdout)
if stage=='start':
 root,_=tree(caller);field=next(n for n in root.iter('node') if n.get('class')=='android.widget.EditText');click(caller,field)
 run(caller,'shell','input','keyevent','123')
 for _ in range(3):run(caller,'shell','input','keyevent','67')
 run(caller,'shell','input','text','102');run(caller,'shell','input','keyevent','4');root,_=tree(caller)
 click(caller,next(n for n in root.iter('node') if n.get('content-desc')=='تماس'))
 seen=False
 for _ in range(4):
  root,_=tree(callee);button=next((n for n in root.iter('node') if n.get('content-desc')=='پاسخ'),None)
  if button is not None:click(callee,button);seen=True;break
  time.sleep(1)
 assert seen,'No incoming answer button'
 connected=False
 for _ in range(22):
  rows=stats_rows(pbx('pjsip show channelstats','start-media'))
  if len(rows)==2 and rows[0][0]==rows[1][0] and all(int(r[4])>0 and int(r[8])>0 for r in rows):connected=True;break
  time.sleep(1)
 save({'status':'PASS' if connected else 'FAIL','answerButtonTapped':seen,'sharedBridgeAndBidirectionalRtp':connected,'scope':'Emulator call signaling and RTP transport; acoustic audio NOT_RUN'})
 if not connected:raise SystemExit(1)
elif stage=='mute':
 # Centres visually reviewed in the fresh 480x800 before-mute screenshot.
 # Live timer prevents UiAutomator's idle wait; do not guess a hierarchy.
 buttons={'میوت':{'bounds':'[376,552][378,554]'},'بلندگو':{'bounds':'[102,552][104,554]'},'قطع تماس':{'bounds':'[239,552][241,554]'}}
 state['buttons']=buttons;state['geometrySource']='post-reboot-controls-before-mute.png (visually reviewed)'
 click(caller,E.Element('node',buttons['میوت']));snap(caller,'muted')
 save({'status':'PASS','muteRequestedAtEpoch':time.time(),'scope':'Visually grounded mute tap; screenshot retained, audible effect NOT_RUN'})
elif stage=='controls':
 elapsed=time.time()-state['mute']['muteRequestedAtEpoch'];assert elapsed>=60,f'Mute interval only {elapsed:.1f}s'
 channels=pbx('core show channels verbose','after-mute');up=channels.count(' Up ')>=2
 assert up,'Call did not stay connected while muted'
 click(caller,E.Element('node',state['buttons']['میوت']));click(caller,E.Element('node',state['buttons']['بلندگو']));snap(caller,'speaker-on')
 click(caller,E.Element('node',state['buttons']['بلندگو']));snap(caller,'controls-restored')
 rows=stats_rows(pbx('pjsip show channelstats','controls-media'))
 save({'status':'PASS','muteIntervalSeconds':round(elapsed,2),'bothLegsStillUp':up,'rtpRows':len(rows),'scope':'60s+ mute stability, unmute and speaker UI controls; physical audio routing NOT_RUN'})
elif stage=='end':
 click(caller,E.Element('node',state['buttons']['قطع تماس']))
 cleared=False
 for _ in range(10):
  if '0 active channels' in pbx('core show channels','after-hangup'):cleared=True;break
  time.sleep(1)
 time.sleep(2);snap(caller,'caller-idle');snap(callee,'callee-idle')
 save({'status':'PASS' if cleared else 'FAIL','channelsCleared':cleared,'scope':'Caller hangup; UI screenshots retained'})
 if not cleared:raise SystemExit(1)
else:raise SystemExit('Unknown stage')
