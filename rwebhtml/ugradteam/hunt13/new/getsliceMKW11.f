      PROGRAM READAGC
C
C   Reads the current version of AGC21 and checks statistics
C    UPDATED FOR 1991 VERSIONS
C
      CHARACTER INFILE*60
      CHARACTER DESCRIPTION*8,NGCIC*8,WHICH*1,TELCODE*1,WIDTHCODE*4,
     *  SIGN*1
      INTEGER AGCNUMBER,RAH,RAM,RAS10,DECD,DECM,DECS,
     *  A100,B100,MAG10,INCCODE,POSANG,BSTEINTYPE,
     *  VOPT,VERR,EXTRC3,EXTDIRBE,VSOURCE,
     *  FLUX100,RMS100,V21,WIDTH,WIDTHERR,
     *  DETCODE,HISOURCE,STATUSCODE,SNRATIO,
     *  IBANDQUAL,IBANDSRC,IRASFLAG,ICLUSTER,HIDATA,
     *  IPOSITION,IPALOMAR,RC3FLAG,IROTCAT,NEWSTUFF,NCLU(101)
      REAL RASS
      CHARACTER COMMA*1
      REAL*8 ONEDEG,SEP,RA,RAR,DEC,DECR,SEARCHRADIUS,
     *  XRA,XDEC,XRAR,XDECR,SEPMIN,SEPDEG,SEPSEC,
     *  XRADEG,RADEG
      PARAMETER (ONEDEG=3.1415927/180.)

      PRINT *,' Enter name of input AGC file to check'
      READ(*,'(a60)') INFILE
      OPEN(10,FILE=INFILE,STATUS='OLD')
      OPEN(14,FILE='vopt.slice',STATUS='unknown')
      OPEN(15,FILE='v21.slice',STATUS='unknown')
      nrec=0
      VMAXI=-1000
      ramin=0.
      ramax=0.
      decmin=0.
      decmax=0.

      write(*,'('' get a slice from 7.5 to 16.5'')')
      write(*,'('' of 5 degrees centered on +13.5'')')
      ramax=247.5/15.
      ramin=112.5/15.
      decmin=11.
      decmax=16.

      ngo=0     
      comma=','
c
c    
    1 READ(10,125,end=99,err=98) AGCNUMBER,WHICH,
     *  RAH,RAM,RAS10,SIGN,DECD,DECM,DECS,
     *  A100,B100,MAG10,INCCODE,POSANG,DESCRIPTION,BSTEINTYPE,
     *  VOPT,VERR,EXTRC3,EXTDIRBE,VSOURCE,NGCIC,
     *  FLUX100,RMS100,V21,WIDTH,WIDTHERR,WIDTHCODE,TELCODE,
     *  DETCODE,HISOURCE,STATUSCODE,SNRATIO,
     *  IBANDQUAL,IBANDSRC,IRASFLAG,ICLUSTER,HIDATA,
     *  IPOSITION,IPALOMAR,RC3FLAG,IROTCAT,NEWSTUFF
  125 FORMAT(I6,A1,2I2.2,I3.3,A1,3I2.2,I5,2I4,I2,I3,A8,I3,I6,I3,
     *      2I5,I3,A8,I5,I4,I5,I4,I2,A4,A1,i1,I2,I1,I3,I1,I2,I1,
     *  I2,5I1,I2)

      ra = real(rah) + real(ram)/60. + real(ras10)/36000.
      dec= real(decd)+ real(decm)/60.+ real(decs)/3600.
      if(sign.eq.'-') dec=-dec
      if(ra.lt.ramin .or. dec.lt.decmin 
     *   .or. dec.gt.decmax) go to 1
      if(ra.gt.ramax) go to 99

      if(vopt.eq.0 .and. v21.eq.0) GO TO 1
      if(vopt.gt.18000 .or. v21.gt.18000) go to 1
      if(vopt.eq.0 .and. (detcode.eq.0 .or. detcode.eq.2)) go to 1

      rar=ra*15.*onedeg
      decr=dec*onedeg
      radeg=ra*15.

c      call cartes(rar,crar,decr,cdecr,sep)
c      sepdeg=sep/onedeg
c      sepmin=sepdeg*60.

      if(vopt.gt.0) then
         cent=180.
         rad0=radeg-cent
         rad90=90.-rad0
         rad90r=rad90*onedeg
         radial=real(vopt)
         x=radial*cos(rad90r)
         y=radial*sin(rad90r)
         WRITE(14,300) AGCNUMBER,comma,radeg,comma,dec,comma,vopt,comma,
     *   x,comma,y
  300 format(i6,a1,f8.4,a1,f7.4,a1,i5,a1,f11.4,a1,f11.4)
      endif

      if(v21.gt.0 .and. HISOURCE.eq.75) then
         cent=180.
         rad0=radeg-cent
         rad90=90.-rad0
         rad90r=rad90*onedeg
         radial=real(v21)
         x=-1.*radial*cos(rad90r)
         y=radial*sin(rad90r)
         WRITE(15,300) AGCNUMBER,comma,radeg,comma,dec,comma,v21,comma,
     *   x,comma,y
       endif



      GO TO 1
   98 write(*,'('' whatsadamattah?'')')
   99 write(*,'(''  galaxies    '',i7)') ngo
C
C  cluster coordinates
C
         cent=180.
         rad0=202.38-cent
         rad90=90.-rad0
         rad90r=rad90*onedeg
         radial=real(6850)
         x=radial*cos(rad90r)
         y=radial*sin(rad90r)
         WRITE(*,'(2f13.4)') x,y   

      STOP
      END
