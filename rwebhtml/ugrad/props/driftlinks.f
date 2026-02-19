C
C   Especially set up for working on ALFALFA tiles
C
      CHARACTER qu*1,gt*1,click1*13,click2*9,click3*10,
     *   click3_2*10,clickg*11
      CHARACTER a1*54,a2*5,a3*53,a4*5,a5*60,g1*53
      character b1*49,b2*23,b3*57,b4*51,b5*21
      character ps*3,pe*4,as*9,ae*4,bl*6,tt*11,comma*1
      character c1*53,c2*55,c3*50,ci*5,c4*62,c5*61,
     *          c6*58,c7*45,click4*3,plus*1,dot*1
      character d1*49,d2*23,d3*45,d4*51,d5*21,e3*46
      REAL RADEG
      INTEGER IRH,IRM,IRS10,IDD,IDM,IDS
      character dummy*1,ans*1,date*20
      real z,exab_r,petromag_r,petror90_r,C,VHEL
      integer nin,IHVEL
      CHARACTER INFILE*64

      CHARACTER SIGN*1
      INTEGER RAH,RAM,RAS10,DECD,DECM,DECS

      nin=0
      as(1:1)=char(60)
      as(2:8)='a href='
      as(9:9)=char(34)
      ae='</a>'
      ps='<p>'
      pe='</p>'
      QU=char(34)
      GT=char(62)
      click1='Explore ObjID'
      click2='CutOut0.4'
      bl(1:1)=char(38)
      bl(2:6)='nbsp '
      comma=','
      plus='+'
      dot='.'
      click3=   'SkyView.03'
      click3_2 ='DSS2red.03'
      click4='NED'
      clickg='DR3Navigate'

c         1234567890123456789012345678901234567890123456789012345678901234

      a1='http://cas.sdss.org/astro/en/tools/explore/obj.asp?ra='
      a2='&dec='
      a3='http://casjobs.sdss.org/ImgCutoutDR3/getjpeg.aspx?ra='
      g1='http://cas.sdss.org/astro/en/tools/chart/navi.asp?ra='

      a4='&dec='
      a5='&scale=0.39617&width=600&height=600&opt=GLST&query=SR(10,20)'
      tt=' target=new'
c         1234567890123456789012345678901234567890123456789012345678901234
      b1='http://skyview.gsfc.nasa.gov/cgi-bin/nnskcall.pl?'
      b2='Interface=bform&VCOORD='
      b3='&NWINDOW=on&SURVEY=Digitized+Sky+Survey&SCOORD=Equatorial'
      b4='&EQUINX=2000&MAPROJ=Gnomonic&SFACTR=0.03&GRIDDD=Yes'
      b5='&COLTAB=Stern+Special'

c         1234567890123456789012345678901234567890123456789012345678901234 
      c1='http://nedwww.ipac.caltech.edu/cgi-bin/nph-objsearch?'
      c2='search_type=Near+Position+Search&in_csys=Near+Position='
      c3='+Search&in_csys=Equatorial&in_equinox=J2000.0&lon='
      ci='&lat='
c     lon=10+44+02.1&lat=15+35+19
      c4(1:32)='&radius=10.0&out_csys=Equatorial'
      c4(33:62)='&out_equinox=J2000.0&obj_sort='
      c5='Distance+to+search+center&of=pre_text&zv_breaker=30000.0&list'
      c6='_limit=5&img_stamp=YES&z_constraint=Unconstrained&z_value1'
      c7='=&z_value2=&z_unit=z&ot_include=ANY&nmp_op=ANY'

c         1234567890123456789012345678901234567890123456789012345678901234
      d1='http://skyview.gsfc.nasa.gov/cgi-bin/nnskcall.pl?'
      d2='Interface=bform&VCOORD='
      d3='&NWINDOW=on&SURVEY=DSS2+Red&SCOORD=Equatorial'
      d4='&EQUINX=2000&MAPROJ=Gnomonic&SFACTR=0.03&GRIDDD=Yes'    
      d5='&COLTAB=Stern+Special'
c         1234567890123456789012345678901234567890123456789012345678901234
      e3='&NWINDOW=on&SURVEY=DSS2+Blue&SCOORD=Equatorial'

      g1='http://cas.sdss.org/astro/en/tools/chart/navi.asp?ra='

C  Make yourself a new file if you want; otherwise it will add on to others

      write(*,'('' Start a new SKYLINKS file?  y/n'')')
      read(*,'(a1)') ans
      if(ans.eq.'y' .or. ans.eq.'Y') then
         open(14,file='skylinks.html',status='unknown')
         call fdate(date)
         write(14,'(a20,a4)') date,pe        
         close(14)
      endif
 
 1    write(*,'('' Enter RA and Dec of central pixel '')')
      write(*,'('' hhmmsss+ddmmss '')')
      write(*,'('' enter 99 to exit '')')
      read(*,'(2i2.2,i3.3,a1,3i2.2)')
     *   rah,ram,ras10,sign,decd,decm,decs
      if(rah.eq.99) go to 99
     
      click2='CutOut0.4'
      click3=   'SkyView.03'
      click3_2 ='DSS2red.03'
      a5='&scale=0.39617&width=600&height=600&opt=GLST&query=SR(10,20)'
      b4='&EQUINX=2000&MAPROJ=Gnomonic&SFACTR=0.03&GRIDDD=Yes'
      d4='&EQUINX=2000&MAPROJ=Gnomonic&SFACTR=0.03&GRIDDD=Yes'

      ngo=ngo+1
 
      ra = real(rah) + real(ram)/60. + real(ras10)/36000.
      dec= real(decd)+ real(decm)/60.+ real(decs)/3600.
      if(sign.eq.'-') dec=-dec  
      radeg=ra*15.
      
      open(14,file='skylinks.html',status='old',access='append')

      write(14,198) bl,bl,
     *   RAH,RAM,RAS10,SIGN,
     *   DECD,DECM,DECS,bl,bl,RADEG,DEC,bl,bl
  198 FORMAT(2a6,2x,
     *   2I2.2,I3.3,A1,3I2.2,1x,2a6,1x,f8.4,1x,f9.4,2x,2a6)
      ras=real(ras10)/10.

      write(14,197) bl,bl,RADEG,DEC,bl,bl
 197  format(2a6,f8.4,2x,f9.5,a8,1x,2a6)
      write(*,199) RADEG,DEC
 199  format(f8.4,8x,f9.5)

      write(14,200)bl,bl,as,a1,RADEG,a2,DEC,QU,tt,gt,click1,ae,bl,bl
  200 format(2a6,a9,a54,f8.4,a5,f9.5,a1,a11,a1,a13,a4,2a6)

c      write(14,201) bl,bl,as,a3,RADEG,a4,DEC,a5,QU,tt,gt,click2,ae
  201 format(2a6,a9,a53,f8.4,a5,f9.5,a60,a1,a11,a1,a9,a4)
      a5='&scale=1.00000&width=600&height=600&opt=GLST&query=SR(10,20)'
      click2='CutOut1.0'
c      write(14,201) bl,bl,as,a3,RADEG,a4,DEC,a5,QU,tt,gt,click2,ae

      write(14,2011) bl,bl,as,g1,RADEG,a4,DEC,QU,tt,gt,clickg,ae
 2011 format(2a6,a9,a53,f8.4,a5,f9.5,"&opt=gli",a1,a11,a1,a11,a4)

      write(14,202) bl,bl,as,b1,b2,RADEG,comma,DEC,
     *      b3,b4,b5,QU,tt,gt,click3,ae
  202 format(2a6,a9,a49,a23,f8.4,a1,f9.5,
     *      a57,a51,a21,a1,a11,a1,a10,a4)
  204 format(2a6,a9,a49,a23,f8.4,a1,f9.5,
     *      a45,a51,a21,a1,a11,a1,a10,a4)
 2041 format(2a6,a9,a49,a23,f8.4,a1,f9.5,
     *      a46,a51,a21,a1,a11,a1,a10,a4)
      b4='&EQUINX=2000&MAPROJ=Gnomonic&SFACTR=0.10&GRIDDD=Yes'
      click3=   'SkyView.10'

      write(14,202) bl,bl,as,b1,b2,RADEG,comma,DEC,
     *      b3,b4,b5,QU,tt,gt,click3,ae
      write(14,204) bl,bl,as,d1,d2,RADEG,comma,DEC,
     *      d3,d4,d5,QU,tt,gt,click3_2,ae
      click3_2 ='DSS2blu.03'
      write(14,2041) bl,bl,as,d1,d2,RADEG,comma,DEC,
     *      e3,d4,d5,QU,tt,gt,click3_2,ae

      d4='&EQUINX=2000&MAPROJ=Gnomonic&SFACTR=0.10&GRIDDD=Yes'
      click3_2 ='DSS2red.10'
      write(14,204) bl,bl,as,d1,d2,RADEG,comma,DEC,
     *      d3,d4,d5,QU,tt,gt,click3_2,ae

      click3_2 ='DSS2blu.10'
      write(14,2041) bl,bl,as,d1,d2,RADEG,comma,DEC,
     *      e3,d4,d5,QU,tt,gt,click3_2,ae


      irs=int(ras)
      irsd=RAS10-irs*10

      write(14,203) bl,bl,as,c1,c2,c3,RAH,plus,RAM,plus,
     *      irs,dot,irsd,ci,sign,decd,plus,decm,plus,decs,
     *      c4,c5,c6,c7,QU,tt,gt,click4,ae,pe
 203  format(2a6,a9,a53,a55,a50,i2.2,a1,i2.2,a1,
     *      i2.2,a1,i1.1,a5,a1,i2.2,a1,i2.2,a1,i2.2,
     *      a62,a61,a58,a45,a1,a11,a1,a3,a4)


      close(14)
      go to 1
            
   99 STOP
      END
