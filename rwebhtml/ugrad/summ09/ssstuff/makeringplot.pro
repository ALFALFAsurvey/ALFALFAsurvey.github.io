pro makeringplot,grid,bigimg
;restore,'gridbf_10.8032+12.5022a.sav'
;restore,'bigimg.sav'
restore,'contparams.sav' ;these parameters came from makeoverlay.pro
z=znew 

window,/free,retain=2,xsize=816,ysize=816 ;this is about as big as you can make the window and still be able to see the whole thing on your screen
erase,color=255 ;makes the background white

;in case you are repeatedly running through these lines individually, these next 2 lines only need to be done the first time to set up the window appropriately:
contour, z, rahr,decdeg, xstyle=1, ystyle=1,xrange=[10.85,10.716667],yrange=[11.416667,13.416667],levels=c_levels,xtitle='!6 Right Ascension (J2000)',ytitle='Declination (J2000)',xtickn=textoidl([xlabels[6],xlabels[5],xlabels[4],xlabels[3],xlabels[2],xlabels[1],xlabels[0]]),ytickn=textoidl([ylabels[0],ylabels[1],ylabels[2],ylabels[3]]),ticklen=-0.015,background=255,color=1,/nodata,charsize=1.5
erase,color=255

;gather data on the plot size so that we know how big to make the image
PX = !X.WINDOW * !D.X_VSIZE  
PY = !Y.WINDOW * !D.Y_VSIZE 

resizedimg=congrid(alog10(bigimg),500,500) ;you can change the size of the image from 500 by 500 but this worked well for me

SZ = SIZE(resizedimg)
resizedimg= (-1.)*resizedImg ;invert!
loadct,0

TVSCL, resizedimg > (-1.98), PX[0], PY[0] 

;note if you are plotting white on black this line will look more like:
;tvscl,resizedimg < 1.9, PX[0], PY[0]
;1.9 was a value that worked well with this particular image. if all the images are downloaded from MOSAIC, hopefully the scaling will be similar among them but we may have to look into this.

contour, z, rahr,decdeg, xstyle=1, ystyle=1,position=[PX[0],PY[0],PX[0]+SZ[1]-1,PY[0]+SZ[2]-1],xrange=[10.85,10.716667],yrange=[11.416667,13.416667],levels=c_levels,xtitle='!6 Right Ascension (J2000)',ytitle='Declination (J2000)',xtickn=textoidl([xlabels[6],xlabels[5],xlabels[4],xlabels[3],xlabels[2],xlabels[1],xlabels[0]]),ytickn=textoidl([ylabels[0],ylabels[1],ylabels[2],ylabels[3]]),ticklen=-0.015,background=255,color=1,/noerase,/device,charsize=1.5

phi=findgen(32)*(!PI*2/32.)
usersym,cos(phi),sin(phi)
;we want to overplot the beam size
oplot,[0.,10.8333],[0.,11.75],psym=8,symsize=2.2,color=1
xyouts,10.84,11.64,'Beam',color=1,charsize=1.7

;here i plot dots for the optical galaxies identified within the Ring
usersym,cos(phi),sin(phi),/fill
;ringdetsRA=[10.775000,10.778139,10.781167,10.783556,10.812028,10.831167]
;ringdetsDEC=[11.755556,12.326944,12.744167,12.959444,12.315278,13.161667]
ringdetsRA=[10.775000,10.778139,10.781167,10.782583,10.783556,10.788917]
ringdetsDEC=[11.755556,12.326944,12.744167,12.998056,12.959444,12.387500]
oplot,ringdetsRA,ringdetsDEC,psym=8,symsize=1.5,color=1

;LABEL LARGE OPTICAL GALAXIES
xyouts,10.803,11.77,'M96',color=1,charsize=1.7
xyouts,10.74,11.9,'N3351',color=1,charsize=1.7
xyouts,10.795,12.5,'M105',color=1,charsize=1.7
xyouts,10.82,12.7,'N3384',color=1,charsize=1.7

;LABEL GALAXIES NOTED BY KK04 THAT ARE IN RING
xyouts,10.768,11.65,'202026',color=1,charsize=1.7
oplot,[10.768,10.775000],[11.66,11.755556],color=1,thick=1.5
xyouts,10.773,12.31,'202027',color=1,charsize=1.7
xyouts,10.774,12.744,'201970',color=1,charsize=1.7
oplot,[10.781167,10.774],[12.744167,12.75],color=1,thick=1.5
xyouts,10.778,12.91,'201975',color=1,charsize=1.7
oplot,[10.783556,10.778],[12.959444,12.93],color=1,thick=1.5

;LABEL OTHER GALAXIES THAT ARE IN RING
xyouts,10.781,12.998056,'201972',color=1,charsize=1.7
xyouts,10.77,12.387500,'205505',color=1,charsize=1.7
oplot,[10.788917,10.77],[12.387500,12.41],color=1,thick=1.5


end
;fyi: a quick and easy way to get a jpg of whatever is on the screen:
;response=tvread(filename='optimusprime2',/JPEG,quality=100,/nodialog)
