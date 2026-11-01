import subprocess,pathlib,json,datetime
base=pathlib.Path('qa/reports/2026-10-31-manual-rc/final');runner=pathlib.Path('qa/reports/2026-10-31-manual-rc/final/procedures');results=[]
steps=[('android8-smoke',['android8-smoke.py']),('android15-ui',['interaction.py']),('to8-start',['call.py','start','to8']),('to8-mute',['call.py','mute','to8']),('soak',['soak.py']),('to15-start',['call.py','start','to15']),('to15-end',['call.py','end','to15']),('decline',['boundary.py','decline','decline']),('cancel',['boundary.py','cancel','cancel']),('timeout',['boundary.py','timeout','timeout']),('cold1',['reboot-probe.py','cold1']),('cold2',['reboot-probe.py','cold2']),('postcold-start',['call.py','start','postcold']),('postcold-end',['call.py','end','postcold'])]
for name,args in steps:
 start=datetime.datetime.now(datetime.timezone.utc).isoformat()
 with (base/(name+'.log')).open('wb') as log:
  r=subprocess.run(['python3',str(runner/args[0]),*args[1:]],stdout=log,stderr=subprocess.STDOUT)
 result={'step':name,'status':'PASS' if r.returncode==0 else 'FAIL','exitCode':r.returncode,'startedAtUtc':start,'finishedAtUtc':datetime.datetime.now(datetime.timezone.utc).isoformat()};results.append(result)
 (base/'steps.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(result),flush=True)
 if r.returncode:raise SystemExit(r.returncode)
