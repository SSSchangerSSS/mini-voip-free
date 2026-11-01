import pathlib,subprocess,time,json
adb='/home/changer/.local/share/mini-voip-free/android-sdk/platform-tools/adb';dev='127.0.0.1:5565';base=pathlib.Path('qa/reports/2026-10-31-manual-rc')
def run(*a):return subprocess.check_output([adb,'-s',dev,*a],timeout=20)
def snap(name):
 time.sleep(1.5);(base/('controls-'+name+'.png')).write_bytes(run('exec-out','screencap','-p'))
snap('baseline')
for name,x in [('muted',377),('unmuted',377),('speaker-on',103),('speaker-off',103)]:
 run('shell','input','tap',str(x),'553');snap(name)
(base/'controls-observed.json').write_text(json.dumps({'status':'NOT_RUN','tapsSent':True,'frameSettleSeconds':1.5,'visualReviewRequired':True,'acousticAudio':'NOT_RUN'},indent=2)+'\n')
