C
C  Test of schedule for a give night 
C  A2941 search mode sources
C        
      CHARACTER CATFILE*60,LINE*65
      CHARACTER header*10
      CHARACTER SRCNAME*16,SIGN*1
      INTEGER irh,irm,idd,idm,ids,ivhel
      REAL ras
      REAL ONEDEG,AOLATDEG,HAdeg,azdeg,zadeg
      REAL timecalonoff

      write(*,'('' enter name of input observing catalog'')')
      read(*,'(a60)') CATFILE
      open(10,file=CATFILE,status='old')
      open(14,file='junk',status='unknown')
      open(15,file='junk.cmd',status='unknown')
      open(16,file='junk.obslog',status='unknown')


      ONEDEG=3.1415926536/180.
      AOLATDEG=18.+(20./60.)+(36.6/3600.)

      write(15,300)
      write(15,301)
      write(15,302)
      write(15,303)
      write(15,304)
      write(15,305)
  300 format("#Mar2015 command file for Lwide observing")
  301 format("#Observing program A2941")
  302 format("#Script generated, MPH 15.03.22")
  303 format("#")
  304 format("CATALOG a2941.cat")
  305 format("WAIT 10")


      do 20 j=1,8
      read(10,'(a10)') HEADER
   20 continue


C  slew speed in az is 0.4 deg/s
C  slew speed in za = 0.04 deg/a
      speed_az=0.4
      speed_za=0.04

C  leave 10 seconds to settle; was once 20 but 10 seems to work
      settle=10.
      nin=0

C  The run in Jan 2015 starts about 09h; ends around 14h
C
C FOR JAN 12      timestart=7.90
C  On Mar 28 we start at 10h37
C  Other days more like 08h00
C      timestart=10.6
C
C  For the last night start at 09h17

      timestart=9.28
      timenow=timestart*15.
      azdeg_last=60.
      zadeg_last=10.
C

    1 read(10,'(a65)',end=99,err=98) LINE
      read(LINE,100) SRCNAME,irh,irm,ras,
     *    sign,idd,idm,ids
  100 format(a16,2x,2i2.2,f4.1,1x,a1,3i2.2)

      write(16,'(a65)') LINE


C  Previous runs/calibrators use time = 180 secs
C       (3 min ON+OFF)
C  Sources whose names start with "S" refer to those
C       observed in "search mods" for 300 sec
C       (5 min ON+OFF)
C  You can also set the time for individual sources
C       explicitly here (that is known to have been done)
C 
      timesec=180.0
      IF(SRCNAME(1:1).eq.'S') timesec=300.

C  The CAlon/off sequences takes 20 sec (10 ON + 10 OFF)
C  Pairtime is the time in minutes per pair (including caltime)
C  For 5 min on-off it is 13 mins; so for us it should be about 8;
C  From cimalog for a2300 it seems a 180 sec on-off w/ 60sec wait 
C  takes 14:42:07 - 14:34:41 ~  
C  Starting 2015, default is 5 min ON-OFF is srcname ="S"
C  Use 3 mins for calibrators ets
      pairtime=8.0
      if(timesec.eq.240.) pairtime=10.5
C  Gonna shorten this by 30 secs; see if better timing
      if(timesec.eq.300.) pairtime=12.5

      rahrs=real(irh)+real(irm)/60.+ ras/3600.
      radeg=rahrs*15.
      decdeg=real(idd)+real(idm)/60.+real(ids)/3600.
      if(sign.eq.'-') decdeg=-decdeg

      HAdeg=timenow-radeg

      call AZZA(HAdeg,Decdeg,azdeg,zadeg)

C
C   calculate move time
C
C  Here for fall only!
C     keep only for checking purposes; don't need it
C      if(azdeg_last.lt.100.) azdec_last=azdel_last+360.
C      if(azdeg.lt.100.) azdeg=azdeg+360.
      delta_az=abs(azdeg_last - azdeg)

      if(delta_az.gt.300) then
            if(azdeg_last .lt. 300 .and. azdeg.gt.300) 
     *           azdeg_last = azdeg_last +360.
            if(azdeg_last .gt. 300 .and. azdeg.lt.300) 
     *           azdeg = azdeg +360.
            delta_az=abs(azdeg_last - azdeg)
      endif

      delta_za=abs(zadeg_last - zadeg)
      time_az=delta_az/speed_az
      time_za=delta_za/speed_za
      timeslew=time_az
      if(time_za.gt.time_az) timeslew=time_za
      timemovesec=timeslew+settle
      timemove=timemovesec/60.
      
      timenow = timenow + (timemovesec*360./(24.*3600.))
C
C  In the fall, we cross 0 hours
      timeobs=timenow/15.
      ihtime=int(timeobs)
      xmtime=60.*(timeobs-real(ihtime))
      imtime=nint(xmtime)
      if(ihtime.ge.24) ihtime=ihtime-24
C
C  Put constraints here
C
      if(zadeg.gt.17 .and. decdeg.gt.3 .and. decdeg.lt.33) then
         write(*,'('' ZA gt 18 so quitting here '')')
         go to 99
      endif
      if(zadeg.gt.19.) then
         write(*,'('' ZA gt 19 so quitting here '')')
         go to 99
      endif
      if(zadeg.lt.3.) then
         write(*,'('' ZA lt 3 so quitting here '')')
         go to 99
      endif

      write(14,110) srcname, radeg, decdeg, HAdeg, azdeg, zadeg, 
     *    ihtime, imtime ,timemove
  110 format(a16,5f9.2,3x,i2.2,'h',i2.2,'m',f9.1,'m')
      write(*,110) srcname, radeg, decdeg, HAdeg, azdeg, zadeg, 
     *    ihtime, imtime,timemove

      write(15,210) SRCNAME
  210 format("GOTO ",a16)

      if(timesec.eq.180.0) intsec=180
      if(timesec.eq.240.0) intsec=240
      if(timesec.eq.300.0) intsec=300
      write(15,211) intsec
  211 format("ONOFF caltype=hcorcal secs=",i3," loops=1 waitsecs=60",
     * " dop=each adjpwr=each newfile=1")


      nin=nin+1

      timenow=timenow+15.*(pairtime/60.)

      HAdeg_last=timenow-radeg
      call AZZA(HAdeg,Decdeg,azdeg_last,zadeg_last)

      go to 1


   98 write(*,'('' whatsadamattah? at '',i6,
     *     1x,a15)') agcnum,hipos
   99 write(*,'(''  nin '',i6)') nin
      STOP
      END

      include 'sub_azza.f'


     


