      PROGRAM READAGC
C
C   Reads the current version of AGC21 and checks statistics
C    UPDATED FOR 1991 VERSIONS
C
      CHARACTER INFILE*60
      CHARACTER DESCRIPTION*8,NGCIC*8,WHICH*1,TELCODE*1,WIDTHCODE*4,
     *  SIGN*1
      CHARACTER COM*1
      INTEGER AGCNUMBER,RAH,RAM,RAS10,DECD,DECM,DECS,
     *  A100,B100,MAG10,INCCODE,POSANG,BSTEINTYPE,
     *  VOPT,VERR,EXTRC3,EXTDIRBE,VSOURCE,
     *  FLUX100,RMS100,V21,WIDTH,WIDTHERR,
     *  DETCODE,HISOURCE,STATUSCODE,SNRATIO,
     *  IBANDQUAL,IBANDSRC,IRASFLAG,ICLUSTER,HIDATA,
     *  IPOSITION,IPALOMAR,RC3FLAG,IROTCAT,NEWSTUFF,NCLU(101)
      REAL RASS,vhelagc,vhelopt,zmag
      PRINT *,' Enter name of input AGC file'
      READ(*,'(a60)') INFILE
      OPEN(10,FILE=INFILE,STATUS='OLD')
      OPEN(14,FILE='junk.csv',STATUS='unknown')
      nrec=0
      ONEDEG=3.1415926536/180.
      com=','

C   for the csv file, first line indicates what it contains
C
      write(14,'(''AGCnr,which,radeg,decdeg,a,b,zmag,'',
     *  ''vopt,hiflux,rms,v21,width,widtherr,snr,hisrc,vhelagc'')')
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

      rahrs=real(rah)+real(ram)/60.+real(ras10)/36000.
      radeg=rahrs*15.
      decdeg=real(decd)+real(decm)/60.+real(decs)/3600.
      if(sign.eq.'-') decdeg=-decdeg

C
C  get bluedisks sample only
C

      vel=real(vopt)
      zed=vel/299796.

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

      vhelagc=real(vopt)
      vhelopt=real(vopt)
      if(v21.ne.0 .and. detcode.ne.0 .and. detcode.ne.2) 
     *    vhelagc=real(v21)
      
      write(14,110) AGCNUMBER,com,which,com,
     * radeg,com,decdeg,com,a,com,b,com,zmag,com,
     * vhelopt,com,hiflux,com,rms,com,real(v21),com,real(width),com,
     * real(widtherr),com,snr,com,hisource,com,vhelagc
  110 format(i6,a1,a1,a1,f9.5,a1,f9.5,a1,f6.2,a1,f5.2,a1,f4.1,a1,
     * f6.0,a1,f6.2,a1,f5.1,a1,f6.0,a1,f4.0,a1,
     * f3.0,a1,f4.1,a1,i2,a1,f7.1)

     


      GO TO 1
   98 write(*,'('' whatsadamattah?'')')
   99 write(*,'(''  galaxies    '',5i7)') ngo,npal,nvogt,ndd,nkpj
      STOP
      END
