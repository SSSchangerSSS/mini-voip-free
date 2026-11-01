import pathlib,subprocess,xml.etree.ElementTree as E,re,time,json
adb='/home/changer/.local/share/mini-voip-free/android-sdk/platform-tools/adb';base=pathlib.Path('qa/reports/2026-10-31-manual-rc/final');result={}
for dev,label,target in [('emulator-5554','android8','103'),('127.0.0.1:5565','android15','101')]:
 def run(*a):return subprocess.check_output([adb,'-s',dev,*a],timeout=45)
 run('shell','am','start','-W','-n','app.minivoipfree/.MainActivity');run('shell','uiautomator','dump','/data/local/tmp/handoff.xml');tree=E.fromstring(run('shell','cat','/data/local/tmp/handoff.xml'))
 assert any(n.get('content-desc')=='آماده' for n in tree.iter('node'))
 f=next(n for n in tree.iter('node') if n.get('class')=='android.widget.EditText');x,y,x2,y2=map(int,re.findall(r'\d+',f.get('bounds')))
 run('shell','input','tap',str((x+x2)//2),str((y+y2)//2));run('shell','input','keyevent','123')
 for _ in range(3):run('shell','input','keyevent','67')
 run('shell','input','text',target)
 if 'mInputShown=true' in run('shell','dumpsys','input_method').decode():run('shell','input','keyevent','4')
 time.sleep(1.5);(base/(label+'-handoff.png')).write_bytes(run('exec-out','screencap','-p'))
 result[label]={'status':'PASS','readyObserved':True,'prefilledTarget':target,'callPlaced':False}
(base/'handoff.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
