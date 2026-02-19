pro makeoverlay,grid
;input should be the restored grid which you get from:
;IDL> restore,'gridbf_10.8032+12.5022a.sav'

;FIRST SET UP THE CONTOUR LEVELS YOU WILL USE FOR THE PLOT
;Average the polarizations
z=reform((grid.d[*,0,*,*]+grid.d[*,1,*,*])/2.)

;Zoom in to the area of interest
chanmin=430.
chanmax=495.
channelrange=(chanmax-chanmin)+1.

;Determine the contour values (i.e. find where the emission peaks in the velocity range specified by the channel ranges entered above)
peaks=fltarr(n_elements(z[0,*,0]),n_elements(z[0,0,*]))
locatepeaks=fltarr(n_elements(z[0,*,0]),n_elements(z[0,0,*]))
for i=0,n_elements(z[0,*,0])-1. do begin
    for j=0,n_elements(z[0,0,*])-1. do begin
        peaks[i,j]=max(z[chanmin:chanmax,i,j],spot)
        locatepeaks[i,j]=spot
    endfor
endfor
flevels=.1*peaks ;we will be searching for when the signal drops to 10 percent of the peak
lowlefts=fltarr(n_elements(z[0,*,0]),n_elements(z[0,0,*]))
lowrights=fltarr(n_elements(z[0,*,0]),n_elements(z[0,0,*]))
for i=0,n_elements(z[0,*,0])-1. do begin
    for j=0,n_elements(z[0,0,*])-1. do begin    
        lowl=locatepeaks[i,j]+chanmin
        repeat lowl=lowl-1. until z[lowl,i,j] le flevels[i,j]
        lowr=locatepeaks[i,j]+chanmin
        repeat lowr=lowr+1. until z[lowr,i,j] le flevels[i,j]
        lowlefts[i,j]=lowl
        lowrights[i,j]=lowr
    endfor
endfor

znew=fltarr(n_elements(z[0,*,0]),n_elements(z[0,0,*]))
for i=0,n_elements(z[0,*,0])-1. do begin
    for j=0,n_elements(z[0,0,*])-1. do begin    
        znew[i,j]=reform(total(z[lowlefts[i,j]:lowrights[i,j],i,j],1))/(lowrights[i,j]-lowlefts[i,j])
    endfor
endfor 

;Get the ra and dec for the axes
velocity=grid.velarr[chanmin:chanmax]
rah=grid.ramin+(dindgen(n_elements(grid.d[0,0,*,0]))+0.5)*grid.deltara/3600.
dec=grid.decmin+(dindgen(n_elements(grid.d[0,0,0,*]))+0.5)*grid.deltadec/(60.)
;rah and dec are for the whole grid, so in the next few lines, we "zoom in" to the area of interest
rahr=rah[0:117]
decdeg=dec[8:125]
znew=znew[0:117,8:125]

;picking the contour levels that you want to plot is not obvious - if you don't go low enough, you miss smaller structures, but if you go too low, the plot looks a mess. the c_levels we specify here are a good first guess, but you should play with these values to get something that looks right
rms=stddev(znew)
;first guess:
c_levels=rms*(dindgen(20)+1)
;what I finally chose:
c_levels=[4.,5.,9.,18.,32.,44.,50.]
print,c_levels

n_levels=rms*[-2.0, -1.0]

;the x and y labels for the axes can be pulled directly from the rah and dec arrays you set up earlier. Here I know what I want them to be so I hardwire them in.
xlabels=['43.2^m','44.4^m','45.6^m','46.8^m','48.0^m','49.2^m','10^h50.4^m']
ylabels=['11^o30^{\prime}','12^o00^{\prime}','12^o30^{\prime}','13^o00^{\prime}']

save,znew,rahr,decdeg,c_levels,xlabels,ylabels,filename='contparams.sav'


end

