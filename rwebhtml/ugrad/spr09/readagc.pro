pro readagc,entry

openr,1,'/home/dorado3/galaxy/esp3/cats/agc2000.north'

agc=''
which=''
position=''
a100=0
b100=0
mag10=0
inccode=0
posang=0
descrip=''
bsteintype=0
vopt=0
verr=0
extrc3=0
extdirbe=0
vsrc=0
ngcic=''
flux100=0
rms100=0
v21=0
width=0
widtherr=0
widthcode=''
telcode=''
detcode=0
hisrc=0
statuscode=0
snratio=0
ibandqual=0
ibandsrc=0
irasflag=0
icluster=0
hidata=0
iposition=0
ipalomar=0
rc3flag=0
irotcat=0
newstuff=0


formatin='(A6,A1,A14,I5,2I4,I2,I3,A8,I3,I6,I3,2I5,I3,A8,I5,I4,I5,I4,I2,A4,A1,I1,I2,I1,I3,I1,I2,I1,I2,5I1,I2)'
while (~EOF(1)) do begin

readf,1,format=formatin,agc,which,position,a100,b100,$
  mag10,inccode,posang,descrip,bsteintype,vopt,verr,$
  extrc3,extdirbe,vsrc,ngcic,flux100,rms100,v21,width,$
  widtherr,widthcode,telcode,detcode,hisrc,statuscode,$
  snratio,ibandqual,ibandsrc,irasflag,icluster,hidata,$
  iposition,ipalomar,rc3flag,irotcat,newstuff

formatout='(A6,A8,A14,I5,I5,I6)'
if (agc eq entry) then print,format=formatout,agc,$
  ngcic,position,v21,a100,vopt
endwhile

close,1
free_lun,1

end 
