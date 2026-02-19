C
C
      INTEGER AGC
      REAL RA_opt,Dec_opt,Dist,V_cmb,logM_HI,
     *   ModelMag_g,ModelMag_i,PetroMag_g,PetroMag_i,
     *   Gext_g,Gext_i,Iext_g,Iext_i,M_V,M0_V,
     *   expAB_g,expAB_i,expRad_g,expRad_i,
     *   petroR50_i,petroR90_i,isoA_i,deVRad_g,deVRad_i,
     *   lnLStar_i,lnLexp_i,lnLDeV_i
      CHARACTER COMMA*1
      REAL*8 ONEDEG,SEP,RA,RAR,DEC,DECR,SEARCHRADIUS,
     *  cRAdeg,cDEC,cRAR,cDECR,SEPMIN,SEPDEG,SEPSEC,
     *  RADEG
      PARAMETER (ONEDEG=3.1415927/180.)     

      open(10,file='a40.plusSDSS.txt',status='old')
      open(14,file='junk',status='unknown')

      ngo=0

      comma=','
c      write(*,'('' For MKW11 use 1329312+114719'')')
c      write(*,'('' 202.38000    11.78861    6850 '')')
      cradeg=202.38000
      cdec=11.78861 
      crar=cradeg*onedeg
      cdecr=cdec*onedeg

    1 read(10,*,end=99) AGC,RA_opt,Dec_opt,Dist,V_cmb,logM_HI,
     *   ModelMag_g,ModelMag_i,PetroMag_g,PetroMag_i,
     *   Gext_g,Gext_i,Iext_g,Iext_i,M_V,M0_V,
     *   expAB_g,expAB_i,expRad_g,expRad_i,
     *   petroR50_i,petroR90_i,isoA_i,deVRad_g,deVRad_i,
     *   lnLStar_i,lnLexp_i,lnLDeV_i

      radeg=ra_opt
      dec=dec_opt

      ximag=PetroMag_i-Gext_i-Iext_i
      write(*,'(2f7.2)') ximag,PetroMag_i
      AbsMag_i = ximag + 5. - 5.*(alog10(Dist*1.0E+06))

c      rar=radeg*onedeg
c      decr=dec*onedeg
c      call cartes(rar,crar,decr,cdecr,sep)
c      sepdeg=sep/onedeg
c      sepmin=sepdeg*60.

c      if(sepdeg.ge.6.) go to 1


c    MSun-Mgal
c    M(Sun) V = +4.83 
      diffmag= (+4.83 - M0_V)
      xlumin=10.**(diffmag/2.5)
      xlogL=alog10(xlumin)
      gas2L=logM_HI-xlogL
   
c    M(Sun) i = 4.58
      diffmagi = (+4.58 - AbsMag_i)
      xluminI=10.**(diffmagI/2.5)
      xlogLI=alog10(xluminI)
      gas2LI=logM_HI-xlogLI

      
      write(14,300) AGC,comma,RA_opt,comma,Dec_opt,comma,
     *   Dist,comma, V_cmb, comma,
     *   xlogL,comma,logM_HI,comma,gas2L,comma,AbsMag_i,
     *   comma,xlogLI,comma,gas2LI
  300 format(i6,a1,f8.4,a1,f7.3,a1,f5.1,a1,f6.0,
     *   a1,f5.2,a1,f5.2,a1,f7.4,
     *   a1,f6.2,a1,f7.4,a1,f7.4)

      ngo=ngo+1
      go to 1

   99 write(*,'(''  galaxies    '',i7)') ngo

      STOP
      END
