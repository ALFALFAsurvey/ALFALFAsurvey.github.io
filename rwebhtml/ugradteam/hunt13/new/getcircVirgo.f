C
C   Reads the 1991 AGC style catalog and finds objects within a certain distance
C   from a specified position on the sky using the routine CARTES
C
C
      CHARACTER WHICH*1,SIGN*1,DESCRIPTION*8,NGCIC*8,WIDTHCODE*4
      CHARACTER TELCODE*1,SGN*1,TFNOTE*1, COMMA*1
      INTEGER AGCNUMBER,RAH,RAM,RAS10,DECD,DECM,DECS,A100,B100,MAG10,
     *        INCCODE,POSANG,BSTEINTYPE,VOPT,VERR,
     *        EXTRC3,EXTDIRBE,VSOURCE,FLUX100,
     *        RMS100,V21,WIDTH,WIDTHERR,DETCODE,
     *        HISOURCE,STATUSCODE,SNRATIO,NEWSTUFF,
     *        IRASFLAG,ICLUSTER,HIDATA,IPOSITION,IPALOMAR,
     *        RC3FLAG,IROTCAT
      REAL VELMIN,VELMAX
      REAL*8 ONEDEG,SEP,RA,RAR,DEC,DECR,SEARCHRADIUS,
     *  XRA,XDEC,XRAR,XDECR,SEPMIN,SEPDEG,SEPSEC,
     *  XRADEG,RADEG
      PARAMETER (ONEDEG=3.1415927/180.)

      print *, ' writes to file junk'
      open(14,file='junk',status='unknown') 
      open(15,file='vopt.radec',status='unknown') 
      open(16,file='v21.radec',status='unknown') 
      nsamp=0
         
      print *,' Output format: AGC(0) or short (1)'
      read *,nformat

      write(*,'('' Enter center position as:  hhmmsssSddmmss '')')
      write(*,'('' For Virgo use NED position '')')
      write(*,'(''  186.634    12.723  '')')
         
      xradeg=186.634
      xdec=12.723
      xrar=xradeg*onedeg
      xdecr=xdec*onedeg

      searchradius=7.5
  
      velmin=-999.
      velmax=18000.

      comma=','
   
      mindec=0 
      minra=0

      open(10,file='/home/rutados/haynes/cats/agc2000.north',
     *   status='old')

c
   1  READ(10,125,end=99,err=98) AGCNUMBER,WHICH,RAH,RAM,RAS10,
     *             SIGN,DECD,DECM,DECS,
     *             A100, B100, MAG10, INCCODE, POSANG, DESCRIPTION,
     *             BSTEINTYPE, VOPT, VERR, EXTRC3,
     *             EXTDIRBE,VSOURCE,NGCIC,FLUX100, RMS100,
     *             V21,WIDTH,WIDTHERR,WIDTHCODE,TELCODE,
     *             DETCODE,HISOURCE,STATUSCODE,SNRATIO,
     *             IBANDQUAL,IBANDSRC,IRASFLAG,ICLUSTER,HIDATA,
     *             IPOSITION,IPALOMAR,RC3FLAG,IROTCAT,NEWSTUFF
  125 FORMAT(I6,A1,2I2.2,I3.3,A1,3I2.2,I5,2I4,I2,I3,A8,I3,I6,I3,
     * 2I5,I3,A8,I5,I4,I5,I4,I2,A4,A1,i1,I2,I1,i3,i1,i2,i1,
     * I2,5I1,I2)
      nrec=nrec+1
      ngal=ngal+1

      vel=vopt
      if(v21.ne.0 .and. detcode.ne.0 .and. detcode.ne.2)
     *    vel=v21
      if(velmin.ne.-999 .and. vel.eq.0) go to 1
      if(vel.lt.velmin .or. vel.gt.velmax) go to 1
c
      if(rah.gt.13) go to 99
      if(rah.lt.11) go to 1
      if(decd.gt.20) go to 1

      ra = real(rah) + real(ram)/60. + real(ras10)/36000.
      dec= real(decd)+ real(decm)/60.+ real(decs)/3600.
      if(sign.eq.'-') dec=-dec
      radeg=ra*15.
      rar=radeg*onedeg
      decr=dec*onedeg

      call cartes(rar,xrar,decr,xdecr,sep)
      sepdeg=sep/onedeg
      sepmin=sepdeg*60.
      write(*,'(i6,4f9.4)') agcnumber,ra,dec,sepdeg
      if(sepdeg.ge.searchradius) go to 1

      TFNOTE='*'
      if(detcode.eq.0.and.hisource.ge.50.and.ipalomar.eq.0) TFNOTE=' '
      if(ibandsrc.eq.0) TFNOTE=' '
      if(ibandqual.eq.9 .or.ibandqual.eq.7) TFNOTE=' '
      if(bsteintype.lt.100 .or.bsteintype.gt.305) TFNOTE=' '
      if(bsteintype.gt.175 .and.bsteintype.lt.300) TFNOTE=' '
      if(a100.lt.50 .or. b100.eq.0)  TFNOTE=' '
      ratio=1.0
      if(a100.ne.0 .and. b100.ne.0) ratio=real(b100)/real(a100)
      if(ratio.gt.0.8)  TFNOTE=' '

      if(v21.eq.0 .and. vopt.eq.0) go to 1
      if(vopt.eq.0 .and. (detcode.eq.0 .or. detcode.eq.2)) go to 1

      nsamp=nsamp+1
      continue
      if(nformat.eq.0)         
     *   WRITE (14,125) AGCNUMBER,WHICH,RAH,RAM,RAS10,
     *             SIGN,DECD,DECM,DECS,
     *             A100,B100,MAG10,INCCODE,POSANG,DESCRIPTION,
     *             BSTEINTYPE,VOPT,VERR,EXTRC3,
     *             EXTDIRBE,VSOURCE,NGCIC,FLUX100,RMS100,
     *             V21,WIDTH,WIDTHERR,WIDTHCODE,TELCODE,
     *             DETCODE,HISOURCE,STATUSCODE,SNRATIO,
     *   IBANDQUAL,IBANDSRC,IRASFLAG,ICLUSTER,HIDATA,
     *   IPOSITION,IPALOMAR,NEWSTUFF
      if(nformat.eq.1) 
     *     WRITE(14,101) AGCNUMBER,WHICH,NGCIC,RAH,RAM,RAS10,
     *       SIGN,DECD,DECM,DECS,A100,B100,MAG10,BSTEINTYPE,
     *       VOPT,VSOURCE,FLUX100,RMS100,
     *       V21,WIDTH,WIDTHCODE,TELCODE,DETCODE,HISOURCE,
     *       IBANDQUAL,IBANDSRC,POSANG,IPOSITION,ipalomar,TFNOTE,
     *       sepmin
  101 FORMAT(I6,A1,A8,1x,2I2.2,I3.3,A1,3I2.2,I5,2I4,i6,2x,I5,I3,2x,
     *       I5,I4,I5,I4,1x,A4,A1,i1,I2,2i3,i5,2i3,a1,f6.2)

      if(vopt.ne.0) 
     *  write(15,300) 
     *  AGCNUMBER,comma,radeg,comma,dec,comma,vopt,comma,sepmin
      if(v21.ne.0)
     *  write(16,300) 
     *  AGCNUMBER,comma,radeg,comma,dec,comma,v21,comma,sepmin
  300 format(i6,a1,f8.4,a1,f7.4,a1,i5,a1,f8.4)

      GO TO 1
   99 write(*,'('' Number in this sample:'',i7)') nsamp
      STOP
   
   98 write(*,'('' So whatsada matta already?'')') 
      write(*,'(i7)') nrec
      STOP      
      END
