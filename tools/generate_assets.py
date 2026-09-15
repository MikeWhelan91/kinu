from pathlib import Path
import wave, math, struct, random
root=Path(__file__).resolve().parents[1]
rate=22050
random.seed(72)
def write(name, samples, loop=False):
 with wave.open(str(root/'assets/audio'/f'{name}.wav'),'w') as w:
  w.setparams((1,2,rate,0,'NONE','not compressed'))
  w.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,s)) * 32767)) for s in samples))
def notes(seq,dur=.14,vol=.4):
 out=[0.] * int((len(seq)*dur+.7)*rate)
 for k,f in enumerate(seq):
  for j in range(int(.6*rate)):
   t=j/rate
   env=(1-math.exp(-t*110))*math.exp(-t*9)
   v=(math.sin(2*math.pi*f*t)+.22*math.sin(2*math.pi*f*2*t))*env*vol
   out[int(k*dur*rate)+j]+=v
 return out
for name,seq in {'tap':[780],'rotate':[440,554],'drop':[620,310],'land':[220],'heavy':[130,165],'combo':[523,659,784,1046],'escape':[392,330,262],'over':[440,349,294,220],'record':[523,659,784,1046,1318],'nudge':[330,440,554]}.items():
 write(name,notes(seq, .11 if name!='over' else .2))
# Original 32-second seamless pentatonic garden music, deliberately sparse.
length=32
out=[0.]*(rate*length)
melody=[72,76,79,81,79,76,74,67,69,72,76,74,72,69,67,64]
for k in range(64):
 midi=melody[k%16] if k%2==0 else [48,55,57,52][(k//8)%4]
 f=440*2**((midi-69)/12)
 for j in range(int(rate*2.8)):
  t=j/rate
  env=(1-math.exp(-35*t))*math.exp(-2.8*t)
  v=.14*env*(math.sin(2*math.pi*f*t)+.18*math.sin(2*math.pi*f*2*t))
  out[(int(k*.5*rate)+j)%len(out)]+=v
write('garden',out)
# Encoding is an offline authoring step; FFmpeg is not a game dependency.
import subprocess
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(root/'assets/audio/garden.wav'),'-c:a','vorbis','-strict','-2','-ac','2',str(root/'assets/audio/garden.ogg')],check=True)
