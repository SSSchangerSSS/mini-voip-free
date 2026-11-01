import subprocess,pathlib,json,hashlib,datetime,re
b=pathlib.Path('qa/reports/2026-10-31-manual-rc/final');adb='/home/changer/.local/share/mini-voip-free/android-sdk/platform-tools/adb';expected='3b51431c961e234d3f1b5be1545bfaebe6af461aa3ec18835c2a9950194e10f1';health={};identity={'status':'PASS','expectedSha256':expected,'devices':{}}
assert len(json.loads((b/'steps.json').read_text()))==14
for dev,label in [('emulator-5554','android8'),('127.0.0.1:5565','android15')]:
 def run(*a):return subprocess.check_output([adb,'-s',dev,*a],timeout=45)
 path=run('shell','pm','path','app.minivoipfree').decode().strip().removeprefix('package:')
 digest=run('shell','sha256sum',path).decode().split()[0];assert digest==expected
 version=run('shell','dumpsys','package','app.minivoipfree').decode();assert 'versionCode=4' in version
 identity['devices'][dev]={'sha256':digest,'versionCode':4,'matches':True}
 events=run('logcat','-d','-b','events').decode(errors='replace');errors=[l for l in events.splitlines() if ' am_anr ' in l or ' am_crash ' in l];crash=run('logcat','-d','-b','crash').decode(errors='replace')
 (b/(label+'-final-events.txt')).write_text('\n'.join(errors));(b/(label+'-final-crash.txt')).write_text(crash)
 health[label]={'status':'PASS' if not errors and not crash.strip() else 'FAIL','anrOrCrashEvents':len(errors),'crashBufferEmpty':not crash.strip()}
 (b/(label+'-handoff.png')).write_bytes(run('exec-out','screencap','-p'))
health['observedAtUtc']=datetime.datetime.now(datetime.timezone.utc).isoformat();(b/'final-runtime-health.json').write_text(json.dumps(health,indent=2)+'\n');(b/'installed-apk-identity.json').write_text(json.dumps(identity,indent=2)+'\n')
for name,cmd in [('final-channels.txt','core show channels'),('final-contacts.txt','pjsip show contacts')]:
 data=subprocess.check_output(['sg','docker','-c',f'docker exec smi-pbx asterisk -rx "{cmd}"'],text=True);(b/name).write_text(data)
 if name=='final-channels.txt':assert '0 active channels' in data
 else:assert '101/sip:' in data and '103/sip:' in data
ready=subprocess.check_output(['curl','--silent','--show-error','--cacert','qa/reports/2026-10-28-local/lan-root-ca.crt','https://192.168.1.151/health/ready']);assert json.loads(ready)=={'db':'ok','ami':'ok'};(b/'final-server-ready.json').write_bytes(ready)
assert all(health[x]['status']=='PASS' for x in ['android8','android15']);print(json.dumps({'runtime':health,'identity':identity}),flush=True)
