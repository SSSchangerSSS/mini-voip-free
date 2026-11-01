import subprocess,time,pathlib,json,xml.etree.ElementTree as E
adb='/home/changer/.local/share/mini-voip-free/android-sdk/platform-tools/adb';dev='127.0.0.1:5565';base=pathlib.Path('qa/reports/2026-10-31-manual-rc')
def run(*a,timeout=20):
 r=subprocess.run([adb,'-s',dev,*a],capture_output=True,timeout=timeout);assert r.returncode==0;return r
r={'status':'FAIL','cycles':[],'anrDialogsDismissed':False}
for i in range(3):
 start=time.monotonic();run('shell','input','keyevent','3');time.sleep(.5)
 run('shell','am','start','-W','-n','app.minivoipfree/.MainActivity');run('shell','uiautomator','dump','/data/local/tmp/qa-interaction.xml')
 tree=E.fromstring(run('shell','cat','/data/local/tmp/qa-interaction.xml').stdout)
 ready=any('آماده' in n.get('content-desc','')+n.get('text','') for n in tree.iter('node'))
 assert ready,'App did not return to Ready after Home'
 run('shell','cmd','statusbar','expand-notifications');time.sleep(.5);run('shell','cmd','statusbar','collapse');time.sleep(.5)
 run('shell','uiautomator','dump','/data/local/tmp/qa-interaction.xml')
 final_tree=E.fromstring(run('shell','cat','/data/local/tmp/qa-interaction.xml').stdout)
 assert any('آماده' in n.get('content-desc','')+n.get('text','') for n in final_tree.iter('node')), 'Notification shade did not return to app'
 r['cycles'].append({'homeReturnReady':ready,'notificationsOpenedAndBack':True,'procedureSeconds':round(time.monotonic()-start,2)})
(base/'ui-after-cycles.png').write_bytes(run('exec-out','screencap','-p').stdout)
events=run('logcat','-d','-b','events').stdout.decode(errors='replace');errors=[x for x in events.splitlines() if ' am_anr ' in x or ' am_crash ' in x]
(base/'ui-cycle-anr-crash.txt').write_text('\n'.join(errors));r['anrOrCrashEvents']=len(errors);r['status']='PASS' if not errors else 'FAIL'
(base/'ui-cycles-result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
assert not errors
