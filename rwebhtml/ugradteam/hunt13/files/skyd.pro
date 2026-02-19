; 
; NAME:
; 		SKYD (and internal helpers WRITELINE, CHECKCOORDINATES)
; PURPOSE:
; 		Create links to various databases given coordinates in a file or on the command line.
; EXPLANATION:
; 		SKYD takes input on the command line and produces skylinks.html, a list of coordinates 
;		and corresponding links as output.  
; 		When SKYD is first started, the user chooses whether to make a new skylinks.html file, 
; 		which overwrites any previous output, or to append to an existing file.
; 		  Then, the user can enter coordinates in one of three ways:
; 			- The user can type coordinates in directly in hhmmsss+ddmmss format.  The coordinates
;			  are bounds checked before SKYD produces output.
; 			- The user can type in the name of an AGC file, which SKYD will open and read.
; 			- The user can type 88 to get a dialog box where an input file can be selected.
; 		Subsequent queries are added to the end of skylinks.html, and the user can continue to 
; 		enter any type of input until 99 is entered to quit.
; INPUTS:
; 		Any text file with AGC formatted data
; OUTPUTS:
; 		skylinks.html
; NOTES:
; 		1. If the user is entering a filename on the command line, it can't begin with 0, 1, or 2
; 		   or SKYD will interpret the string as coordinates, print an error, and reprompt.
;		2. SKYD repeatedly opens and closes the output file.  This is intentional, so the file is
; 		   updated after every operation (so the user can see the results in real time in a browser
; 		   rather than having to close SKYD first).
; MODIFICATION HISTORY:
; 		Written by MPH in FORTRAN; Translation to idl and revisions by Schuyler Smith, Union College, 
;               June 25, 2009, IDL 6.1
;               Dec 7,2013:    Add call to DR9; dropped direct Explore link  (mph)
;----------------------------------------------------------------------------------------------------


; Helper Procedure: takes coordinates and writes the requisite links to the given output file
pro writeline, outfile, input, rah, ram, ras, sign, decd, decm, decs

ra = (rah + ram/60. + ras/3600.)*15						; convert ra to decimal degrees
dec = decd + decm/60. + decs/3600.						; convert dec to a decimal
if (sign eq '-') then dec = -dec						; set sign of dec
fmt1 = '(a,f8.4,a,f8.4,a)'								; format for the urls that take decimal coordinates
fmt2 = '(a,i2.2,a,i2.2,a,f4.1,a,a,i2.2,a,i2.2,a,i2.2,a)'; format for the urls that use hms/dms coordinates (NED)

printf, outfile, '&nbsp   ', input, ' &nbsp', ra, dec, format='(3a, 2f9.4)'

;	; Explore ObjID
;printf, outfile, '&nbsp <a href="http://cas.sdss.org/astro/en/tools/explore/obj.asp?ra=', ra, '&dec=', dec, '" target=new>Explore ObjID</a>', format=fmt1

	; DR7Navigate
printf ,outfile, '&nbsp <a href="http://cas.sdss.org/astro/en/tools/chart/navi.asp?ra=', ra, '&dec=', dec, '&opt=glsi" target=new>DR7Navigate</a>', format=fmt1

	; DR9Navigate
printf ,outfile, '&nbsp <a href="http://skyserver.sdss3.org/dr9/en/tools/chart/navi.asp?ra=', ra, '&dec=', dec, '&opt=glsi" target=new>DR9Navigate</a>', format=fmt1

	; SkyView.03
printf, outfile, '&nbsp <a href="http://skyview.gsfc.nasa.gov/cgi-bin/nnskcall.pl?Interface=bform&VCOORD=', ra, ',', dec, '&NWINDOW=on&SURVEY=Digitized+Sky+Survey&SCOORD=Equatorial&EQUINX=2000&MAPROJ=Gnomonic&SFACTR=0.03&GRIDDD=Yes&COLTAB=Stern+Special" target=new>SkyView.03</a>', format = fmt1

	; SkyView.10
printf, outfile, '&nbsp <a href="http://skyview.gsfc.nasa.gov/cgi-bin/nnskcall.pl?Interface=bform&VCOORD=', ra, ',', dec, '&NWINDOW=on&SURVEY=Digitized+Sky+Survey&SCOORD=Equatorial&EQUINX=2000&MAPROJ=Gnomonic&SFACTR=0.10&GRIDDD=Yes&COLTAB=Stern+Special" target=new>SkyView.10</a>', format = fmt1

	; DSS2red.03
printf, outfile, '&nbsp <a href="http://skyview.gsfc.nasa.gov/cgi-bin/nnskcall.pl?Interface=bform&VCOORD=', ra, ',', dec, '&NWINDOW=on&SURVEY=DSS2+Red&SCOORD=Equatorial&EQUINX=2000&MAPROJ=Gnomonic&SFACTR=0.03&GRIDDD=Yes&COLTAB=Stern+Special" target=new>DSS2red.03</a>', format = fmt1

	; DSS2blu.03
printf, outfile, '&nbsp <a href="http://skyview.gsfc.nasa.gov/cgi-bin/nnskcall.pl?Interface=bform&VCOORD=', ra, ',', dec, '&NWINDOW=on&SURVEY=DSS2+Blue&SCOORD=Equatorial&EQUINX=2000&MAPROJ=Gnomonic&SFACTR=0.03&GRIDDD=Yes&COLTAB=Stern+Special" target=new>DSS2blu.03</a>', format = fmt1

	; DSS2red.10
printf, outfile, '&nbsp <a href="http://skyview.gsfc.nasa.gov/cgi-bin/nnskcall.pl?Interface=bform&VCOORD=', ra, ',', dec, '&NWINDOW=on&SURVEY=DSS2+Red&SCOORD=Equatorial&EQUINX=2000&MAPROJ=Gnomonic&SFACTR=0.10&GRIDDD=Yes&COLTAB=Stern+Special" target=new>DSS2red.10</a>', format = fmt1

	; DSS2blu.10
printf, outfile, '&nbsp <a href="http://skyview.gsfc.nasa.gov/cgi-bin/nnskcall.pl?Interface=bform&VCOORD=', ra, ',', dec, '&NWINDOW=on&SURVEY=DSS2+Blue&SCOORD=Equatorial&EQUINX=2000&MAPROJ=Gnomonic&SFACTR=0.10&GRIDDD=Yes&COLTAB=Stern+Special" target=new>DSS2blu.10</a>', format = fmt1

	; NED1
printf, outfile, '&nbsp <a href="http://nedwww.ipac.caltech.edu/cgi-bin/nph-objsearch?search_type=Near+Position+Search&in_csys=Near+Position=+Search&in_csys=Equatorial&in_equinox=J2000.0&lon=', rah, '+', ram, '+', ras, '&lat=', sign, decd, '+', decm, '+', decs, '&radius=1.00&out_csys=Equatorial&out_equinox=J2000.0&obj_sort=Distance+to+search+center&of=pre_text&zv_breaker=30000.0&list_limit=5&img_stamp=YES&z_constraint=Unconstrained&z_value1=&z_value2=&z_unit=z&ot_include=ANY&nmp_op=AN" target=new>NED1 </a>', format = fmt2

	; NED10
printf, outfile, '&nbsp <a href="http://nedwww.ipac.caltech.edu/cgi-bin/nph-objsearch?search_type=Near+Position+Search&in_csys=Near+Position=+Search&in_csys=Equatorial&in_equinox=J2000.0&lon=', rah, '+', ram, '+', ras, '&lat=', sign, decd, '+', decm, '+', decs, '&radius=10.0&out_csys=Equatorial&out_equinox=J2000.0&obj_sort=Distance+to+search+center&of=pre_text&zv_breaker=30000.0&list_limit=5&img_stamp=YES&z_constraint=Unconstrained&z_value1=&z_value2=&z_unit=z&ot_include=ANY&nmp_op=AN" target=new>NED10</a>', format = fmt2

printf, outfile, '</p>'
end



; makes sure all the elements of the input are within the expected range
; returns 1 (true) if they're all in range, and 0 (false) otherwise
function checkcoordinates, rah, ram, ras, sign, decd, decm, decs
if (rah lt 0) or (rah ge 24) then return, 0
if (ram lt 0) or (ram ge 60) then return, 0
if (ras lt 0) or (ras ge 60) then return, 0
if (sign ne '+') and (sign ne '-') then return, 0
if (decd lt 0) or (decd gt 90) then return, 0
if (decm lt 0) or (decm ge 60) then return, 0
if (decs lt 0) or (decs ge 60) then return, 0
if (decd eq 90) and ((decm ne 0) or (decs ne 0)) then return, 0
return, 1
end




; Main Procedure: handles user interaction, file management, etc.
pro skyd

outfile = 1L	; logical unit number (for output file, skylinks.html), actual value is arbitrary
infile = 2L		; logical unit number (for input file, if necessary)
rah = 0			; ra hours
ram = 0			; ra minutes
ras = 0			; ra seconds
decd = 0		; dec degrees
decm = 0		; dec minutes
decs = 0		; dec seconds
sign = ''		; sign

close, outfile										; make sure files aren't already open
close, infile

newfile = ''
read, newfile, prompt='Start a new skylinks file? (y/n) '
if (newfile eq 'y') or (newfile eq 'Y') then begin 	; make a new file
	openw, outfile, 'skylinks.html'
	printf, outfile, 'Created ', systime(), ' </p>'
	close, outfile
endif


while 1 do begin									; main loop

input = ''		; initialize input as a string
print, ''
print, 'Enter:' 
print, ' - ra and dec of central pixel (hhmmsss+ddmmss) OR'
print, ' - name of input AGC file OR'
print, ' - 88 to select a file OR'
print, ' - 99 to exit'
read, input
input = strtrim(input, 2) 							; strip off leading and trailing spaces
if input eq '99' then return 						; quit when the user enters '99'

if input ne '' then begin							; check for null input (i.e. hit enter accidentally)
if (strmid(input,0,1) ge '0') and (strmid(input,0,1) le '2') then begin ; first character in {0,1,2} -> read as coordinates
	print, ''
	print, 'Assuming ', input, ' are coordinates...'
	
	catch, e										; catch any error in parsing the input (below, IDL is weird)
	if e ne 0 then begin
		print, ''
		print, '    ERROR: Unable to parse ', input, ' as coordinates, try again.'
	endif else begin
		reads, input, rah, ram, ras, sign, decd, decm, decs, format = '(2i2, i3, a1, 3i2)'
		ras = ras/10. 								; convert deciseconds to seconds
		if (checkcoordinates(rah, ram, ras, sign, decd, decm, decs)) then begin
			print, (rah + ram/60. + ras/3600.)*15, decd + decm/60. + decs/3600.
			openu, outfile, 'skylinks.html', /append
			writeline, outfile, input, rah, ram, ras, sign, decd, decm, decs
			close, outfile
		endif else begin
			print, ''
			print, '    ERROR: Input coordinates out of expected range, try again.'
		endelse
	endelse
	
endif else begin									; read from a file
	if input eq '88' then input = dialog_pickfile() else begin
		print, ''		
		print, 'Assuming ', input, ' is a filename...'
	endelse

	if (findfile(input) ne '') then begin 			; if file exists, continue
		openr, infile, input						; open input file as reaad only
		openu, outfile, 'skylinks.html', /append
		while(eof(infile) ne 1) do begin			; while not at end of file
			coordinates = ''		
			readf, infile, coordinates, format = '(7x, a14)'
			reads, coordinates, rah, ram, ras, sign, decd, decm, decs, format = '(2i2, i3, a1, 3i2)'
			ras = ras/10. 							; convert deciseconds to seconds
			if (checkcoordinates(rah, ram, ras, sign, decd, decm, decs)) then begin
				writeline, outfile, coordinates, rah, ram, ras, sign, decd, decm, decs
			endif else begin
				print, ''
				print, '    WARNING: ', coordinates, ' out of range in ', input
			endelse
		endwhile
	
	endif else begin								; file does not exist
		print, ''
		print, '    ERROR: Input file does not exist, try again.'
	endelse
	
	close, infile
	close, outfile
endelse
endif
endwhile
end
