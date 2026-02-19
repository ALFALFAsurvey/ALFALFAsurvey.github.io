;+
; NAME:
;      AGCBTEST
; PURPOSE:
;       IDL Browser for the EGG Arecibo Galaxy Catalog.  RG, MPH
;       THIS IS A TEST VERSION
;
; EXPLANATION:
;       agcbtest reads in the entire AGC from file agctotal.sav.  The
;       user can call up a single galaxy from the command line or the
;       interface. The user can also search a coordinate position
;       within a specified radius.  The "search radius" is also used
;       in the single galaxy query, specifying the limits on the
;       skyplot range in the lower left hand window display.  The full
;       sky window identifies where the galaxy chosen is on an aitoff
;       projection with all other galaxies from the catalog.
;
;       If a coordinate search is performed, a list of candidates are
;       displayed in the search result window.  The user may then
;       click on a galaxy.  The DSS image of that galaxy is displayed,
;       and the skyplot is updated and centered on that galaxy, within
;       the current range of the search radius.
;       
;
; SYNTAX:
;       agcbtest, agc=agc
;
;
; OPTIONAL INPUT KEYWORD:
;
;          AGC:  display a galaxy profile from startup, if desired.
;
; OUTPUTS:
;       none
;
;
; RESTRICTIONS:
;
;       As of now, name resolver is only for agc/ugc number.  Browser
;       will slow down as search radius increases and a galaxy is
;       selected because the DSS image download takes longer.
;
; EXAMPLE:
;
;       View Virgo A!  (aka M87) via:
;                                      agcbtest, agc=7654
;
; PROCEDURES USED:
;         DSSQUERY, GSFC IDL USER'S LIBRARY
;
;         HOR.  See pjp AO library
;         VER.  See pjp AO library
;
; MODIFICATION HISTORY:
;       WRITTEN, B. Kent, Cornell U.,  June 17, 2005,  IDL 6.0
;                June 18, 2005:   Changed so DSS image is same scale
;                as sky plot.
;
;       MODIFIED, Martha, Jan 5, 2008
;                remove explicit call to dorado3; reset to agcdir
;
;-
;-----------------------------------------------------------------------



;-------------------------------------------
; Initialize common blocks
pro agcbtest_initcommon

common agcbtest_state, state

;restore, '/home/dorado3/galaxy/idl_alfa/agctotal.sav'
common agcshare
restore,agcdir+'agctotal.sav'


rec=n_elements(agctotal.agcnumber)

state={baseID:0L, $
       fmenu:0L, $
       helpmenu:0L, $
       plotwindowone:0L, $
       plotwindowtwo:0L, $
       plotwindowthree:0L, $
       resultlist:0L, $
       currentresults:0L, $
       currentagcnumber:0L, $ 
       searchra:0L, $
       searchdec:0L, $
       searchradius:0L, $
       agc:agctotal, $
       agcrahr:fltarr(rec), $
       agcdecdeg:fltarr(rec), $
       agcx:fltarr(rec), $
       agcy:fltarr(rec), $
       agcnumber:0L, $
       ngcic:0L, $
       ra:0L, $
       dec:0L, $
       ab:0L, $
       mag:0L, $
       inccode:0L, $
       posang:0L, $
       description:0L, $ 
       bsteintype:0L, $   
       vopt:0L, $       
       extrc3:0L, $      
       extdirbe:0L, $    
       vsource:0L, $    
       flux:0L, $        
       rms:0L, $        
       v21:0L, $        
       width:0L, $      
       telcode:0L, $  
       detcode:0L, $
       resultlistmembers:lonarr(2000), $
       resultnumbers:0L}   

 delvarx, agctotal

end

;-------------------------------------------------------------
;Startup block
pro agcbtest_startup

if (not (xregistered('agcbtest', /noshow))) then begin

;print, 'AGC Browse startup'

common agcbtest_state

agcbtest_initcommon

loadct, 1, /silent
stretch, 225,0

;Reset plots
hor
ver
!p.multi=0
device, decomposed=0

;Create widgets

;Top level base
tlb=widget_base(row=1, title='Arecibo General Catalog (Cornell EGG)', $
                tlb_frame_attr=1, xsize=1100, ysize=800, mbar=top_menu, $
                uvalue='tlb')

;Menu options
state.fmenu=widget_button(top_menu, value=' File ')
  buttonexit=widget_button(state.fmenu, value=' Exit ', /separator, $
                           event_pro='agcbtest_exit')

state.helpmenu=widget_button(top_menu, value=' Help ')
  buttonhelpfits=widget_button(state.helpmenu, value= ' About ', event_pro='agcbtest_help')
;-------------------------------------------------

;LEFT BASE - query options, select galaxy list, selected galaxy
;            information from AGC

leftbase=widget_base(tlb, xsize=260, ysize=750, frame=1, /column)
  agcsearchbase=widget_base(leftbase, /row)
  label=widget_label(agcsearchbase, value='AGC ID: ')
  state.currentagcnumber=widget_text(agcsearchbase, xsize=8, /editable, value='123456', uvalue='displayagc')
  button=widget_button(agcsearchbase, value=' Display ', uvalue='displayagc')

coordsearchbase=widget_base(leftbase, /column, xsize=250, /frame)
  label=widget_label(coordsearchbase, value='Search by:')
  topcoordbase=widget_base(coordsearchbase, /row)
     label=widget_label(topcoordbase, value='(RA, Dec): ')
     state.searchra=widget_text(topcoordbase, value='12.568', xsize=7, /editable, uvalue='querposition')
     state.searchdec=widget_text(topcoordbase, value='25.025', xsize=7, /editable, uvalue='querypositon')
  bottomcoordbase=widget_base(coordsearchbase, /row)
     label=widget_label(bottomcoordbase, value='    within ')
     state.searchradius=widget_text(bottomcoordbase, value='5.0  ', xsize=7, /editable, uvalue='queryposition')
     label=widget_label(bottomcoordbase, value=' arcminutes')
  searchbutton=widget_button(coordsearchbase, value='Query Position', uvalue='queryposition')
  
listbase=widget_base(leftbase, /column, xsize=250)
state.currentresults=widget_label(listbase, value='Search Results')
state.resultlist=widget_list(listbase, xsize=20,ysize=10, value=['Enter a search'], $
                               uvalue='resultlist')

currentagcbase=widget_base(leftbase, /row, xsize=250, /base_align_left, /frame)
   labelbase=widget_base(currentagcbase, /column, /base_align_left)
    label=widget_label(labelbase,value='AGCNumber: ')
    label=widget_label(labelbase,value='NGC/IC: ')
    label=widget_label(labelbase,value='RA: ')
    label=widget_label(labelbase,value='Dec: ')
    label=widget_label(labelbase,value='a,b: ')
    label=widget_label(labelbase,value='Mag: ')
    label=widget_label(labelbase,value='IncCODE: ')
    label=widget_label(labelbase,value='PosAng: ')
    label=widget_label(labelbase,value='Description: ')
    label=widget_label(labelbase,value='Bsteintype: ')
    label=widget_label(labelbase,value='Vopt(err): ')
    label=widget_label(labelbase,value='ExtRC3: ')
    label=widget_label(labelbase,value='ExtDirbe: ')
    label=widget_label(labelbase,value='Vsource: ') 
    label=widget_label(labelbase,value='Flux: ')
    label=widget_label(labelbase,value='rms: ')
    label=widget_label(labelbase,value='v21: ')
    label=widget_label(labelbase,value='width(err): ')
    label=widget_label(labelbase,value='Telescope: ')
    label=widget_label(labelbase,value='Detcode: ')

   infobase=widget_base(currentagcbase, /column, /base_align_left)
    state.agcnumber=    widget_label(infobase, value='123456           ')
    state.ngcic=        widget_label(infobase, value='NGC9999          ')
    state.ra=           widget_label(infobase, value='12 34 56.2       ')
    state.dec=          widget_label(infobase, value='+25 24 55        ')
    state.ab=           widget_label(infobase, value='12.3, 12.9       ')
    state.mag=          widget_label(infobase, value='12.345           ')
    state.inccode=      widget_label(infobase, value='12               ')
    state.posang=       widget_label(infobase, value='13               ')
    state.description=  widget_label(infobase, value='A Galaxy         ')
    state.bsteintype=   widget_label(infobase, value='23               ')
    state.vopt=         widget_label(infobase, value='2345(80)         ')
    state.extrc3=       widget_label(infobase, value='14.5             ')
    state.extdirbe=     widget_label(infobase, value='15.3             ')
    state.vsource=      widget_label(infobase, value='2356             ')
    state.flux=         widget_label(infobase, value='13.4             ')
    state.rms=          widget_label(infobase, value='2.3              ')
    state.v21=          widget_label(infobase, value='2370             ')
    state.width=        widget_label(infobase, value='120(15)          ')
    state.telcode=      widget_label(infobase, value='Arecibo          ')
    state.detcode=      widget_label(infobase, value='23               ')

;------------------------------------------------------------------------
;RIGHT BASE - full Aitoff sky plot. Smaller sky plot and dss image display

rightbase=widget_base(tlb, xsize=830, ysize=630, /column)
   state.plotwindowone=widget_draw(rightbase, xsize=820, ysize=420, frame=1)

lowerbase=widget_base(rightbase, xsize=820, ysize=360, /row)
   state.plotwindowtwo=widget_draw(lowerbase, xsize=450, ysize=360, frame=1)
   state.plotwindowthree=widget_draw(lowerbase,xsize=360, ysize=360, frame=1)

;Realization
widget_control, tlb, /realize

state.baseID=tlb

;Xmanager startup
xmanager, 'agcbtest', state.baseID, /no_block

;To start, plot the entire AGC
widget_control, state.baseID, hourglass=1
agc=state.agc

rec=n_elements(agc.agcnumber)

rahr=fltarr(rec)
decdeg=fltarr(rec)

for i=0L, rec-1L do begin
   rahr[i]=agc.rah[i]+agc.ram[i]/60.0+(agc.ras10[i]/10.0)/3600.0
   decdeg[i]=abs(agc.decd[i])+agc.decm[i]/60.0+agc.decs[i]/3600.0
   if (agc.sign[i] eq '-') then decdeg[i]=-decdeg[i]
endfor

widget_control, state.plotwindowone, get_value=index
wset, index

ver, -90,90
hor, -180,180

glactc, rahr, decdeg, 2000, gl,gb, 1
aitoff,gl,gb,x,y

plot, x,y,psym=3, charsize=1.0, xtitle='Galactic Longitude', ytitle='Galactic Latitude'

aitoff_grid

state.agcx=x
state.agcy=y
state.agcrahr=rahr
state.agcdecdeg=decdeg

delvarx, agc,x,y,gl,gb,rahr,decdeg,rec

widget_control, state.baseID, hourglass=0

endif

end

;-----------------------------------------------------
;EVENT HANDLER

pro agcbtest_event, event

common agcbtest_state

widget_control, event.id, get_uvalue=uvalue

case uvalue of

'displayagc': begin
     
              widget_control, state.currentagcnumber, get_value=agcnum

              agcnum=long(agcnum)
              agcnum=agcnum[0]
              agcindex=where(state.agc.agcnumber eq agcnum)

              if (agcindex ne -1) then begin
                  widget_control, state.resultlist, $
                      set_value=strcompress(state.agc.agcnumber[agcindex], /remove_all)
                  widget_control, state.resultlist, set_list_select=0
                  
                  state.resultlistmembers=state.agc.agcnumber[agcindex]
                  state.resultnumbers=n_elements(agcindex)

                 agcselect, agcindex

              endif else begin
                widget_control, state.resultlist, set_value=['No galaxies found']
              endelse
           

              end

'queryposition': begin

           ;Plot a zoomed in skyplot of surrounding area
              widget_control, state.searchra, get_value=rahr
              widget_control, state.searchdec, get_value=decdeg
              widget_control, state.searchradius, get_value=searchradius
              searchradius=float(searchradius)
              rahr=float(rahr)
              decdeg=float(decdeg)
              searchradius=searchradius[0]
              rahr=rahr[0]
              decdeg=decdeg[0]


              glactc, rahr, decdeg, 2000, gl,gb, 1
              aitoff,gl,gb,x,y

              widget_control, state.plotwindowone, get_value=index
              wset, index

              ver, -90,90
              hor, -180,180

              plot, state.agcx,state.agcy,psym=3, charsize=1.0, $
                    xtitle='Galactic Longitude',ytitle='Galactic Latitude'
              device, decomposed=1
              oplot, x,y, psym=6, symsize=2.0, thick=2.0, color='0000FF'XL
              device, decomposed=0

              aitoff_grid

              ralower=rahr-((searchradius/60.0)/15.0)
                if (ralower lt 0.0) then ralower=0.0
              raupper=rahr+((searchradius/60.0)/15.0)
                if (raupper gt 23.999999) then raupper=23.999999
              declower=decdeg-(searchradius/60.0)
                if (declower lt -90.0) then declower=-90.0
              decupper=decdeg+(searchradius/60.0)
                if (decupper gt 90.0) then decupper=90.0

              indexsurround=where(state.agcrahr ge ralower AND $
                                  state.agcrahr le raupper AND $
                                  state.agcdecdeg ge declower AND $
                                  state.agcdecdeg  le decupper  )

              widget_control, state.plotwindowtwo, get_value=index
                wset, index

              hor, rahr+((searchradius/60.0)/15.0), rahr-((searchradius/60.0)/15.0)
              ver, decdeg-(searchradius/60.0), decdeg+(searchradius/60.0)

             
            if (indexsurround[0] ne -1) then begin
              plot, state.agcrahr[indexsurround], state.agcdecdeg[indexsurround], $
                psym=5, xtitle='RA [hours]', ytitle='Dec [degrees]', $
                title=strcompress(searchradius, /remove_all)+ ' arcminutes around query'

              widget_control, state.resultlist, $
              set_value=strcompress(state.agc.agcnumber[indexsurround], /remove_all)
              state.resultlistmembers=state.agc.agcnumber[indexsurround]
              state.resultnumbers=n_elements(indexsurround)
            endif

                 end

  'resultlist': begin

                 resultlist=state.resultlistmembers[0:state.resultnumbers-1]
                 agcnumber=resultlist[event.index]
                 agcnumber=long(agcnumber)
                 agcindex=where(state.agc.agcnumber eq agcnumber)
                 
                 agcselect, agcindex

                end

else:

endcase

end


;-----------------------------------------------------
;Exit event handler
pro agcbtest_exit, event

common agcbtest_state

hor
ver
!p.multi=0

widget_control, state.baseID, /destroy
loadct, 0, /silent
stretch, 0,100

delvarx, state

print, 'Exiting agcbtest...'

end

;------------------------------------------------------------
;Help
pro agcbtest_help, event

   common agcbtest_state

h=['AGC BROWSE        ', $
   'B. Kent, Cornell Univ.', $
   'Based on data from, well, all kinds of sources!', $
   'RG, MPH, Cornell EGG', $
   ' ', $
   'Started June 17, 2005', $
   'Last update, Saturday June 18, 2005']


if (not (xregistered('agcbtest_help', /noshow))) then begin

helptitle = strcompress('agcbtest HELP')

    help_base =  widget_base(group_leader = state.baseID, $
                             /column, /base_align_right, title = helptitle, $
                             uvalue = 'help_base')

    help_text = widget_text(help_base, /scroll, value = h, xsize = 85, ysize = 15)
    
    help_done = widget_button(help_base, value = ' Done ', uvalue = 'help_done')

    widget_control, help_base, /realize
    xmanager, 'agcbtest_help', help_base, /no_block
    
endif


end

;----------------------------------------------------------------------

pro agcbtest_help_event, event

widget_control, event.id, get_uvalue = uvalue

case uvalue of
    'help_done': widget_control, event.top, /destroy
    else:
endcase

end

;------------------------------------------------------------------
;RA dec conversion - takes ra in decimal hours, and dec in decimal degrees
;                    and converts to strings - uses adstring from GSFC
;                                              ASTRO LIB

pro radecconvert, rahr, decdeg, rastring, decstring

   radeg=(rahr/24.0)*360.0

   result=strtrim(adstring([radeg,decdeg], 2, /truncate))

;Use strmatch here?
;Get position of plus or minus sign for dec, and cut the string at
;that position

   signpos=strpos(result, '+')
   if (signpos eq -1) then signpos=strpos(result, '-')

   rastring=strmid(result, 0, signpos-1)
   decstring=strmid(result, signpos, strlen(result)-1)

end

;--------------------------------------------------------
;Refreshes screen with selected galaxy
pro agcselect, agcindex

common agcbtest_state

rahr=state.agc.rah[agcindex]+state.agc.ram[agcindex]/60.0 $
                 +(state.agc.ras10[agcindex]/10.0)/3600.0

              decdeg=abs(state.agc.decd[agcindex])+state.agc.decm[agcindex]/60.0 $
                  +state.agc.decs[agcindex]/3600.0
              rahr=rahr[0]
              decdeg=decdeg[0]
              if (state.agc.sign[agcindex] eq '-') then decdeg=-decdeg

              glactc, rahr, decdeg, 2000, gl,gb, 1
              aitoff,gl,gb,x,y

              widget_control, state.plotwindowone, get_value=index
              wset, index

              ver, -90,90
              hor, -180,180

              plot, state.agcx,state.agcy,psym=3, charsize=1.0, $
                    xtitle='Galactic Longitude',ytitle='Galactic Latitude'
             
              device, decomposed=1
              oplot, x,y, psym=6, symsize=2.0, thick=2.0, color='0000FF'XL
              device, decomposed=0

              aitoff_grid

              ;Update infobase window with galaxy information
              radecconvert, rahr, decdeg, rastring, decstring
              agcnumber=state.agc.agcnumber[agcindex]
              ngcic=state.agc.ngcic[agcindex]
              a=state.agc.a100[agcindex]/100.0
              b=state.agc.b100[agcindex]/100.0
              mag=state.agc.mag10[agcindex]/10.0
              inccode=state.agc.inccode[agcindex]
              posang=state.agc.posang[agcindex]
              description=state.agc.description[agcindex]
              bsteintype=state.agc.bsteintype[agcindex]
              vopt=state.agc.vopt[agcindex]
              verr=state.agc.verr[agcindex]
              extrc3=state.agc.extrc3[agcindex]
              extdirbe=state.agc.extdirbe[agcindex]
              vsource=state.agc.vsource[agcindex]
              flux=state.agc.flux100[agcindex]/100.0
              rms=state.agc.rms100[agcindex]/100.0
              v21=state.agc.v21[agcindex]
              width=state.agc.width[agcindex]
              widtherr=state.agc.widtherr[agcindex]
              telcode=state.agc.telcode[agcindex]
              detcode=state.agc.detcode[agcindex]

widget_control, state.agcnumber, set_value=strcompress(agcnumber[0], /remove_all)
widget_control, state.ngcic, set_value=strcompress(ngcic[0])
widget_control, state.ra, set_value=rastring[0]
widget_control, state.dec, set_value=decstring[0]
widget_control, state.ab, set_value=strcompress(a[0], /remove_all)+', '+ $
                                    strcompress(b[0], /remove_all)
widget_control, state.mag, set_value=strcompress(mag[0], /remove_all)
widget_control, state.inccode, set_value=strcompress(inccode[0], /remove_all)
widget_control, state.posang, set_value=strcompress(posang[0], /remove_all)
widget_control, state.description, set_value=strcompress(description[0])
widget_control, state.bsteintype, set_value=strcompress(bsteintype[0], /remove_all)
widget_control, state.vopt, set_value=strcompress(vopt[0], /remove_all)+'('+ $
                                      strcompress(verr[0], /remove_all)+')'
widget_control, state.extrc3, set_value=strcompress(extrc3[0], /remove_all)
widget_control, state.extdirbe, set_value=strcompress(extdirbe[0], /remove_all)
widget_control, state.vsource, set_value=strcompress(vsource[0], /remove_all)
widget_control, state.flux, set_value=strcompress(flux[0], /remove_all)
widget_control, state.rms, set_value=strcompress(rms[0], /remove_all)
widget_control, state.v21, set_value=strcompress(v21[0], /remove_all)
widget_control, state.width, set_value=strcompress(width[0], /remove_all)+'('+ $
                                       strcompress(widtherr[0], /remove_all)+')'
widget_control, state.telcode, set_value=strcompress(telcode[0], /remove_all)
widget_control, state.detcode, set_value=strcompress(detcode[0], /remove_all)

                ;Query DSS at STSCI
                widget_control, state.baseID, hourglass=1

                widget_control, state.searchradius, get_value=searchradius
                searchradius=float(searchradius)
                searchradius=searchradius[0]

                ;Both coords must be in decimal degrees
                coords=[rahr*15.0,decdeg]
                querydss, coords, image, Hdr, survey='2b', imsize=10
                
                widget_control, state.plotwindowthree, get_value=index
                wset, index


                if (image[0] ne 0) then begin
                   image=congrid(image, 360,360)
                   tvscl, image
                endif else begin
                    plot,[0,0],xstyle=4, ystyle=4
                    xyouts, 80,170, 'Image not available', /device, charsize=2.0
                    xyouts, 100, 155, 'at this time', /device, charsize=2.0
                endelse

                widget_control, state.baseID, hourglass=0

               ;Plot a zoomed in skyplot of surrounding area
    
                ;This cutoff solution should be modified
              ralower=rahr-((searchradius/60.0)/15.0)
                if (ralower lt 0.0) then ralower=0.0
              raupper=rahr+((searchradius/60.0)/15.0)
                if (raupper gt 23.999999) then raupper=23.999999
              declower=decdeg-(searchradius/60.0)
                if (declower lt -90.0) then declower=-90.0
              decupper=decdeg+(searchradius/60.0)
                if (decupper gt 90.0) then decupper=90.0

              indexsurround=where(state.agcrahr ge ralower AND $
                                  state.agcrahr le raupper AND $
                                  state.agcdecdeg ge declower AND $
                                  state.agcdecdeg  le decupper  )

              widget_control, state.plotwindowtwo, get_value=index
                wset, index

             hor, rahr+((searchradius/60.0)/15.0), rahr-((searchradius/60.0)/15.0)
             ver, decdeg-(searchradius/60.0), decdeg+(searchradius/60.0)

            if (indexsurround[0] ne -1) then begin
              plot, state.agcrahr[indexsurround], state.agcdecdeg[indexsurround], $
                psym=5, xtitle='RA [hours]', ytitle='Dec [degrees]', $
                title=strcompress(searchradius, /remove_all)+ ' arcminutes around AGC '+ $
                strcompress(agcnumber[0], /remove_all)

              device, decomposed=1
              plots, rahr, decdeg, psym=5, thick=4.0, color='0000FF'XL
              device, decomposed=0

              widget_control, state.searchra, set_value=strcompress(rahr, /remove_all)
              widget_control, state.searchdec, set_value=strcompress(decdeg, /remove_all)

            endif


end


;-----------------------------------------------
;MAIN PROCEDURE BLOCK
pro agcbtest, agc=agc


agcbtest_startup

common agcbtest_state

;Select galaxy if given at command prompt.
if (n_elements(agc) ne 0) then begin
              agcnum=agc

              agcindex=where(state.agc.agcnumber eq agcnum)

              if (agcindex ne -1) then begin
                  widget_control, state.resultlist, $
                      set_value=strcompress(state.agc.agcnumber[agcindex], /remove_all)
                  widget_control, state.resultlist, set_list_select=0
                  
                  widget_control, state.currentagcnumber, set_value=strcompress(agcnum, /remove_all)
                  state.resultlistmembers=state.agc.agcnumber[agcindex]
                  state.resultnumbers=n_elements(agcindex)

                 agcselect, agcindex

              endif else begin
                widget_control, state.resultlist, set_value=['No galaxies found']
              endelse
   
endif



end
