#!/usr/bin/env python3
"""Interface Ports v5.0.1: navigation TTY, esthétique, lancement xterm."""
import os, sys, re, select, signal, termios, time, unicodedata, tty
from collections import deque

ESC='\x1b'
RESET=ESC+'[0m'
OFF=ESC+'[?1000l'+ESC+'[?1002l'+ESC+'[?1003l'+ESC+'[?1006l'
MOUSE=ESC+'[?1006h'+ESC+'[?1003h'
COLORS=not bool(os.environ.get('NO_COLOR'))

def safe(s):
    return ''.join(c if not unicodedata.category(c).startswith('C') else ' ' for c in s)

def cell(c):
    return 0 if unicodedata.combining(c) else 2 if unicodedata.east_asian_width(c) in 'WF' else 1

def width(s): return sum(map(cell,s))

def fit(s,n):
    s=safe(s); n=max(0,n)
    if width(s)<=n:return s
    if not n:return ''
    out=''; k=0
    for c in s:
        if k+cell(c)>n-1:break
        out+=c;k+=cell(c)
    return out+'…'

def pad(s,n):
    s=fit(s,n);return s+' '*max(0,n-width(s))

def color(code,s):return ESC+'['+code+'m'+s+RESET if COLORS else s

class Events:
    """Incremental ANSI parser. No fragment of a CSI report becomes a key."""
    def __init__(self):self.state='';self.buf=bytearray();self.since=0;self.events=deque()
    def feed(self,data):
        for ch in data:
            if ch==27:
                self.state='esc';self.buf.clear();self.since=time.monotonic();continue
            if self.state=='esc':
                if ch==91:self.state='csi'
                elif ch==79:self.state='ss3'
                elif ch==93:self.state='osc'
                else:self.state=''
                continue
            if self.state=='osc':
                if ch==7:self.state=''
                continue
            if self.state in ('csi','ss3','discard'):
                if 64<=ch<=126:
                    v=bytes(self.buf)+bytes([ch]);kind=self.state
                    self.state='';self.buf.clear()
                    if kind=='discard':continue
                    m=re.fullmatch(rb'<(\d{1,5});(\d{1,5});(\d{1,5})([Mm])',v)
                    if kind=='csi' and m:
                        self.events.append(('mouse',int(m[1]),int(m[2]),int(m[3]),m[4]==b'M'));continue
                    m=re.fullmatch(rb'(\d{1,5});(\d{1,5})R',v)
                    if kind=='csi' and m:self.events.append(('position',int(m[1]),int(m[2])));continue
                    if v in (b'A',b'B',b'5~',b'6~',b'H',b'F',b'C',b'D'):
                        self.events.append(('nav',v.decode()))
                elif len(self.buf)<96:self.buf.append(ch)
                else:self.state='discard'
                continue
            if ch<128:self.events.append(('key',chr(ch)))
    def expire(self):
        if self.state=='esc' and time.monotonic()-self.since>.10:
            self.state='';self.events.append(('key','\x1b'))
        # Partial CSI is deliberately never replayed as ordinary digits.

class Terminal:
    def __init__(self):self.fd=None;self.original=None;self.events=Events();self.mouse=False
    def __enter__(self):
        self.fd=os.open('/dev/tty',os.O_RDWR|os.O_NOCTTY)
        try:
            self.original=termios.tcgetattr(self.fd)
            attrs=termios.tcgetattr(self.fd)
            attrs[0]&=~(termios.BRKINT|termios.ICRNL|termios.INPCK|termios.ISTRIP|termios.IXON)
            attrs[3]&=~(termios.ECHO|termios.ECHONL|termios.ICANON|termios.IEXTEN|termios.ISIG)
            attrs[6][termios.VMIN]=1;attrs[6][termios.VTIME]=0
            termios.tcsetattr(self.fd,termios.TCSAFLUSH,attrs)
            self.write(OFF+ESC+'[?25l'+RESET)
        except BaseException:
            self.close();raise
        return self
    def write(self,s):
        data=s.encode('utf-8');view=memoryview(data)
        while view:
            n=os.write(self.fd,view);view=view[n:]
    def read(self,timeout=.1):
        if select.select([self.fd],[],[],max(0,timeout))[0]:
            b=os.read(self.fd,8192)
            if not b:raise EOFError('Terminal fermé')
            self.events.feed(b)
        self.events.expire()
    def size(self):
        z=os.get_terminal_size(self.fd);return max(12,z.lines),max(20,z.columns)
    def position(self):
        # DSR is sent exclusively while the terminal is raw and no-echo.
        self.write(ESC+'[6n');deadline=time.monotonic()+.45;keep=[];pos=None
        while time.monotonic()<deadline and pos is None:
            self.read(min(.04,deadline-time.monotonic()))
            while self.events.events:
                e=self.events.events.popleft()
                if e[0]=='position':pos=e[1:];break
                keep.append(e)
        self.events.events.extendleft(reversed(keep))
        return pos
    def close(self):
        if self.fd is None:return
        try:
            if self.original is not None:
                # Disable reporting first; consume reports already in flight before restoring echo.
                try:
                    self.write(OFF+RESET+ESC+('[?25l' if os.environ.get('BLONDIN_PORTS_PAD')=='1' else '[?25h'))
                    end=time.monotonic()+.18;quiet=time.monotonic()+.045
                    while time.monotonic()<min(end,quiet):
                        if select.select([self.fd],[],[],max(0,min(end,quiet)-time.monotonic()))[0]:
                            if not os.read(self.fd,8192):break
                            quiet=time.monotonic()+.045
                finally:
                    termios.tcsetattr(self.fd,termios.TCSAFLUSH,self.original)
        finally:
            os.close(self.fd);self.fd=None
    def __exit__(self,*exc):self.close()

ICONS={'Système':'⚙','Applications':'▦','Jeux et émulation':'◆','Maintenance':'+','Batocera commande':'›','Quiver':'◇','Retour':'‹','Quitter':'×','Quitter le gestionnaire':'×','Continuer':'›','Non':'×','Oui':'✓'}

def menu_label(label):
    return (ICONS[label]+'  '+label) if label in ICONS else label

def centered(s,cols):return ' '*max(0,(cols-width(s))//2)+s

class Menu:
    def __init__(self,t,mode,items):
        self.t=t;self.mode=mode;self.items=items;self.idx=0;self.first=0;self.hit={};self.top=0;self.bottom=0;self.last_size=None;self.relative=False;self.drawn=0;self.wheel_locked=False;self.last_frame={}
    def navigation(self,i):
        num,label,_,_=self.items[i]
        return self.mode not in ('confirm','pause') and (num.upper()=='Q' or (num=='0' and label.casefold().startswith(('retour','quitter','annuler'))))
    def boundary(self,i):
        return i>0 and self.navigation(i) and not self.navigation(i-1)
    def initialize(self):
        self.h,self.w=self.t.size();self.last_size=(self.h,self.w)
        # A preceding log line is written by tee; let it reach the terminal first.
        time.sleep(.025)
        p=self.t.position();self.block=min(58,self.w-4);self.left=(self.w-self.block)//2
        if p is None:
            self.relative=True;self.top=0;self.capacity=max(3,self.h-3);self.footer=False
            self.t.write('\r'+ESC+'[2K');return
        row=max(1,min(self.h,p[0]));total=sum(1+bool(i[2]) for i in self.items)+2*sum(self.boundary(i) for i in range(len(self.items)))
        wanted=min(total+2,self.h-2)
        if self.h-row<3:
            shift=min(row-1,3-(self.h-row))
            if shift>0:
                self.t.write(ESC+f'[{self.h};1H'+'\r\n'*shift);row-=shift
        free=self.h-row
        # Keep headings near their lists; modest vertical padding for short menus.
        gap=min(3,max(0,(free-total-2)//2)) if self.mode=='single' and total<=8 else 0
        self.top=row+gap;self.footer=self.h-self.top>=3
        self.capacity=max(1,self.h-self.top-int(self.footer));self.bottom=self.top
        self.t.write(ESC+f'[{row};1H'+ESC+'[2K')
        self.t.write(MOUSE);self.t.mouse=True
    def visible(self):
        if self.idx<self.first:self.first=self.idx
        while True:
            n=0;out=[]
            for i in range(self.first,len(self.items)):
                need=1+bool(self.items[i][2])
                if n+need>self.capacity and out:break
                if self.boundary(i) and out:
                    spare=self.capacity-n-need
                    if spare>=2:out.extend([(-1,False),(-2,False)]);n+=2
                    elif spare>=1:out.append((-2,False));n+=1
                out.append((i,False));n+=1
                if self.items[i][2] and n<self.capacity:out.append((i,True));n+=1
                if n>=self.capacity:break
            if any(i==self.idx for i,_ in out) or self.first>=self.idx:return out
            self.first+=1
    def line(self,i,detail):
        w=self.block
        if i==-1:return ''
        if i==-2:return color('0;90','─'*w)
        num,label,desc,role=self.items[i]
        if detail:
            c={'success':'1;32','warning':'1;33','error':'1;31'}.get(role,'0;36')
            return ' '*7+color(c,fit(desc,w-7))
        if self.mode=='pause':
            text=pad(centered('›  CONTINUER',w),w)
            return color('1;38;5;87;48;5;23',text)
        no=num.zfill(2) if num.isdigit() else num.upper().ljust(2)
        lab=pad(menu_label(label),w-8)
        nav_color=None
        if self.navigation(i):nav_color='1;31' if num.upper()=='Q' or label.casefold().startswith('quitter') else '1;36'
        if i==self.idx:
            if not COLORS:return '▸ '+no+'  '+lab
            return ESC+'[48;5;23m'+ESC+'[1;38;5;220m'+' ▸ '+no+'  '+ESC+('[1;38;5;203m' if nav_color=='1;31' else '[1;38;5;87m')+lab+' '+RESET
        c='1;32' if label.startswith('✓ ') else '1;31' if label.startswith('✗ ') else '1;33' if label.startswith('◆ ') else '0;37'
        return '   '+color('0;33',no)+'  '+color(nav_color or c,lab)+' '
    def draw(self):
        lines=self.visible();self.hit={};parts=[]
        if self.relative:
            if self.drawn:parts.append(ESC+f'[{self.drawn}A'+'\r')
            total=max(self.drawn,len(lines))
            for j in range(total):
                parts.append('\r'+ESC+'[2K'+(' '*self.left+self.line(*lines[j]) if j<len(lines) else '')+'\r\n')
            self.drawn=total;self.t.write(''.join(parts));return
        frame={}
        for j,(i,d) in enumerate(lines):
            y=self.top+j
            if i>=0:self.hit[y]=i
            frame[y]=' '*self.left+self.line(i,d)
        end=self.top+len(lines)
        if self.footer:
            end=min(end,self.h-1)
            extra='↑ ' if self.first else ''
            if lines and lines[-1][0]<len(self.items)-1:extra+='↓ '
            tip='Clic / Entrée pour continuer' if self.mode=='pause' else 'Souris  •  Manette  •  Clavier'
            frame[end]=color('0;90',centered(fit(extra+tip,self.block),self.w));end+=1
        for y in sorted(set(frame)|set(self.last_frame)):
            if frame.get(y)!=self.last_frame.get(y):
                parts.append(ESC+f'[{y};1H'+ESC+'[2K'+frame.get(y,''))
        self.last_frame=frame;self.bottom=min(self.h,end)
        if parts:self.t.write(''.join(parts)+ESC+f'[{self.bottom};1H')
    def action(self,choice):
        # Do not clear result, pause, confirmation, or navigation back.
        if self.mode not in ('confirm','pause','dialog') and choice not in ('0','q','Q'):
            item=next((i for i in self.items if i[0]==choice),None)
            categories={'Système','Applications','Jeux et émulation','Maintenance','Batocera commande','Logiciels','Jeux','Émulateurs et runners','Organisation des systèmes','Correctifs et patchs','Quiver','Gérer les raccourcis','Infos et diagnostics','Diagnostics','Mises à jour','Outils et lanceurs'}
            if item and item[1] not in categories:
                title=fit(item[1].upper(),self.block);rule='─'*self.block
                self.t.write(ESC+'[2J'+ESC+'[H'+color('1;36',centered(rule,self.w))+'\r\n'+color('1;96',centered(title,self.w))+'\r\n'+color('0;36',centered(rule,self.w))+'\r\n\r\n')
        return 'q' if choice=='Q' else choice
    def run(self):
        self.initialize();self.draw();digit_at=None; digits=''; allowed={i[0] for i in self.items}
        while True:
            if digit_at is not None and time.monotonic()>=digit_at:
                if self.mode!='dialog':return self.action('1')
                if digits in allowed:return self.action(digits)
                digit_at=None;digits=''
            if not self.t.events.events:self.t.read(.04 if digit_at else .10)
            if not self.t.events.events:continue
            e=self.t.events.events.popleft();prev=self.idx
            if digit_at is not None and self.mode=='dialog':
                if e[0]=='key' and e[1].isdigit():
                    digits+=e[1]; digit_at=time.monotonic()+.65
                    if digits in allowed and not any(x.startswith(digits) and x!=digits for x in allowed):return self.action(digits)
                    if not any(x.startswith(digits) for x in allowed):digits='';digit_at=None
                    continue
                if e[0]=='key' and e[1] in ('\r','\n') and digits in allowed:return self.action(digits)
                if e[0]=='position' or (e[0]=='mouse' and (e[1]&32 or not e[4])):continue
                digits='';digit_at=None
            if digit_at is not None:
                if e[0]!='key':continue
                digit_at=None
                if e[1] in '01':return self.action('1'+e[1])
                return self.action('1')
            if e[0]=='position':continue
            if e[0]=='nav':
                if self.mode=='pause':return '0'
                self.wheel_locked=True
                k=e[1];n=len(self.items)
                if k=='A':self.idx=(self.idx-1)%n
                elif k=='B':self.idx=(self.idx+1)%n
                elif k=='5~':self.idx=max(0,self.idx-5)
                elif k=='6~':self.idx=min(n-1,self.idx+5)
                elif k=='H':self.idx=0
                elif k=='F':self.idx=n-1
            elif e[0]=='mouse' and self.t.mouse:
                _,b,x,y,pressed=e
                if not pressed:continue
                if b&128:continue
                hit=self.hit.get(y) if self.left<x<=self.left+self.block else None
                if b&64:
                    if self.mode!='pause' and (b&3) in (0,1):
                        self.wheel_locked=True
                        self.idx=(self.idx+(-1 if (b&3)==0 else 1))%len(self.items)
                elif b&32:
                    if not self.wheel_locked and hit is not None:self.idx=hit
                elif b&3==2:return '0'
                elif b&3==0:
                    # Always validate the highlighted choice, not the pointer coordinates.
                    return self.action(self.items[self.idx][0])
            elif e[0]=='key':
                k=e[1]
                if k=='\x03':raise KeyboardInterrupt
                if self.mode=='pause':return '0'
                if k in ('\r','\n'):return self.action(self.items[self.idx][0])
                if k in ('\x1b','0','\x04'):return '0'
                if k in 'qQ':return '0' if self.mode in ('confirm','dialog') else 'q'
                if self.mode=='dialog':
                    if k.isdigit() and k!='0':
                        if k in allowed and not any(x.startswith(k) and x!=k for x in allowed):return self.action(k)
                        if any(x.startswith(k) for x in allowed):digits=k;digit_at=time.monotonic()+.65
                    elif k in allowed:return self.action(k)
                    continue
                if self.mode=='confirm' and k in 'oOyYnN':return '1' if k in 'oOyY' else '0'
                if k in '123456789':
                    if self.mode=='ten' and k=='1':digit_at=time.monotonic()+.8;continue
                    return self.action(k)
                # Preserve explicit letter choices used by some legacy menus.
                if k.isascii() and k.isalpha() and self.mode not in ('confirm','pause'):return k
            if self.idx!=prev:self.draw()

# Reports are independent of the ordinary menu, with fixed title and actions.
ANSI=re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
HEADINGS={'MACHINE','RÉSEAU','PERFORMANCES','MÉMOIRE / STOCKAGE','SYSTÈME','BATTERIE','ALIMENTATION'}

def report_lines(raw):
    return [safe(ANSI.sub('',line)).rstrip() for line in raw.splitlines() if ANSI.sub('',line).strip()]

def wrap_cells(text,limit):
    # Do not ellipsize data, including long device names and paths.
    result=[]
    while width(text)>limit:
        k=0;cut=0
        for i,ch in enumerate(text):
            if k+cell(ch)>limit:break
            k+=cell(ch);cut=i+1
        cut=max(1,cut)
        sp=text.rfind(' ',0,cut+1)
        if sp>0:cut=sp
        result.append(text[:cut]);text=text[cut:].lstrip()
    result.append(text)
    return result

def report_layout(raw,cols,kind):
    lines=report_lines(raw)
    if kind=='system':lines=[v.strip() for v in lines]
    def render(seq,n):
        out=[]
        for line in seq:
            out.extend((part, '1;96' if line in HEADINGS else '0;37') for part in wrap_cells(line,n))
        return out
    if kind!='system' or cols<74:
        return [(color(c,v),width(v)) for v,c in render(lines,cols)]
    groups=[]
    for line in lines:
        if line in HEADINGS or not groups:groups.append([])
        groups[-1].append(line)
    if len(groups)<2:return [(color(c,v),width(v)) for v,c in render(lines,cols)]
    n=(cols-3)//2; best=None
    for i in range(1,len(groups)):
        a=render([v for g in groups[:i] for v in g],n)
        b=render([v for g in groups[i:] for v in g],n)
        score=max(len(a),len(b))
        if best is None or score<best[0]:best=(score,a,b)
    _,a,b=best;out=[]
    for i in range(max(len(a),len(b))):
        av,ac=a[i] if i<len(a) else ('','0;37');bv,bc=b[i] if i<len(b) else ('','0;37')
        out.append((color(ac,pad(av,n))+'   '+color(bc,bv),n+3+width(bv)))
    return out

class Report(Menu):
    def __init__(self,t,title,kind,raw,items):
        super().__init__(t,'dialog',items);self.title=title;self.kind=kind;self.raw=raw;self.page=0;self.pages=1
    def layout(self):
        self.h,self.w=self.t.size();self.last_size=(self.h,self.w)
        self.block=min(110,self.w-4);self.left=(self.w-self.block)//2
        self.lines=report_layout(self.raw,self.block,self.kind) or [('Aucune information disponible',27)]
        self.separated=any(self.boundary(i) for i in range(len(self.items))) and self.h>=len(self.items)+8
        self.capacity=max(1,self.h-5-len(self.items)-int(self.separated));self.pages=max(1,(len(self.lines)+self.capacity-1)//self.capacity)
        self.page=min(self.page,self.pages-1);self.top=5+self.capacity
    def draw(self,clear=False):
        self.layout();frame={};self.hit={}
        def put(y,s):frame[y]=s
        rule='─'*self.block
        put(1,' '*self.left+color('1;36',rule))
        put(2,color('1;96',centered(fit(self.title,self.block),self.w)))
        put(3,' '*self.left+color('1;36',rule))
        for j,(line,_) in enumerate(self.lines[self.page*self.capacity:(self.page+1)*self.capacity]):put(4+j,' '*self.left+line)
        pager=fit(f'Page {self.page+1}/{self.pages}  |  Molette sur rapport / ← →',self.block)
        put(4+self.capacity,color('1;36',centered(pager,self.w)))
        y=self.top
        for i,it in enumerate(self.items):
            if self.separated and self.boundary(i):
                put(y,' '*self.left+color('0;90',rule));y+=1
            self.hit[y]=i;put(y,' '*self.left+self.line(i,False));y+=1
        # No extra newline at the terminal bottom: no scroll.
        parts=[ESC+'[2J'] if clear else []
        for y in sorted(set(frame)|set(self.last_frame)):
            if clear or frame.get(y)!=self.last_frame.get(y):parts.append(ESC+f'[{y};1H'+ESC+'[2K'+frame.get(y,''))
        self.last_frame=frame
        if parts:self.t.write(''.join(parts)+ESC+f'[{self.h};1H')
    def run(self):
        self.t.write(MOUSE);self.t.mouse=True;self.draw(True)
        while True:
            if self.t.size()!=self.last_size:self.draw(True)
            if not self.t.events.events:self.t.read(.1)
            if not self.t.events.events:continue
            e=self.t.events.events.popleft();old=(self.idx,self.page)
            if e[0]=='nav':
                k=e[1]
                if k in ('C','6~'):self.page=min(self.pages-1,self.page+1)
                elif k in ('D','5~'):self.page=max(0,self.page-1)
                elif k=='A':self.idx=(self.idx-1)%len(self.items);self.wheel_locked=True
                elif k=='B':self.idx=(self.idx+1)%len(self.items);self.wheel_locked=True
            elif e[0]=='mouse':
                _,b,x,y,pressed=e
                if not pressed or b&128:continue
                hit=self.hit.get(y) if self.left<x<=self.left+self.block else None
                if b&64 and (b&3) in (0,1):
                    delta=-1 if (b&3)==0 else 1
                    if y<self.top:self.page=max(0,min(self.pages-1,self.page+delta))
                    else:self.idx=(self.idx+delta)%len(self.items);self.wheel_locked=True
                elif b&32:
                    if hit is not None and not self.wheel_locked:self.idx=hit
                elif b&3==2:return '0'
                elif b&3==0:return 'q' if self.items[self.idx][0]=='Q' else self.items[self.idx][0]
            elif e[0]=='key':
                k=e[1]
                if k=='\x03':raise KeyboardInterrupt
                if k in ('\x1b','0','\x04'):return '0'
                if k in 'qQ':return 'q'
                if k in ('\r','\n'):return 'q' if self.items[self.idx][0]=='Q' else self.items[self.idx][0]
                if k in {i[0] for i in self.items}:return k
                if k in 'nN':self.page=min(self.pages-1,self.page+1)
                if k in 'pP':self.page=max(0,self.page-1)
            if old!=(self.idx,self.page):self.draw()

def report(args):
    title,kind,*rawitems=args
    if not rawitems or len(rawitems)%4:raise ValueError('Rapport invalide')
    items=[tuple(safe(s) for s in rawitems[i:i+4]) for i in range(0,len(rawitems),4)]
    raw=sys.stdin.read()
    def stop(sig,frame):raise KeyboardInterrupt
    for sig in (signal.SIGINT,signal.SIGTERM,signal.SIGHUP):signal.signal(sig,stop)
    with Terminal() as t:result=Report(t,title,kind,raw,items).run()
    print(result,end='',flush=True)

def navigate(args):
    mode=args[0];raw=args[1:]
    if len(raw)%4 or not raw:raise ValueError('Menu invalide')
    items=[tuple(safe(s) for s in raw[i:i+4]) for i in range(0,len(raw),4)]
    def stop(sig,frame):raise KeyboardInterrupt
    for s in (signal.SIGINT,signal.SIGTERM,signal.SIGHUP):signal.signal(s,stop)
    with Terminal() as t:
        result=Menu(t,mode,items).run()
    print(result,end='',flush=True)

SHELL=r'''
v501_report_menu(){
  local producer="$1" heading="$2" kind="$3" data rc=0
  shift 3
  local -a args=()
  while (( $# >= 2 )); do args+=("$1" "$2" '' 'info'); shift 2; done
  data="$(BLONDIN_REPORT_CAPTURE=1 "$producer")" || rc=$?
  if ((rc)); then data+=$'\n[ATTENTION] Rapport partiel (code '"$rc"').'; fi
  printf '%s\n' "$data" | python3 /userdata/system/blondin-v4/helpers/interface-v501.py report "$heading" "$kind" "${args[@]}"
}
v501_center(){
  local role="$1" line="$2" c p
  c="$(ui_installation_cols)"; line="$(ui_fit "$line" "$((c-2))")"
  p=$(((c-${#line})/2)); ((p<0)) && p=0
  printf '%*s' "$p" ''; ui_print "$role" "$line"
}
v501_section(){
  local c w rule path='' part f i last=''
  c="$(ui_installation_cols)"; w=$((c-4)); ((w>58)) && w=58; ((w<12)) && w=12
  for ((i=${#FUNCNAME[@]}-1;i>=0;i--)); do
    f="${FUNCNAME[i]}"; part=''
    case "$f" in
      v41_main) part='Accueil';; v41_apps) part='Applications';; v41_software) part='Logiciels';;
      v41_games_emulation) part='Jeux et émulation';; v41_games) part='Jeux';;
      v41_emulators) part='Émulateurs';; v41_system) part='Système';;
      v41_maintenance) part='Maintenance';; v41_info) part='Diagnostics';;
      v416_quiver|v416_q_systems) part='Quiver';; v41_updates) part='Mises à jour';;
    esac
    if [[ -n "$part" && "$part" != "$last" && "${part^^}" != "${1^^}" ]]; then
      path="${path:+$path › }$part"; last="$part"
    fi
  done
  printf -v rule '%*s' "$w" ''; rule="${rule// /─}"
  printf '\n'
  if [[ -n "$path" && "$1" != 'MENU PRINCIPAL' ]]; then v501_center info "$path"; fi
  v501_center section "$rule"; v501_center title "$1"; v501_center section "$rule"
}
v501_banner(){
  local c w rule; c="$(ui_installation_cols)"; w=$((c-4)); ((w>58)) && w=58; ((w<12)) && w=12
  printf -v rule '%*s' "$w" ''; rule="${rule// /━}"
  printf '\n'
  v501_center section "$rule"; v501_center title 'GESTIONNAIRE BATOCERA'
  v501_center gold '★ BLONDIN EDITION ★'; v501_center section "$rule"
  v501_center menu 'v5.0.1  •  BATOCERA 44'; v501_center success '● SYSTÈME PRÊT'
}
if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 ]]; then
  read(){
    if [[ -t 0 && " $* " != *" -n "* && " $* " != *" -N "* ]]; then
      printf '\033[?25h' >/dev/tty 2>/dev/null || true
    fi
    builtin read "$@"
  }
fi
v501_terminal_reset(){ printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?25h\033[0m' >/dev/tty 2>/dev/null || true; }
manager_menu_navigation(){
  local mode="${1:-single}" i result
  local -a args=("$mode")
  ((${#UI_MENU_NUMBERS[@]}>0)) || return 2
  for i in "${!UI_MENU_NUMBERS[@]}"; do
    args+=("${UI_MENU_NUMBERS[i]}" "${UI_MENU_LABELS[i]}" "${UI_MENU_DETAILS[i]:-}" "${UI_MENU_DETAIL_ROLES[i]:-info}")
  done
  result="$(python3 /userdata/system/blondin-v4/helpers/interface-v501.py navigate "${args[@]}")" || { v501_terminal_reset; return 1; }
  if [[ "$result" == q && "$mode" != pause ]]; then manager_quit_key q && return 1; fi
  printf '%s' "$result"
}
'''

LAUNCHER=r'''#!/bin/bash
export DISPLAY="${DISPLAY:-:0}"
export BLONDIN_PORTS_PAD=1
SCRIPT=/userdata/system/gestionnaire-batocera.sh
[[ -f "$SCRIPT" ]] || { echo '[ERREUR] Gestionnaire introuvable.'; exit 1; }
read -r cols rows fs x y < <(python3 - <<'PYGEO'
import re, subprocess
def run(args):
    try:return subprocess.check_output(args,text=True,stderr=subprocess.DEVNULL,timeout=3)
    except (OSError,subprocess.SubprocessError):return ''
mon=[]
for line in run(['xrandr','--current']).splitlines():
    m=re.search(r'^(\S+)\s+connected\s+(primary\s+)?(\d+)x(\d+)([+-]\d+)([+-]\d+)',line)
    if m:mon.append((bool(m[2]),int(m[3]),int(m[4]),int(m[5]),int(m[6])))
if mon:primary,w,h,ox,oy=max(mon,key=lambda v:(v[1]*v[2],v[0]))
else:
    m=re.search(r'dimensions:\s+(\d+)x(\d+)',run(['xdpyinfo']))
    w,h=(int(m[1]),int(m[2])) if m else (1280,800);ox=oy=0
dpi=96
m=re.search(r'resolution:\s+(\d+)x(\d+)',run(['xdpyinfo']))
if m:dpi=max(72,min(180,int(m[2])))
cols,rows=80,28
fs=32
while fs>10 and (cols*fs*dpi/72*.63+20>w*.95 or rows*fs*dpi/72*1.28+32>h*.95):fs-=1
ww=int(cols*fs*dpi/72*.60+8);hh=int(rows*fs*dpi/72*1.23+22)
print(cols,rows,fs,max(0,ox+(w-ww)//2),max(0,oy+(h-hh)//2))
PYGEO
)
[[ "$cols" =~ ^[0-9]+$ ]] || { cols=80; rows=28; fs=15; x=0; y=0; }
# Motif hints are advisory; the compositor is free to ignore them.
exec xterm -bg black -fg white -fa 'DejaVu Sans Mono' -fs "$fs" \
  -geometry "${cols}x${rows}+${x}+${y}" -xrm 'XTerm*pointerShape: left_ptr' -xrm 'XTerm*pointerColor: #55d9ee' -xrm 'XTerm*pointerColorBackground: white' +bc +sb -b 2 -bw 0 -sl 5000 \
  -xrm 'XTerm*omitTranslation: select,block-select,wheel-mouse' \
  -xrm 'XTerm*VT100.translations: #override \n Shift <Btn4Down>: scroll-back(3,line) \n Shift <Btn5Down>: scroll-forw(3,line) \n <Btn4Up>: string("") \n <Btn5Up>: string("") \n Shift <Btn1Down>: select-start() \n Shift <Btn1Motion>: select-extend() \n Shift <Btn1Up>: select-end(CLIPBOARD,PRIMARY) \n Ctrl Shift <Key>C: copy-selection(CLIPBOARD) \n Ctrl Shift <Key>V: insert-selection(CLIPBOARD) \n Shift <Key>Insert: insert-selection(CLIPBOARD,PRIMARY)' \
  -xrm 'XTerm*highlightSelection: true' -xrm 'XTerm*highlightColor: #23434a' -xrm 'XTerm*highlightTextColor: white' \
  -title 'Gestionnaire Batocera - BLONDIN EDITION' -e /bin/bash -c '
    if [[ "${WINDOWID:-}" =~ ^[0-9]+$ ]] && command -v xprop >/dev/null 2>&1; then
      xprop -id "$WINDOWID" -f _MOTIF_WM_HINTS 32c -set _MOTIF_WM_HINTS "2, 0, 0, 0, 0" >/dev/null 2>&1 || true
    fi
    exec /bin/bash "$1"
  ' bash "$SCRIPT"
'''


def once(s,a,b):
    if s.count(a)!=1:raise RuntimeError('Ancre UI inattendue : '+a[:100])
    return s.replace(a,b,1)

def patch_manager(s):
    a=s.index('manager_menu_navigation(){');b=s.index('\nread_key(){',a)
    s=s[:a]+SHELL+s[b:]
    s=once(s,'ui_section(){\n','ui_section(){\n  if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 && -t 0 ]]; then v501_section "$1"; return; fi\n')
    s=once(s,'ui_banner(){\n','ui_banner(){\n  if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 && -t 0 ]]; then v501_banner; return; fi\n')
    s=once(s,"manager_closed_message(){ echo 'Gestionnaire fermé.'; }", "manager_closed_message(){ if [[ \"${BLONDIN_PORTS_PAD:-0}\" == 1 ]]; then v501_terminal_reset; fi; echo 'Gestionnaire fermé.'; }")
    a=s.index('read_key(){');b=s.index('\n# Rafraichit uniquement',a);fn=s[a:b]
    fn=once(fn,'  ui_prompt "$prompt"\n','  if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 && -t 0 && ${#UI_MENU_NUMBERS[@]} -gt 0 && ( "$prompt" == \'Votre choix : \' || "$prompt" == \'CHOIX : \' ) ]]; then\n    manager_menu_navigation "$mode"; return $?\n  fi\n  ui_prompt "$prompt"\n')
    a2=fn.index('  # Flèches/validation');b2=fn.index('  IFS= read -r -s -n 1 key',a2);fn=fn[:a2]+fn[b2:]
    s=s[:a]+fn+s[b:]
    s=once(s,'refresh_screen(){\n','refresh_screen(){\n  if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 && -t 0 ]]; then printf \'\\033[?25l\' >/dev/tty 2>/dev/null || true; fi\n')
    a=s.index('    launcher_text = """#!/bin/bash');b=s.index('\n"""',a)+4
    s=s[:a]+'    launcher_text = '+repr(LAUNCHER)+s[b:]
    old='confirm(){ local ans; ans="$(read_key "$1 [o/N] : ")" || return 1; [[ "$ans" =~ ^[oOyY]$ ]]; }'
    new=r'''confirm(){
  local ans
  if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 && -t 0 ]]; then
    local -a UI_MENU_NUMBERS=(0 1) UI_MENU_LABELS=('Non' 'Oui')
    local -a UI_MENU_DETAILS=() UI_MENU_DETAIL_ROLES=()
    v501_center warning "$1"
    ans="$(manager_menu_navigation confirm)" || return 1
    [[ "$ans" == 1 ]]
  else
    ans="$(read_key "$1 [o/N] : ")" || return 1
    [[ "$ans" =~ ^[oOyY]$ ]]
  fi
}'''
    s=once(s,old,new)
    s=once(s,'pause(){\n  local _\n','''pause(){
  local _
  if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 && -t 0 ]]; then
    local -a UI_MENU_NUMBERS=(0) UI_MENU_LABELS=('Continuer')
    local -a UI_MENU_DETAILS=() UI_MENU_DETAIL_ROLES=()
    manager_menu_navigation pause >/dev/null && return 0
  fi
''')
    a='    [[ -n "$line" ]] && ui_print "$role" "  $line"'
    if a in s:s=once(s,a,'    if [[ -n "$line" ]]; then\n      if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 && -t 0 ]]; then v501_center "$role" "$line"; else ui_print "$role" "  $line"; fi\n    fi')
    # Initial welcome is also a pause, allowing mouse-only entry.
    a="ui_print gold '  ★ Appuyer sur une touche  ★'\nif [[ -t 0 ]]; then IFS= read -r -s -n 1 _startup_key || true; else IFS= read -r _startup_key || true; fi"
    b="""if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 && -t 0 ]]; then
  pause
else
  ui_print gold '  ★ Appuyer sur une touche  ★'
  if [[ -t 0 ]]; then IFS= read -r -s -n 1 _startup_key || true; else IFS= read -r _startup_key || true; fi
fi"""
    s=once(s,a,b)
    return patch_reports(patch_backup(s))


def patch_reports(s):
    # Read-only output producers run in a command substitution. Suppress only
    # the terminal clear and title while capturing their existing data.
    s=once(s,'refresh_screen(){\n','refresh_screen(){\n  [[ "${BLONDIN_REPORT_CAPTURE:-0}" == 1 ]] && return 0\n')
    s=once(s,'ui_section(){\n','ui_section(){\n  if [[ "${BLONDIN_REPORT_CAPTURE:-0}" == 1 ]]; then [[ "$1" == "INFORMATIONS SYSTÈME" || "$1" == "DISQUES ET PARTITIONS" ]] || ui_print section "$1"; return 0; fi\n')
    s=once(s,'sys_info_menu(){\n  local choice\n  while :; do\n    sys_info_overview',r'''sys_info_menu(){
  local choice
  if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 && -t 0 ]]; then
    while :; do
      choice="$(v501_report_menu sys_info_overview 'INFORMATIONS SYSTÈME' system 1 'Actualiser' 2 'Détails des disques' 3 'Vérifier / MAJ Batocera' 0 'Retour' Q 'Quitter le gestionnaire')" || return 0
      case "$choice" in
        1) continue;; 2) sys_info_disks_menu;; 3) sys_info_updates_menu;; 0) return 0;; q|Q) exit 0;;
      esac
    done
  fi
  while :; do
    sys_info_overview''')
    s=once(s,'sys_info_disks_menu(){\n  local choice\n  while :; do\n    sys_info_disks',r'''sys_info_disks_menu(){
  local choice
  if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 && -t 0 ]]; then
    while :; do
      choice="$(v501_report_menu sys_info_disks 'DISQUES ET PARTITIONS' plain 1 'Actualiser' 0 'Retour' Q 'Quitter le gestionnaire')" || return 0
      case "$choice" in 1) continue;; 0) return 0;; q|Q) exit 0;; esac
    done
  fi
  while :; do
    sys_info_disks''')
    s=once(s,'manager_paged_output(){\n',r'''manager_paged_output(){
  if [[ "${BLONDIN_PORTS_PAD:-0}" == 1 && -t 0 ]]; then
    local answer
    answer="$(v501_report_menu "$1" 'DIAGNOSTIC - LECTURE' plain 0 'Retour' Q 'Quitter le gestionnaire')" || return 0
    [[ "$answer" == q || "$answer" == Q ]] && exit 0
    return 0
  fi
''')
    return s

def patch_backup(s):
    a=s.index("<<'PY_BACKUP44'\n")+len("<<'PY_BACKUP44'\n")
    b=s.index('\nPY_BACKUP44\n',a)
    src=s[a:b]
    src=once(src,'def prompt(msg):\n',r'''PORTS_UI=os.environ.get('BLONDIN_PORTS_PAD')=='1'
UI_HELPER='/userdata/system/blondin-v4/helpers/interface-v501.py'

def ports_choose(entries):
    # The helper reads /dev/tty, not the stdin carrying this Python source.
    print('',flush=True)
    args=['dialog']
    for key,label in entries:
        args.extend((str(key),str(label),'','info'))
    result=subprocess.run([sys.executable,UI_HELPER,'navigate',*args],stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,text=True)
    if result.returncode:
        raise BackupError('Navigation interrompue : aucun choix appliqué.')
    choice=result.stdout.strip()
    if choice not in {str(key) for key,label in entries}:
        raise BackupError('Sélection annulée.')
    return choice

def ports_cursor():
    if PORTS_UI:
        try:
            with open('/dev/tty','w') as ttyout:ttyout.write('\033[?25h')
        except OSError:pass

def prompt(msg):
    ports_cursor()
''')
    src=once(src,"    print('[APPAREIL] Détection :',detected)\n",r'''    print('[APPAREIL] Détection :',detected)
    if PORTS_UI:
        entries=[('1','Mini-PC'+(' (détecté)' if detected=='MiniPC' else '')),('2','Steam Deck'+(' (détecté)' if detected=='SteamDeck' else ''))]
        if detected=='SteamDeck':entries.reverse()
        choice=ports_choose(entries+[('0','Annuler / retour')])
        if choice=='0':raise BackupError('Sélection annulée.')
        return {'1':'MiniPC','2':'SteamDeck'}[choice]
''')
    src=once(src,"    for i,f in enumerate(files,1):print(f'  {i}) {f.name}')\n    n=prompt('Numéro (0 = annuler) : ')",r'''    if PORTS_UI:
        n=ports_choose([(str(i),f.name) for i,f in enumerate(files,1)]+[('0','Annuler / retour')])
    else:
        for i,f in enumerate(files,1):print(f'  {i}) {f.name}')
        n=prompt('Numéro (0 = annuler) : ')
'''.rstrip())
    start=src.index("        for n,p in enumerate(available,1):")
    end=src.index("        if answer=='0':",start)
    old=src[start:end]
    new=r'''        if PORTS_UI:
            entries=[]
            for n,p in enumerate(available,1):
                slug=custom_slug(p.name)
                mark='✓' if slug in already else '[x]' if slug in selected else '[ ]'
                entries.append((str(n),mark+' '+(slug.upper() if slug in priority else slug)))
            answer=ports_choose(entries+[('s','Enregistrer / retour'),('0','Annuler sans enregistrer')])
            if answer=='0':return
            if answer=='s':answer='0'
        else:
'''+''.join('    '+line if line.strip() else line for line in old.splitlines(keepends=True))
    src=src[:start]+new+src[end:]
    src=once(src,"    choice=prompt('Choix [0 = annuler] : ')\n    if choice=='0' or choice not in ('1','2'):","    choice=ports_choose([('0','Annuler / retour'),('1','Tous les paramètres')]+([('2','Systèmes personnalisés')] if custom_keys else [])) if PORTS_UI else prompt('Choix [0 = annuler] : ')\n    if choice=='0' or choice not in ('1','2'):")
    src=once(src,"    choice=prompt('Choix [0 = annuler] : ')\n    if choice!='1':","    choice=ports_choose([('0','Annuler / retour'),('1','Restaurer maintenant')]) if PORTS_UI else prompt('Choix [0 = annuler] : ')\n    if choice!='1':")
    src=once(src,"    if not f.is_file(): raise BackupError('Aucun Runner en attente.')","    if not f.is_file():\n        if PORTS_UI:\n            status_ok('Aucun runner en attente : rien à réappliquer.')\n            return\n        raise BackupError('Aucun Runner en attente.')")
    src=once(src,"    if prompt('Appliquer les choix devenus disponibles ? Taper OUI : ')!='OUI':return","    if PORTS_UI:\n        print('Appliquer les choix devenus disponibles ?')\n        if ports_choose([('0','Non / annuler'),('1','Oui, appliquer')])!='1':return\n    elif prompt('Appliquer les choix devenus disponibles ? Taper OUI : ')!='OUI':return")
    src=once(src,'def password(twice=False):\n','def password(twice=False):\n    ports_cursor()\n')
    src=once(src,'def token():\n','def token():\n    ports_cursor()\n')
    src=once(src,"    print('  1) Tous les paramètres')\n    print('  2) Systèmes personnalisés')\n    print('  0) Annuler')", "    if not PORTS_UI:\n        print('  1) Tous les paramètres')\n        print('  2) Systèmes personnalisés')\n        print('  0) Annuler')")
    src=once(src,"    print('  ',paint('1)', 'ok'),'Restaurer')\n    print('  ',paint('0)', 'warning'),'Annuler')", "    if not PORTS_UI:\n        print('  ',paint('1)', 'ok'),'Restaurer')\n        print('  ',paint('0)', 'warning'),'Annuler')")
    compile(src,'PY_BACKUP44','exec')
    return s[:a]+src+s[b:]


def patch_installer(s):
    a='if [[ ! -f "$LAUNCHER" ]]; then\n  cat > "$LAUNCHER" <<\'LAUNCHERV4\'\n'
    b='if [[ ! -f "$LAUNCHER" ]] || { grep -q "BLONDIN_PORTS_PAD=1" "$LAUNCHER" && grep -q "gestionnaire-batocera.sh" "$LAUNCHER" && grep -q "xterm" "$LAUNCHER"; }; then\n  cat > "$LAUNCHER" <<\'LAUNCHERV4\'\n'
    s=once(s,a,b);i=s.index(b)+len(b);j=s.index('\nLAUNCHERV4',i)
    s=s[:i]+LAUNCHER.rstrip('\n')+s[j:]
    s=once(s,"echo '[OK] Lanceur Ports existant conserve.'","echo '[INFO] Lanceur Ports personnalise conserve : centrage non modifie.'")
    return s

if __name__=='__main__':
    try:
        if len(sys.argv)<3:raise ValueError('Usage : navigate mode options / report titre type options')
        if sys.argv[1]=='report':report(sys.argv[2:])
        elif sys.argv[1]=='navigate':navigate(sys.argv[2:])
        else:raise ValueError('Mode inconnu')
    except (KeyboardInterrupt,EOFError):sys.exit(130)
    except Exception as e:print('[ERREUR UI]',e,file=sys.stderr);sys.exit(1)
