import pathlib,sys,datetime
exec((pathlib.Path(__file__).parent/'call_helpers.py').read_text())
base=pathlib.Path('qa/reports/2026-10-31-manual-rc');stage=sys.argv[1];direction=sys.argv[2] if len(sys.argv)>2 else 'to8';tag=sys.argv[3] if len(sys.argv)>3 else 'call-'+direction
caller,callee,target=('127.0.0.1:5565','emulator-5554','101') if direction=='to8' else ('emulator-5554','127.0.0.1:5565','103')
statefile=base/f'{tag}-stages.json';state=json.loads(statefile.read_text()) if statefile.exists() else {}
def save(value):
 value['observedAtUtc']=datetime.datetime.now(datetime.timezone.utc).isoformat();state[stage]=value;statefile.write_text(json.dumps(state,indent=2)+'\n');print(json.dumps(value),flush=True)
def rows(text):return [l.split() for l in text.splitlines() if re.match(r'\s*[0-9a-f]{8}\s+10[13]-',l)]
def snap(dev,name):
 r=run(dev,'exec-out','screencap','-p');assert r.returncode==0 and r.stdout.startswith(b'\x89PNG');(base/f'{tag}-{name}.png').write_bytes(r.stdout)
if stage=='start':
 root,_=tree(caller);field=next(n for n in root.iter('node') if n.get('class')=='android.widget.EditText');click(caller,field)
 run(caller,'shell','input','keyevent','123')
 for _ in range(3):run(caller,'shell','input','keyevent','67')
 run(caller,'shell','input','text',target);run(caller,'shell','input','keyevent','4');root,_=tree(caller)
 click(caller,next(n for n in root.iter('node') if n.get('content-desc')=='تماس'))
 answered=False
 for _ in range(4):
  root,_=tree(callee);button=next((n for n in root.iter('node') if n.get('content-desc')=='پاسخ'),None)
  if button is not None:click(callee,button);answered=True;break
  time.sleep(1)
 assert answered,'Incoming answer button not seen'
 connected=False
 for _ in range(25):
  media=rows(pbx('pjsip show channelstats','media-initial'))
  if len(media)==2 and media[0][0]==media[1][0] and all(int(r[4])>0 and int(r[8])>0 for r in media):connected=True;break
  time.sleep(1)
 snap(caller,'caller-connected');snap(callee,'callee-connected')
 save({'status':'PASS' if connected else 'FAIL','answered':answered,'sharedBridgeAndBidirectionalRtp':connected,'caller':caller,'callee':callee,'rtpCounts':[{'rx':int(r[4]),'tx':int(r[8])} for r in media],'acousticAudio':'NOT_RUN'})
 if not connected:raise SystemExit(1)
elif stage=='mute':
 # Connected caller screenshot must be reviewed separately before these taps.
 run(caller,'shell','input','tap','377','553');snap(caller,'muted');save({'status':'PASS','requestedAtEpoch':time.time(),'scope':'Mute UI and call stability; acoustic effect NOT_RUN'})
elif stage=='controls':
 elapsed=time.time()-state['mute']['requestedAtEpoch'];assert elapsed>=60
 media=rows(pbx('pjsip show channelstats','after-mute'))
 assert len(media)==2 and media[0][0]==media[1][0],'Call lost shared bridge during mute'
 run(caller,'shell','input','tap','377','553');run(caller,'shell','input','tap','103','553');snap(caller,'speaker-on')
 run(caller,'shell','input','tap','103','553');snap(caller,'controls-restored')
 save({'status':'PASS','muteIntervalSeconds':round(elapsed,2),'sharedBridgeMaintained':True,'scope':'UI mute/unmute/speaker controls; physical audio routing NOT_RUN'})
elif stage=='end':
 run(caller,'shell','input','tap','240','553');cleared=False
 for _ in range(10):
  if '0 active channels' in pbx('core show channels','after-hangup'):cleared=True;break
  time.sleep(1)
 time.sleep(2);snap(caller,'caller-idle');snap(callee,'callee-idle')
 save({'status':'PASS' if cleared else 'FAIL','channelsCleared':cleared})
 if not cleared:raise SystemExit(1)
