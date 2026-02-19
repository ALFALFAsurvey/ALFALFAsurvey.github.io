      PROGRAM READAGC
C
C   Reads the current version of AGC21 and checks statistics
C    UPDATED FOR 1991 VERSIONS
C
      CHARACTER INFILE*60
      CHARACTER DESCRIPTION*8,NGCIC*8,WHICH*1,TELCODE*1,WIDTHCODE*4,
     *  SIGN*1
      CHARACTER WHICH1*2,TELCODE1*2
      CHARACTER COM*1
      INTEGER AGCNUMBER,RAH,RAM,RAS10,DECD,DECM,DECS,
     *  A100,B100,MAG10,INCCODE,POSANG,BSTEINTYPE,
     *  VOPT,VERR,EXTRC3,EXTDIRBE,VSOURCE,
     *  FLUX100,RMS100,V21,WIDTH,WIDTHERR,
     *  DETCODE,HISOURCE,STATUSCODE,SNRATIO,
     *  IBANDQUAL,IBANDSRC,IRASFLAG,ICLUSTER,HIDATA,
     *  IPOSITION,IPALOMAR,RC3FLAG,IROTCAT,NEWSTUFF,NCLU(101)
      REAL RASS,vhelagc,vhelopt,zmag,snr,hiflux
      REAL rv21,rwidth,rwidtherr

      PRINT *,' This makes only short version but for PPS'
      PRINT *,' Enter name of input AGC file'
      READ(*,'(a60)') INFILE
      OPEN(10,FILE=INFILE,STATUS='OLD')
      OPEN(14,FILE='junk.csv',STATUS='unknown')
      nrec=0
      ONEDEG=3.1415926536/180.
      com=','
      WHICH1(1:2)='""'
      TELCODE1(1:2)='""'
      ngo=0

C   for the csv file, first line indicates what it contains
C
      write(14,'(''AGCnr,radeg,decdeg,a,b,zmag,'',
     *  ''vopt,hiflux,rms,v21,width,widtherr,snr,hisrc,vhelagc,'',
     *  '' rawrap'')')
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
c

      ngo=ngo+1

C
C  Restrict to PPS in broadest terms
C
      if(v21.gt.12000 .or. vopt.gt.12000) go to 1
      if(rah.gt.3 .and. rah.lt.21) go to 1
      if(decd.gt.50) go to 1
      if(decd.lt.20) go to 1
      if(vopt.eq.0 .and. v21.eq.0) go to 1
      if(vopt.eq.0 .and. detcode.eq.2) go to 1
      if(NGCIC(1:8).eq.'HIdetHVC') go to 1

      rahrs=real(rah)+real(ram)/60.+real(ras10)/36000.
      radeg=rahrs*15.
      decdeg=real(decd)+real(decm)/60.+real(decs)/3600.
      if(sign.eq.'-') decdeg=-decdeg


      a=0.
      b=0.
      zmag=0.
      if(a100.gt.0) a=real(a100)/100.
      if(b100.gt.0) b=real(b100)/100.
      if(mag10.gt.0) zmag=real(mag10)/10.

      hiflux=0.
      rms=0.
      snr=0.
      if(flux100.gt.0) hiflux=real(flux100)/100.
      if(rms100.gt.0) rms=real(rms100)/100.
      if(snratio.gt.0) snr=real(snratio)/10.

      vhelagc=0.
      vhelopt=0.
      if(vopt.ne.0) then
           vhelopt=real(vopt)
           vhelagc=vhelopt
      endif
 
      if(v21.ne.0 .and. detcode.ne.0 .and. detcode.ne.2
     *    .and. detcode.ne.6) 
     *    vhelagc=real(v21)

      rv21=0.
      if(v21.ne.0) rv21=real(v21)
      rwidth=0.
      if(width.ne.0) rwidth=real(width)
      rwidtherr=0.
      if(widtherr.ne.0) rwidtherr=real(widtherr)

      if(vhelagc.gt.999999. .or. vhelopt.gt.999999. 
     *  .or. rv21.gt.99999. .or. rwidth.gt.9999.)
     *  write(*,'(''error writing '',i6)') agcnumber
      
      if(vhelagc.eq.0) go to 1
      vhelagc=vhelagc+0.0001
      rawrap=radeg
      if(radeg.gt.180.) rawrap=radeg-360.

      dist=vhelagc/70.
      
      write(14,110) AGCNUMBER,com,
     * radeg,com,decdeg,com,a,com,b,com,zmag,com,
     * vhelopt,com,hiflux,com,rms,com,rv21,com,rwidth,com,
     * rwidtherr,com,snr,com,hisource,com,vhelagc,com,rawrap
  110 format(i6,a1,f10.6,a1,f10.6,a1,f6.2,a1,f5.2,a1,f4.1,a1,
     * f7.1,a1,f6.2,a1,f5.1,a1,f7.1,a1,f6.1,a1,
     * f3.0,a1,f4.1,a1,i2,a1,f7.1,a1,f11.6)     



      GO TO 1
   98 write(*,'('' whatsadamattah?'')')
   99 write(*,'(''  galaxies    '',5i7)') ngo,npal,nvogt,ndd,nkpj
      STOP
      END
