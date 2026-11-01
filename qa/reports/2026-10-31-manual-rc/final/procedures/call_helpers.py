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
