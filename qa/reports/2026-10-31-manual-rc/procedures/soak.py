import pathlib,subprocess,time,json,re
base=pathlib.Path('qa/reports/2026-10-31-manual-rc');start=time.monotonic();samples=[];controls=False
for i in range(15):
 r=subprocess.run(['sg','docker','-c','docker exec smi-pbx asterisk -rx "pjsip show channelstats"'],capture_output=True,text=True,check=True)
 (base/f'soak-media-{i:02d}.txt').write_text(r.stdout)
 rows=[l.split() for l in r.stdout.splitlines() if re.match(r'\s*[0-9a-f]{8}\s+10[13]-',l)]
 good=len(rows)==2 and rows[0][0]==rows[1][0] and all(int(x[4])>0 and int(x[8])>0 for x in rows)
 sample={'seconds':round(time.monotonic()-start,2),'sharedBridgeAndRtp':good,'counts':[{'rx':int(x[4]),'tx':int(x[8])} for x in rows]};samples.append(sample)
 (base/'soak-progress.json').write_text(json.dumps({'status':'NOT_RUN','samples':samples},indent=2)+'\n')
 assert good,'Lost call bridge/media during soak'
 if sample['seconds']>=70 and not controls:
  subprocess.run(['python3','qa/reports/2026-10-31-manual-rc/procedures/call.py','controls','to8'],check=True);controls=True
 if i<14:time.sleep(10)
result={'status':'PASS','samples':samples,'observedSeconds':samples[-1]['seconds'],'controlsExercised':controls,'acousticAudio':'NOT_RUN'}
(base/'soak-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
subprocess.run(['python3','qa/reports/2026-10-31-manual-rc/procedures/call.py','end','to8'],check=True)
