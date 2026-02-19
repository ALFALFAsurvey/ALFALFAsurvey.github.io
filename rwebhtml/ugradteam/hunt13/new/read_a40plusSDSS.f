C
C
      INTEGER AGC
      REAL RA_opt,Dec_opt,Dist,V_cmb,logM_HI,
     *   ModelMag_g,ModelMag_i,PetroMag_g,PetroMag_i,
     *   Gext_g,Gext_i,Iext_g,Iext_i,M_V,M0_V,
     *   expAB_g,expAB_i,expRad_g,expRad_i,
     *   petroR50_i,petroR90_i,isoA_i,deVRad_g,deVRad_i,
     *   lnLStar_i,lnLexp_i,lnLDeV_i

      open(10,file='a40.plusSDSS.txt',status='old')
      open(14,file='junk',status='unknown')

      ngo=0

    1 read(10,*,end=99) AGC,RA_opt,Dec_opt,Dist,V_cmb,logM_HI,
     *   ModelMag_g,ModelMag_i,PetroMag_g,PetroMag_i,
     *   Gext_g,Gext_i,Iext_g,Iext_i,M_V,M0_V,
     *   expAB_g,expAB_i,expRad_g,expRad_i,
     *   petroR50_i,petroR90_i,isoA_i,deVRad_g,deVRad_i,
     *   lnLStar_i,lnLexp_i,lnLDeV_i

      write(*,300) AGC,RA_opt,Dec_opt,Dist,V_cmb,logM_HI,
     *   ModelMag_g,ModelMag_i,PetroMag_g,PetroMag_i,
     *   Gext_g,Gext_i,Iext_g,Iext_i,M_V,M0_V,
     *   expAB_g,expAB_i,expRad_g,expRad_i,
     *   petroR50_i,petroR90_i,isoA_i,deVRad_g,deVRad_i,
     *   lnLStar_i,lnLexp_i,lnLDeV_i
 300  format(i6,1x,27e8.2)

      ngo=ngo+1
      go to 1

   99 write(*,'(''  galaxies    '',i7)') ngo

      STOP
      END
