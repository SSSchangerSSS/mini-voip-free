import subprocess,pathlib,json,time,xml.etree.ElementTree as E,re
adb='/home/changer/.local/share/mini-voip-free/android-sdk/platform-tools/adb'; dev='emulator-5554'; base=pathlib.Path('qa/reports/2026-10-31-manual-rc/final')
def run(*args):
 r=subprocess.run([adb,'-s',dev,*args],capture_output=True,timeout=45)
 if r.returncode: raise RuntimeError('ADB command failed: '+args[0])
 return r.stdout

def tree():
 run('shell','uiautomator','dump','/data/local/tmp/manual-smoke.xml')
 return E.fromstring(run('shell','cat','/data/local/tmp/manual-smoke.xml'))
def ready():
 for _ in range(6):
  t=tree()
  if any(n.get('content-desc')=='آماده' for n in t.iter('node')):return t
  time.sleep(2)
 raise RuntimeError('Ready screen missing')
def snap(name): (base/(name+'.png')).write_bytes(run('exec-out','screencap','-p'))
result={'status':'FAIL','device':dev,'version':'0.1.1+4','passwordEntered':False,'dataWiped':False,'coldAppRestores':[]}
for i in range(1):
 start=time.monotonic(); run('shell','am','force-stop','app.minivoipfree');run('shell','am','start','-W','-n','app.minivoipfree/.MainActivity');ready()
 result['coldAppRestores'].append({'status':'PASS','seconds':round(time.monotonic()-start,2)})
snap('android8-upgrade-ready')
for target in ['101','199']:
 t=ready();f=next(n for n in t.iter('node') if n.get('class')=='android.widget.EditText')
 x,y,x2,y2=map(int,re.findall(r'\d+',f.get('bounds')))
 run('shell','input','tap',str((x+x2)//2),str((y+y2)//2));run('shell','input','keyevent','123')
 for _ in range(3):run('shell','input','keyevent','67')
 run('shell','input','text',target);run('shell','input','keyevent','4')
 t=tree();b=next(n for n in t.iter('node') if n.get('content-desc')=='تماس');x,y,x2,y2=map(int,re.findall(r'\d+',b.get('bounds')));run('shell','input','tap',str((x+x2)//2),str((y+y2)//2));time.sleep(3);ready();snap('android8-rejected-'+target)
 result['selfCallReturnsIdle' if target=='101' else 'unknownCallReturnsIdle']=True
# Leave an empty destination field for the human tester.
t=ready();f=next(n for n in t.iter('node') if n.get('class')=='android.widget.EditText');x,y,x2,y2=map(int,re.findall(r'\d+',f.get('bounds')));run('shell','input','tap',str((x+x2)//2),str((y+y2)//2));run('shell','input','keyevent','123')
for _ in range(3):run('shell','input','keyevent','67')
run('shell','input','keyevent','4');snap('android8-final')
events=run('logcat','-d','-b','events').decode(errors='replace');errors=[l for l in events.splitlines() if ' am_anr ' in l or ' am_crash ' in l];(base/'android8-anr-crash.txt').write_text('\n'.join(errors));result['anrOrCrashEvents']=len(errors)
result['status']='PASS' if not errors else 'FAIL';(base/'android8-smoke.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
assert result['status']=='PASS'
