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
      PRINT *,' Enter name of input AGC file to check'
      READ(*,'(a60)') INFILE
      OPEN(10,FILE=INFILE,STATUS='OLD')
      OPEN(14,FILE='vopt.radec',STATUS='unknown')
      OPEN(15,FILE='v21.radec',STATUS='unknown')
      nrec=0
      ONEDEG=3.1415926536/180.
      VMAXI=-1000
      ramin=0.
      ramax=0.
      decmin=0.
      decmax=0.

      write(*,'('' Enter ramin, ramax in hours'')')
      write(*,'(''  For MKW 11, we use RA: 198-207 '')')
      write(*,'('' which translates to RA: 13.2-13.8 '')')
      write(*,'(''               and  Dec: 7-16 '')')
      read *,ramin,ramax
      write(*,'('' Enter decmin, decmax in degrees'')')
      read *,decmin,decmax 

      ngo=0     
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
      if(detcode.eq.0 .or. detcode.eq.2) go to 1


      rar=ra*15.*onedeg
      decr=dec*onedeg

      ngo=ngo+1

      if(vopt.ne.0) 
     *   WRITE(14,'(i6,1x,f9.4,1x,f9.4,1x,i5)') AGCNUMBER,ra,dec,vopt
      if(v21.ne.0) 
     *   WRITE(15,'(i6,1x,f9.4,1x,f9.4,1x,i5)') AGCNUMBER,ra,dec,v21




      GO TO 1
   98 write(*,'('' whatsadamattah?'')')
   99 write(*,'(''  galaxies    '',i7)') ngo
      STOP
      END
