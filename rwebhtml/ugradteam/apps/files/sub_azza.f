C
C
      SUBROUTINE AZZA(HAdeg,Decdeg,azdeg,zadeg)

      real HAdeg,Decdeg,ONEDEG,AOLATDEG,
     *  HArad,Decrad,AOlatrad,sinalt,
     *  altrad,altdeg,cosA,A,adeg,azdeg,zadeg

      ONEDEG=3.1415926536/180.
      AOLATDEG=18.+(20./60.)+(36.6/3600.)

      HArad=HAdeg*ONEDEG
      aolatrad=AOLATDEG*ONEDEG
      Decrad=Decdeg*ONEDEG

      sinalt=(sin(decrad)*sin(aolatrad)) +
     *     (cos(decrad)*cos(aolatrad)*cos(HArad))
      altrad=asin(sinalt)
      altdeg=altrad/ONEDEG

      cosA=(sin(decrad) - (sin(altrad)*sin(aolatrad)))/
     *     (cos(altrad)*cos(aolatrad))
      a = acos(cosA)
      adeg=a/ONEDEG
      if(sin(HArad) .lt. 0) then
           azdeg=adeg
           else
           azdeg=360.-adeg
      endif
      zadeg=90.-altdeg

      RETURN
      END
      
