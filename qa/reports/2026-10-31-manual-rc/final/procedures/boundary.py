import pathlib,sys,datetime
exec((pathlib.Path('qa/reports/2026-10-31-manual-rc/procedures')/'call_helpers.py').read_text())
base=pathlib.Path('qa/reports/2026-10-31-manual-rc/final')
mode=sys.argv[2];caller,callee='emulator-5554','127.0.0.1:5565'
root,_=tree(caller);field=next(n for n in root.iter('node') if n.get('class')=='android.widget.EditText');click(caller,field);run(caller,'shell','input','text','103');run(caller,'shell','input','keyevent','4');root,_=tree(caller);start=time.time();utc_start=datetime.datetime.now(datetime.timezone.utc);click(caller,next(n for n in root.iter('node') if n.get('content-desc')=='تماس'))
result={'mode':mode,'status':'FAIL','incomingSeen':False,'secretValuesRecorded':False}
for _ in range(4):
 root,_=tree(callee)
 decline=next((n for n in root.iter('node') if n.get('content-desc')=='رد تماس'),None)
 if decline is not None:
  result['incomingSeen']=True
  if mode=='decline':click(callee,decline)
  elif mode=='cancel':
   croot,_=tree(caller);click(caller,next(n for n in croot.iter('node') if n.get('content-desc')=='قطع تماس'))
  break
 if time.time()-start>40:break
if mode=='timeout':
 for _ in range(55):
  state=pbx('core show channels','timeout-monitor')
  if '0 active channels' in state:
   utc_end=datetime.datetime.now(datetime.timezone.utc);break
  time.sleep(1)
 else:utc_end=datetime.datetime.now(datetime.timezone.utc)
 logs=subprocess.run(['sg','docker','-c',f"docker logs --since {utc_start.isoformat()} smi-control 2>&1"],capture_output=True,text=True).stdout
 admitted=next((line.split()[0] for line in logs.splitlines() if ' admitted, push=' in line),None)
 if admitted:
  result['serverAdmissionUtc']=admitted;result['channelsGoneUtc']=utc_end.isoformat();result['serverPendingLifetimeSeconds']=round((utc_end-datetime.datetime.fromisoformat(admitted.replace('Z','+00:00'))).total_seconds(),2)
  result['deadlineWithinBounds']=38<=result['serverPendingLifetimeSeconds']<=42
else:time.sleep(3)
after=pbx('core show channels','after-action');result['channelsCleared']='0 active channels' in after
c1=capture(caller,'caller');c2=capture(callee,'callee')
result['callerIdle']=any(n.get('content-desc')=='تماس' for n in c1.iter('node'));result['calleeIdle']=any(n.get('content-desc')=='تماس' for n in c2.iter('node'))
result['elapsedSeconds']=round(time.time()-start,2);result['status']='PASS' if result['incomingSeen'] and result['channelsCleared'] and result['callerIdle'] and result['calleeIdle'] and (mode!='timeout' or result.get('deadlineWithinBounds',False)) else 'FAIL'
(base/f'{tag}-result.json').write_text(json.dumps(result,indent=2));print(json.dumps(result),flush=True)
