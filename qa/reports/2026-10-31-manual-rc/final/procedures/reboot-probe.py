import subprocess,time,pathlib,json,sys,re,datetime
base=pathlib.Path('qa/reports/2026-10-31-manual-rc/final');tag=sys.argv[1];adb='/home/changer/.local/share/mini-voip-free/android-sdk/platform-tools/adb';device='127.0.0.1:5565'
def docker(cmd):return subprocess.run(['sg','docker','-c',cmd],capture_output=True,text=True,timeout=40)
def run(*args,timeout=15):return subprocess.run([adb,'-s',device,*args],capture_output=True,timeout=timeout)
channels=docker('docker exec smi-pbx asterisk -rx "core show channels"');assert '0 active channels' in channels.stdout,'Active call: do not reboot'
old_contacts=docker('docker exec smi-pbx asterisk -rx \"pjsip show contacts\"').stdout
old_match=re.search(r'Contact:\s+103/sip:([^@]+)@',old_contacts);old_contact=old_match.group(1) if old_match else None
start=time.monotonic();r=docker('docker stop -t 15 smi-qa-android15');assert r.returncode==0
run('disconnect',device)
start=time.monotonic();start_command='docker compose -f qa/redroid-compose.yaml up -d --force-recreate android15' if tag=='cold3' else 'docker start smi-qa-android15'
r=docker(start_command);assert r.returncode==0
ready=False;stable=None;count=0
for _ in range(90):
 subprocess.run([adb,'connect',device],capture_output=True,timeout=6)
 try:
  pid=run('shell','pidof','system_server').stdout.strip()
  if pid and run('shell','getprop','sys.boot_completed').stdout.strip()==b'1' and b'RUNNING_UNLOCKED' in run('shell','am','get-started-user-state','0').stdout and b'package:' in run('shell','pm','path','android').stdout:
   count=count+1 if pid==stable else 1;stable=pid
   if count>=3:ready=True;break
  else:count=0
 except subprocess.TimeoutExpired:pass
 time.sleep(1)
assert ready,'Stable framework readiness failed'
result={'status':'FAIL','bootReadySeconds':round(time.monotonic()-start,2),'credentialsEntered':False,'dataWiped':False,'anrDismissed':False}
assert run('shell','getprop','ro.build.version.sdk').stdout.strip()==b'35'
launch=run('shell','am','start','-n','app.minivoipfree/.MainActivity');assert launch.returncode==0
for _ in range(60):
 p=docker('docker exec smi-pbx asterisk -rx "pjsip show contacts"')
 new_match=re.search(r'Contact:\s+103/sip:([^@]+)@',p.stdout)
 if new_match and new_match.group(1)!=old_contact:result['freshSipContact']=True;break
 time.sleep(1)
else:raise RuntimeError('Stored account did not restore/register')
result['registeredSecondsFromStart']=round(time.monotonic()-start,2);(base/f'{tag}-contacts.txt').write_text(p.stdout)
time.sleep(2);(base/f'{tag}-app.png').write_bytes(run('exec-out','screencap','-p',timeout=35).stdout)
events=run('logcat','-d','-b','events',timeout=35).stdout.decode(errors='replace');errors=[l for l in events.splitlines() if ' am_anr ' in l or ' am_crash ' in l]
crash=run('logcat','-d','-b','crash').stdout.decode(errors='replace');(base/f'{tag}-anr-events.txt').write_text('\n'.join(errors));(base/f'{tag}-crash.txt').write_text(crash)
result['anrOrCrashEvents']=len(errors);result['crashBufferEmpty']=not crash.strip();result['status']='PASS' if not errors and not crash.strip() else 'FAIL';result['screenReviewRequired']=True
result['pidsEvents']=run('shell','cat','/sys/fs/cgroup/pids.events').stdout.decode().strip()
(base/f'{tag}-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
assert result['status']=='PASS'
