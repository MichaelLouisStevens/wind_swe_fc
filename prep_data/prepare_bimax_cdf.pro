; Project: WIND/SWE Faraday Cup Proton & Alpha Anisotropies
;
; IDL Procedure: prepare_bimax_cdf.pro
;
; Author:     Mike Stevens (mstevens@cfa.harvard.edu)
;
; Purpose:    Create CDF data file
;
;
; History:  04/03/12 This file created from prepare_bimax_ascii file
;           06/04/12 Alterations made to INCLUDE magnetosheath and
;           near-bowshock data in the output
;           06/04/12 ASCII output integrated via WRITEASCII keyword
;           06/22/12 corrections made to update skeleton table and
;           include timing to SPDF specs
;
; Note: push directory for data updates is at
; spdf_ingest.gsfc.nasa.gov, h1swegst, h#swe7tz
;
; SCCS Info
;
;           %Z%%M%   VERSION %I%    %G%  %U% 
;
; This routine uses the CDFX package for CDF formatted I/O
;@'/crater/utilities/idl/mike/idlstartup'
;@'/crater/utilities/idl/cdawlib/compile_cdfx.pro'
;.compile '/crater/utilities/idl/cdawlib/IDLmakecdf.pro'

PRO prepare_bimax_cdf, year, FPLOT=FPLOT, $
                       FSAVE=FSAVE, $ ;                        String giving the save file address
                       FSKELETON=FSKELETON, $ ;                String giving the CDF skeleton file address
                       writeASCII = writeASCII, $ ;            switch to also write ascii output
                       doy_start=doy_start, doy_end=doy_end, $;specify the start and end doy if desired
                       listing=listing ;                       return a listing of new CDF files if desired

; if no start or end days are specified, run the whole year
if not keyword_set(doy_start) then doy_start = 0.
if not keyword_set(doy_end) then doy_end = 367.

FILL  = 99999.9d
FILL2 = 99999.999d

; check keywords
IF keyword_set(FPLOT) THEN BEGIN
	MESSAGE, 'Plots will be written to: '+fplot, /INFORM
	SET_PLOT, 'ps'
	DEVICE, /INCHES, YOFFSET=0.1, YSIZE=10
	DEVICE, /LANDSCAPE
	DEVICE, FILENAME=fplot
	LOADCT, 13
	DEVICE, /COLOR
ENDIF ELSE BEGIN
	MESSAGE, 'Plots will be written to screen.', /INFORM
ENDELSE

IF NOT KEYWORD_SET(FSKELETON) THEN BEGIN
  FSKELETON = '/crater/observatories/wind/code/prep_data/swe_bimax_skeleton.cdf'
  MESSAGE, 'Skeleton file used: ' + fskeleton, /INFORM
ENDIF

s_year = string(year, format='(i4.4)')
s_doy_start = string(doy_start,format='(i3.3)')
s_doy_end   = string(doy_end,format='(i3.3)')


; first load in everything for this year so we can report how
;	much data made the cuts

MACHMIN         = -1d10
PDENMIN         = -1d10
PDENMAX         = 1d10
MAGLATMIN       = -1d10
MAGLATMAX       = 1d10
CHISQMAX        = 1d10
BZ2MIN          = -1d10
BSMIN           = -1d10
BMAGDEVMAX      = 1d10
BANGDEVMAX      = 1d10
FITSTATMIN      = -1d10
WERRMAX         = 1d10
DWPERPMAX	= 1d10
DWPARPMAX	= 1d10
CUTS = DINDGEN(14)
CUTS[ 0]        = MACHMIN
CUTS[ 1]        = PDENMIN
CUTS[ 2]        = PDENMAX
CUTS[ 3]        = MAGLATMIN
CUTS[ 4]        = MAGLATMAX
CUTS[ 5]        = CHISQMAX
CUTS[ 6]        = BZ2MIN
CUTS[ 7]        = BSMIN
CUTS[ 8]        = BMAGDEVMAX
CUTS[ 9]        = BANGDEVMAX
CUTS[10]        = FITSTATMIN
CUTS[11]        = WERRMAX
CUTS[12]	= DWPERPMAX
CUTS[13]	= DWPARPMAX

; find all files for this period
MESSAGE, 'Searching for all files in ' + s_year, /INFORM
spawn, 'ls /crater/observatories/wind/swe/bimax_nl/wi_fc_bimax.' + $
	s_year + '.*.idl', file_list
filedoy = fix(strmid(file_list, 57, 3))
inrange = where(filedoy ge doy_start and filedoy le doy_end, nfiles)
if nfiles gt 0 then file_list = file_list[inrange]
n_files = n_elements(file_list)


IF file_list[0] EQ '' THEN BEGIN
	MESSAGE, 'Sorry, no data files found for requested date range in ' + s_year, /INFORM
	RETURN
ENDIF ELSE BEGIN
	MESSAGE, 'Found ' + string(n_files, format='(i4)') + $
		' files in requested range for ' + s_year, /INFORM
ENDELSE


; load in all data
MESSAGE, 'Loading in all data with no cuts', /INFORM

load_bimax, file_list, DOY=DOY, $
	VXP=VXP, VYP=VYP, VZP=VZP, NP=NP, $
	NM=NM, X=X, $
	CUTS=CUTS, $
	/GETDOY, /GETVXP, /GETVYP, /GETVZP, /GETNP, $
	/GETNM, /GETX

n_all_nocuts = N_ELEMENTS(DOY)
MESSAGE, 'Loaded in ' + string(n_all_nocuts) + ' points with no cuts.', /INFORM

; look at timing information
; 1st question: are there any time regressions?
is_regression = BINDGEN( n_all_nocuts )*0
last_good = 0.0d
MESSAGE, 'Searching through dataset for time regressions...', /INFORM
FOR i=0L,(n_all_nocuts-1) DO BEGIN
	IF DOY[i] LE last_good THEN BEGIN
		is_regression[i] = 1
	ENDIF ELSE BEGIN
		last_good = DOY[i]
	ENDELSE
ENDFOR
tk = WHERE( is_regression, n_regression )
IF n_regression GT 0 THEN BEGIN
	MESSAGE, 'Identified ' + string(n_regression) + $
		' time regressions in the dataset', /INFORM
	IF n_regression LT 50 THEN PRINT, DOY[tk]
ENDIF ELSE BEGIN
	MESSAGE, 'No time regressions found in this dataset.', /INFORM
ENDELSE

; 2nd question: What are typical intervals between measurements?
dt = 86400.0*ABS( DOY - SHIFT(DOY, 1) )
dt_hist = HISTOGRAM(dt, MIN=0, MAX=400)
;plot, dt_hist, /yl, yr=[0.5,1.1*MAX(dt_hist)], $
;	title='Wind/SWE/FC Proton Anisotropy Dataset [' + s_year + $
;	'] - Typical Spectrum Rate', xtitle='One Second Bins', $
;	ytitle='Spectra / One Second Bin', psym=10


; how many times did moment analysis fail?
; how many times did non-linear analysis fail?
n_all_nocut = N_ELEMENTS( NP )
n_nl_fail_nocut = N_ELEMENTS( WHERE( NP LT 0.0 ) )
n_mo_fail_nocut = N_ELEMENTS( WHERE( NM LT 0.0 ) )
print, 'NL Failure Rate:  ', 100.0*n_nl_fail_nocut/(1.0*n_all_nocut)
print, 'MOM Failure Rate: ', 100.0*n_mo_fail_nocut/(1.0*n_all_nocut)

; more limited for output to file
MESSAGE, 'Scanning for files from '+s_year, /INFORM
spawn, 'ls /crater/observatories/wind/swe/bimax_nl/wi_fc_bimax.' + $
	s_year + '.*.idl', file_list
filedoy = fix(strmid(file_list, 57, 3))
inrange = where(filedoy ge doy_start and filedoy le doy_end, nfiles)
if nfiles gt 0 then file_list = file_list[inrange] else begin
    print, 'No files found in range. Processing should not have gone this far.'
    return
    endelse

        MACHMIN         = 1.5d
        PDENMIN         = 0.001d
        PDENMAX         = 1000.0d
        MAGLATMIN       = -90.0d
        MAGLATMAX       = 90.0d
        CHISQMAX        = 1d5
        BZ2MIN          = 0.00d
        BSMIN           = 5.0d
        BMAGDEVMAX      = 1d10
        BANGDEVMAX      = 1d10
        FITSTATMIN      = 0.0d
        WERRMAX         = 1d10
	DWPERPMAX	= 1d5
	DWPARPMAX	= 1d5
        CUTS = DINDGEN(14)
        CUTS[ 0]        = MACHMIN
        CUTS[ 1]        = PDENMIN
        CUTS[ 2]        = PDENMAX
        CUTS[ 3]        = MAGLATMIN
        CUTS[ 4]        = MAGLATMAX
        CUTS[ 5]        = CHISQMAX
        CUTS[ 6]        = BZ2MIN
        CUTS[ 7]        = BSMIN
        CUTS[ 8]        = BMAGDEVMAX
        CUTS[ 9]        = BANGDEVMAX
        CUTS[10]        = FITSTATMIN
        CUTS[11]        = WERRMAX
	CUTS[12]	= DWPERPMAX
	CUTS[13]	= DWPARPMAX




; zero out the old data to save memory
DOY	=	1.0
VXP	=	1.0
VYP	=	1.0
VZP	=	1.0
NP	=	1.0
NM	=	1.0
X	=	1.0

MESSAGE, 'Loading in limited dataset', /INFORM
load_bimax, file_list, DOY=DOY, $
        VXP=VXP, VYP=VYP, VZP=VZP, WPERP=WPERP, WPARP=WPARP, NP=NP, $
	DNL=DNL, $
        VXM=VXM, VYM=VYM, VZM=VZM, WPERM=WPERM, WPARM=WPARM, WM=WM, NM=NM, $
        VXA=VXA, VYA=VYA, VZA=VZA, WPERA=WPERA, WPARA=WPARA, NA=NA, $
	BX=BX, BY=BY, BZ=BZ, CHISQ=CHISQ, BANGDEV=BANGDEV, BMAGDEV=BMAGDEV, $
	CUTS=CUTS, FIT=FIT, NLPTS=NLPTS, MOMERR=MOMERR, PEAKDOY=PEAKDOY, dPEAKDOY=dPEAKDOY,  $
        /GETVXP, /GETVYP, /GETVZP, /GETWPERP, /GETWPARP, /GETNP, $
        /GETVXM, /GETVYM, /GETVZM, /GETWPERM, /GETWPARM, /GETNM, $
        /GETVXA, /GETVYA, /GETVZA, /GETWPERA, /GETWPARA, /GETNA, $
	/GETBX, /GETBY, /GETBZ, /GETDNL, /GETDOY, /GETWM, /GETCHISQ, /GETBMAGDEV, /GETBANGDEV, $
        /GETFIT, /GETNLPTS, /GETMOMERR, /GETPEAKDOY, /GETdPEAKDOY, /nobs

; fix any buggy peakDOY calculations by setting the peak time to the
; spectrum time
badPDOY = where(abs(peakdoy-doy) gt 1.6 or (peakdoy lt doy), nbadPDOY)
if nbadPDOY gt 0 then peakdoy[badPDOY] = doy[badPDOY]

; chisq -> chisq/d.o.f.
CHISQ = CHISQ / NLPTS

n_all_cut = N_ELEMENTS( NP )
n_nl_fail_cut = N_ELEMENTS( WHERE( NP LT 0.0 ) )
n_mo_fail_cut = N_ELEMENTS( WHERE( NM LT 0.0 ) )
print, 'NL Failure Rate:  ', 100.0*n_nl_fail_cut/(1.0*n_all_cut)
print, 'MOM Failure Rate: ', 100.0*n_mo_fail_cut/(1.0*n_all_cut)

; look for time regressions
n_all_cut = N_ELEMENTS(DOY)
MESSAGE, 'Loaded in ' + string(n_all_cut) + ' points with cuts.', /INFORM

; look at timing information
; 1st question: are there any time regressions?

is_regression = BINDGEN( n_all_cut )*0
last_good = 0.0d
MESSAGE, 'Searching through dataset for time regressions...', /INFORM
FOR i=0L,(n_all_cut-1) DO BEGIN & $
	IF DOY[i] LE last_good THEN BEGIN & $
		is_regression[i] = 1 & $
	ENDIF ELSE BEGIN & $
		last_good = DOY[i] & $
	ENDELSE & $
ENDFOR
tk = WHERE( is_regression, n_regression )
MESSAGE, 'Identified ' + string(n_regression) + $
	' time regressions in the dataset', /INFORM

; now run median filter despiking code
is_spike =  BINDGEN( n_all_cut )*0
MESSAGE, 'Searching through database for single point spikes...', /INFORM
VCRIT = 0.1
NCRIT = 0.5
WCRIT = 1.0
EWCRIT = 8.0
NSCRIT = 8.0
v = SQRT(vxp^2. + vyp^2 + vzp^2)
w = SQRT((wparp^2 + 2.0*(wperp^2))/3.0)
ew = ATAN( -VYP, -VXP ) / !dtor
ns = ATAN( VZP, SQRT(VXP^2 + VYP^2) ) / !dtor
vmedian = MEDIAN(v, 3)
wmedian = MEDIAN(w, 3)
nmedian = MEDIAN(np, 3)
ewmedian = MEDIAN(ew, 3) 
nsmedian = MEDIAN(ns, 3)
tk = WHERE( 	((ABS(v-vmedian)/vmedian) GT VCRIT) OR $
		((ABS(w-wmedian)/wmedian) GT WCRIT) OR $
		((ABS(np-nmedian)/nmedian) GT NCRIT) OR $
		(ABS(ew-ewmedian) GT EWCRIT) OR $
		(ABS(ns-nsmedian) GT NSCRIT), n_spike )
IF n_spike GT 0 THEN is_spike[tk] = 1
v = 1.0
w = 1.0
ew = 1.0
ns = 1.0
MESSAGE, 'Identified ' + string(n_spike) + $
	' single point spikes in the dataset', /INFORM

; Identify spectra with very different number densities from
; each of the cups - these could be periods when the modulator
; was acting quirky
is_modfail =  BINDGEN( n_all_cut )*0

; cup1 and cup2 densities from moment analysis
npmom1 = REFORM(MOMERR[*,3])
npmom2 = REFORM(MOMERR[*,4])
momdenrat = npmom1/npmom2
tk = WHERE( (momdenrat LE 0.85) OR (momdenrat GE 1.15), n_modfail )
IF n_modfail GT 0 THEN is_modfail[tk] = 1

IF (n_regression GT 0) OR (n_spike GT 0) OR (n_modfail GT 0) THEN BEGIN
	tk = WHERE( (is_regression EQ 0) AND (is_spike EQ 0) AND (is_modfail EQ 0) )
	DOY	=	DOY[tk]
	VXP	=	VXP[tk]
	VYP	=	VYP[tk]
	VZP	=	VZP[tk]
	WPERP	=	WPERP[tk]
	WPARP	=	WPARP[tk]
	NP	=	NP[tk]
	VXA	=	VXA[tk]
	VYA	=	VYA[tk]
	VZA	=	VZA[tk]
	WPERA	=	WPERA[tk]
	WPARA	=	WPARA[tk]
	NA	=	NA[tk]
	DNL	=	DNL[tk,*]
	VXM	=	VXM[tk]
	VYM	=	VYM[tk]
	VZM	=	VZM[tk]
	WPERM	=	WPERM[tk]
	WPARM	=	WPARM[tk]
	WM	=	WM[tk]
	NM	=	NM[tk]
	BX	=	BX[tk]
	BY	=	BY[tk]
	BZ	=	BZ[tk]
	CHISQ	=	CHISQ[tk]
	BANGDEV	=	BANGDEV[tk]
	BMAGDEV	=	BMAGDEV[tk]
        FIT     =       FIT[tk]
        PEAKDOY =       PEAKDOY[tk]
        dPEAKDOY=       dPEAKDOY[tk]
ENDIF ELSE BEGIN
	MESSAGE, 'No time regressions, spikes, or anamalous densities found in this dataset.', /INFORM
ENDELSE

; 2nd question: What are typical intervals between measurements?
dt = 86400.0*ABS( DOY - SHIFT(DOY, 1) )
dt_hist = HISTOGRAM(dt, MIN=0, MAX=400)
;plot, dt_hist, /yl, yr=[0.5,1.1*MAX(dt_hist)], $
;	title='Wind/SWE/FC Proton Anisotropy Dataset [' + s_year + $
;	'] - Typical Spectrum Rate', xtitle='One Second Bins', $
;	ytitle='Spectra / One Second Bin', psym=10



; prepare the moments for output
; find bad moment points and set to FILL
NM = DOUBLE(NM)
tk = WHERE( (vxm LT -2000.0) OR (NM LE 0.0), nbad )
IF nbad GT 0 THEN BEGIN
 vxm[tk] = FILL
 vym[tk] = FILL
 vzm[tk] = FILL
 wm[tk] = FILL
 nm[tk] = FILL2
 wperm[tk] = FILL
 wparm[tk] = FILL
ENDIF
tk = WHERE( (wperm GT 1000.0) or (wparm GT 1000.0) or (wperm LE 0.0) or (wparm LE 0.0), nbad )
IF nbad GT 0 THEN BEGIN & $
 WPERM[tk] = FILL & $
 WPARM[tk] = FILL & $
ENDIF

; moment bulk speed
VM = SQRT( VXM^2 + VYM^2 + VZM^2)
tk = WHERE( VM GT 2000.0, n_tk )
IF n_tk GT 0 THEN VM[tk] = FILL

; now prepare the non-linear data for output.  Here are the requirements:
SIGMA_KMS_MIN	=	1.0	; minimum uncertainty in km/s
D_KMS_MIN	=	0.01	; uncertainty must be GE 1% of value for speeds
SIGMA_NCC_MIN	=	0.01	; minimum uncertainty n/cc
D_NCC_MIN	=	0.005	; minimum uncertainty number density
D_ERRMAX	=	0.70	; maximum error is 70%
SIGMA_DEG_MIN	=	0.5

; VXP
sigma_vxp 	= ABS( REFORM( VXP*DNL[*,0] ) ) > ABS(D_KMS_MIN*VXP) > SIGMA_KMS_MIN
Dvxp		= ABS( REFORM( DNL[*,0] ) ) > D_KMS_MIN
tk = WHERE( (VXP LT -2000.0) OR (Dvxp GT D_ERRMAX), nbad )
IF nbad GT 0 THEN BEGIN & $
	VXP[tk] = FILL & $
	sigma_vxp[tk] = FILL & $
ENDIF

; VYP
sigma_vyp 	= ABS( REFORM( VYP*DNL[*,1] ) ) > ABS(D_KMS_MIN*VYP) > SIGMA_KMS_MIN
Dvyp		= ABS( REFORM( DNL[*,1] ) ) > D_KMS_MIN
tk = WHERE( (VYP LT -2000.0) OR (Dvyp GT D_ERRMAX), nbad )
IF nbad GT 0 THEN BEGIN & $
	VYP[tk] = FILL & $
	sigma_vyp[tk] = FILL & $
ENDIF

; VZP
sigma_vzp 	= ABS( REFORM( VZP*DNL[*,2] )) > ABS(D_KMS_MIN*VZP) > SIGMA_KMS_MIN
Dvzp		= ABS( REFORM( DNL[*,2] ) ) > D_KMS_MIN
tk = WHERE( (VZP LT -2000.0) OR (Dvzp GT D_ERRMAX), nbad )
IF nbad GT 0 THEN BEGIN & $
	VZP[tk] = FILL & $
	sigma_vzp[tk] = FILL & $
ENDIF

; WPERP
sigma_wperp 	= ABS( REFORM( WPERP*DNL[*,3] ) ) > ABS(D_KMS_MIN*WPERP) > SIGMA_KMS_MIN
Dwperp		= ABS( REFORM( DNL[*,3] ) ) > D_KMS_MIN
tk = WHERE( (WPERP LT -2000.0) OR (Dwperp GT D_ERRMAX), nbad )
IF nbad GT 0 THEN BEGIN & $
	WPERP[tk] = FILL & $
	sigma_wperp[tk] = FILL & $
ENDIF

; WPARP
sigma_wparp 	= ABS( REFORM( WPARP*DNL[*,4] ) ) > ABS(D_KMS_MIN*WPARP) > SIGMA_KMS_MIN
Dwparp		= ABS( REFORM( DNL[*,4] ) ) > D_KMS_MIN
tk = WHERE( (WPARP LT -2000.0) OR (Dwparp GT D_ERRMAX), nbad )
IF nbad GT 0 THEN BEGIN & $
	WPARP[tk] = FILL & $
	sigma_wparp[tk] = FILL & $
ENDIF


; NP
NP = DOUBLE(NP)
sigma_np 	= ABS( REFORM( NP*DNL[*,5] ) ) > ABS(D_NCC_MIN*NP) > SIGMA_NCC_MIN
Dnp		= ABS( REFORM( DNL[*,5] ) ) > D_NCC_MIN
tk = WHERE( (NP LT 0.0) OR (Dnp GT D_ERRMAX), nbad )
IF nbad GT 0 THEN BEGIN & $
	NP[tk] = FILL2 & $
	sigma_np[tk] = FILL2 & $
ENDIF

; calculate bulk speeds and the uncertainty in the bulk speed
VP = SQRT(VXP^2 + VYP^2 + VZP^2)
sigma_vp = SQRT( ((sigma_vxp*vxp)^2 + (sigma_vyp*vyp)^2 + (sigma_vzp*vzp)^2)/(Vp^2) ) $
	> ABS(D_KMS_MIN*VP) > SIGMA_KMS_MIN
dVP = sigma_vp / VP
tk = WHERE( (VXP GT 9999.) OR (VYP GT 9999.) OR (VZP GT 9999.) OR (dVP GT D_ERRMAX), nbad )
IF nbad GT 0 THEN BEGIN & $
	VP[tk] = FILL & $
	sigma_vp[tk] = FILL & $
ENDIF

; east-west flow angle and uncertainty
ew = ATAN( -VYP, -VXP ) / !dtor
sigma_ew = SQRT( ((VXP*sigma_vxp)^2 + (VYP*sigma_vyp)^2)/( (VXP^2 + VYP^2)^2 ) ) > SIGMA_DEG_MIN
tk = WHERE( (VXP GT 9999.) OR (VYP GT 9999.), nbad )
IF nbad GT 0 THEN BEGIN & $
	ew[tk] = FILL & $
	sigma_ew[tk] = FILL & $
ENDIF

; north south flow angle and uncertainty
ns = ATAN( VZP, SQRT(VXP^2 + VYP^2) ) / !dtor
sigma_ns = SQRT( (((VXP^2 + VYP^2)*sigma_vzp)^2 + $
	((VXP*sigma_vxp)^2 + (VYP*sigma_vyp)^2)*(VZP^2)) / $
	( (VXP^2 + VYP^2)*(VP^4) ) ) > SIGMA_DEG_MIN
tk = WHERE( (VXP GT 9999.) OR (VYP GT 9999.) OR (VZP GT 9999.), nbad )
IF nbad GT 0 THEN BEGIN & $
	ns[tk] = FILL & $
	sigma_ns[tk] = FILL & $
ENDIF


; calculate temperatures given parallel and perpendicular temperatures
;	and get the trace thermal speed and uncertainty
Tperp = 60.5*(WPERP^2)
Tpara = 60.5*(WPARP^2)
Ttrace = (2.0*Tperp + Tpara)/3.0
dTtrace = ((2.0*60.5)/(3.0*Ttrace))*SQRT(4.0*(Wperp^4)*(DNL[*,3]^2) + (Wparp^4)*(DNL[*,4]^2))
Wtrace = SQRT(Ttrace/60.5)
dWtrace = DTtrace*SQRT(Ttrace/60.5)/Wtrace/2.0
sigma_wtrace = ABS( dWtrace*Wtrace ) > SIGMA_KMS_MIN
tk = WHERE( (WPERP GT 9999.) OR (WPARP GT 9999.) OR (sigma_wtrace/wtrace GT D_ERRMAX), nbad )
IF nbad GT 0 THEN BEGIN & $
	Wtrace[tk] = FILL & $
	sigma_wtrace[tk] = FILL & $
ENDIF


; 
; Alpha particles
; 

; VXA
; remove alpha velocities for spectra with a-p ambiguity (fit 6) or
; alphas out of the SWE range (fit 7)
sigma_vxa 	= ABS( REFORM( VXA*DNL[*,6] ) ) > ABS(D_KMS_MIN*VXA) > SIGMA_KMS_MIN
Dvxa		= ABS( REFORM( DNL[*,6] ) ) > D_KMS_MIN
tk = WHERE( (VXA LT -1500.0) OR (Dvxa GT D_ERRMAX) OR (FIT LE 0) OR (FIT eq 6) OR (FIT eq 7) OR (FIT eq 2 and na/np ge 0.2), nbad )
IF nbad GT 0 THEN BEGIN & $
	VXA[tk] = FILL & $
	sigma_vxa[tk] = FILL & $
ENDIF

; VYA
; remove alpha velocities for spectra with a-p ambiguity (fit 6) or
; alphas out of the SWE range (fit 7)
sigma_vya 	= ABS( REFORM( VYA*DNL[*,7] ) ) > ABS(D_KMS_MIN*VYA) > SIGMA_KMS_MIN
Dvya		= ABS( REFORM( DNL[*,7] ) ) > D_KMS_MIN
tk = WHERE( (VYA LT -2000.0) OR (FIT LE 0) OR (FIT eq 6) OR (FIT eq 7) OR (FIT eq 2 and na/np ge 0.2), nbad )
IF nbad GT 0 THEN BEGIN & $
	VYA[tk] = FILL & $
	sigma_vya[tk] = FILL & $
ENDIF

; VZA
; remove alpha velocities for spectra with a-p ambiguity (fit 6) or
; alphas out of the SWE range (fit 7)
sigma_vza 	= ABS( REFORM( VZA*DNL[*,8] )) > ABS(D_KMS_MIN*VZA) > SIGMA_KMS_MIN
Dvza		= ABS( REFORM( DNL[*,8] ) ) > D_KMS_MIN
tk = WHERE( (VZA LT -2000.0) OR (FIT LE 0) OR (FIT eq 6) OR (FIT eq 7) OR (FIT eq 2 and na/np ge 0.2), nbad )
IF nbad GT 0 THEN BEGIN & $
	VZA[tk] = FILL & $
	sigma_vza[tk] = FILL & $
ENDIF

; WPERA
sigma_wpera 	= ABS( REFORM( WPERA*DNL[*,9] ) ) > ABS(D_KMS_MIN*WPERA) > SIGMA_KMS_MIN
Dwpera		= ABS( REFORM( DNL[*,9] ) ) > D_KMS_MIN
; remove alpha thermal speeds for spectra with a-p ambiguity (fit 6) or
; alphas out of the SWE range (fit 7)
tk = WHERE( (WPERA LT -2000.0) OR (Dwpera GT D_ERRMAX) OR (FIT LE 0) OR (FIT eq 6) OR (FIT eq 7) OR $
            (FIT eq 2 and na/np ge 0.2), nbad )
IF nbad GT 0 THEN BEGIN & $
	WPERA[tk] = FILL & $
	sigma_wpera[tk] = FILL & $
ENDIF

; WPARA
sigma_wpara 	= ABS( REFORM( WPARA*DNL[*,10] ) ) > ABS(D_KMS_MIN*WPARA) > SIGMA_KMS_MIN
Dwpara		= ABS( REFORM( DNL[*,10] ) ) > D_KMS_MIN
; remove alpha thermal speeds for spectra with a-p ambiguity (fit 6) or
; alphas out of the SWE range (fit 7)
tk = WHERE( (WPARA LT -2000.0) OR (Dwpara GT D_ERRMAX) OR (FIT LE 0) OR (FIT eq 6) OR (FIT eq 7) OR (FIT eq 2 and na/np ge 0.2), nbad )
IF nbad GT 0 THEN BEGIN & $
	WPARA[tk] = FILL & $
	sigma_wpara[tk] = FILL & $
ENDIF

; NP
NA = DOUBLE(NA)
sigma_na 	= ABS( REFORM( NA*DNL[*,11] ) ) > ABS(D_NCC_MIN*NA) > SIGMA_NCC_MIN
Dna		= ABS( REFORM( DNL[*,11] ) ) > D_NCC_MIN
; remove alpha densities for spectra with a-p ambiguity (fit 6) or
; alphas out of the SWE range (fit 7)
tk = WHERE( (NA LT 0.0) OR (Dna GT D_ERRMAX) OR (FIT LE 0) OR (FIT eq 6) OR (FIT eq 7) OR (FIT eq 2 and na/np ge 0.2), nbad )
IF nbad GT 0 THEN BEGIN & $
	NA[tk] = FILL2 & $
	sigma_na[tk] = FILL2 & $
ENDIF

; calculate bulk speeds and the uncertainty in the bulk speed
VA = SQRT(VXA^2 + VYA^2 + VZA^2)
sigma_va = SQRT( ((sigma_vxa*vxa)^2 + (sigma_vya*vya)^2 + (sigma_vza*vza)^2)/(Va^2) ) $
	> ABS(D_KMS_MIN*VA) > SIGMA_KMS_MIN
dVA = sigma_va / VA
tk = WHERE( (VXA GT 9999.) OR (VYA GT 9999.) OR (VZA GT 9999.) OR (dVA GT D_ERRMAX) OR (FIT LE 0) OR (FIT eq 6) OR (FIT eq 7) OR (FIT eq 2 and na/np ge 0.2), nbad )
IF nbad GT 0 THEN BEGIN & $
	VA[tk] = FILL & $
	sigma_va[tk] = FILL & $
	VXA[tk] = FILL & $
	sigma_vxa[tk] = FILL & $
	VYA[tk] = FILL & $
	sigma_vya[tk] = FILL & $
	VZA[tk] = FILL & $
	sigma_vza[tk] = FILL & $
ENDIF

; calculate temperatures given parallel and perpendicular temperatures
;	and get the trace thermal speed and uncertainty
Tpera = 60.5*(WPERA^2)
Tpara = 60.5*(WPARA^2)
TtraceA = (2.0*Tpera + Tpara)/3.0
dTtraceA = ((2.0*60.5)/(3.0*TtraceA))*SQRT(4.0*(Wpera^4)*(DNL[*,9]^2) + (Wpara^4)*(DNL[*,10]^2))
WtraceA = SQRT(TtraceA/60.5)
dWtraceA = DTtraceA*SQRT(TtraceA/60.5)/WtraceA/2.0
sigma_wtraceA = ABS( dWtraceA*WtraceA ) > SIGMA_KMS_MIN
tk = WHERE( (WPERA GT 999.) OR (WPARA GT 999.) OR (sigma_wtraceA/wtraceA GT D_ERRMAX) OR (FIT LE 0) OR (FIT eq 6) OR (FIT eq 7) OR (FIT eq 2 and na/np ge 0.2), nbad )
IF nbad GT 0 THEN BEGIN & $; should all anis W's get filled here?
  wtraceA[tk] = FILL &$
  wpara[tk] = FILL &$
  wpera[tk] = FILL &$
  sigma_wpera[tk] = FILL & $
  sigma_wpara[tk] = FILL & $
  sigma_wtraceA[tk] = FILL & $
ENDIF

; remove alpha temperatures that are identically equal to the proton
; (this will mostly catch flag = 3, but may also catch cases where the mode flag was not correctly applied)
tk = where((wtraceA eq wtrace) or (wpera eq wperp) or (wpara eq wparp), nbad)
if nbad gt 0 then begin &$
  wtraceA[tk] = FILL &$
  wpara[tk] = FILL &$
  wpera[tk] = FILL &$
  sigma_wpera[tk] = FILL & $
  sigma_wpara[tk] = FILL & $
  sigma_wtraceA[tk] = FILL & $
endif

BX = double(BX)
BY = double(BY)
BZ = double(BZ)
B = SQRT( BX^2 + BY^2 + BZ^2 )
BANGDEV = double(BANGDEV)
BMAGDEV = double(BMAGDEV)

; magnetic field data
tk = WHERE( (BX LT -1000) OR (BY LT -1000) OR (BZ LT -1000), n_tk )
IF n_tk GT 0 THEN BEGIN & $
 BX[tk] = FILL2 & $
 BY[tk] = FILL2 & $
 BZ[tk] = FILL2 & $
 B[tk] = FILL2 & $
 BMAGDEV[tk] = FILL2 & $ 
 BANGDEV[tk] = FILL2 & $
ENDIF
tk = WHERE( (bmagdev LT 0.0) OR (bangdev LT 0.0), n_tk )
IF n_tk GT 0 THEN BEGIN & $
 BANGDEV[tk] = FILL2 & $
 BMAGDEV[tk] = FILL2 & $
ENDIF

; Throw out bad alpha data - look for alignment of differential
;                            velocity with magnetic field
dVapX = VXA - VXP
dVapY = VYA - VYP
dVapZ = VZA - VZP
dVap = SQRT(dVapX^2 + dVapY^2 + dVapZ^2)

; Limit for cut on alphas
alpha = ACOS( (dVapX*BX + dVapY*BY + dvAPZ*BZ) / (B*dVap) ) / !DTOR
dvap_limit_param = 50.0 > (-90.0 - COS(alpha*!dtor)*220.) > (-90.0 + COS(alpha*!dtor)*220.) 
tk = WHERE( DVAP GE dvap_limit_param, ntk )
IF ntk GT 0 THEN BEGIN  & $
    	VXA[tk] = FILL & $
	sigma_vxa[tk] = FILL & $
	VYA[tk] = FILL & $
	sigma_vya[tk] = FILL & $
	VZA[tk] = FILL & $
	sigma_vza[tk] = FILL & $
	WPERA[tk] = FILL & $
	sigma_wpera[tk] = FILL & $
	WPARA[tk] = FILL & $
	sigma_wpara[tk] = FILL & $
	NA[tk] = FILL2 & $
	sigma_na[tk] = FILL2 & $
	VA[tk] = FILL & $
	sigma_va[tk] = FILL & $
	WtraceA[tk] = FILL & $
	sigma_wtraceA[tk] = FILL & $
ENDIF


; throw out any bad moment data (NANs from bimax moment failures)
tk = WHERE(finite(wperm)*finite(wparm) eq 0, ntk)
IF ntk GT 0 THEN BEGIN &$
        wperm[tk] = FILL &$
        wparm[tk] = FILL &$
  ENDIF


n_alpha = N_ELEMENTS(WHERE(NA LT 1000.0))

; get trajectory information: GSE, GSM
; for now restoring from big trajectory file downloaded from NSSDC
; in the future will use position data included in daily IDL save files
MESSAGE, 'Restoring NSSDC trajectory information', /INFORM
DOY_HOLD1 = DOY
YEAR_HOLD1 = YEAR
NS_HOLD1 = NS

restore, '/crater/observatories/wind/traj/idl/wind.traj.idl'
check = uniq(fyear)
DOY_pos = DOY[check]
YEAR_POS = YEAR[check]
XGSE_pos = XGSE[check]
YGSE_pos = YGSE[check]
ZGSE_pos = ZGSE[check]
YGSM_pos = YGSM[check]
ZGSM_pos = ZGSM[check]

badTraj = where(xgse_pos gt 300, NBT)
if NBT gt 0 then stop

DOY = DOY_HOLD1
YEAR = YEAR_HOLD1
NS = NS_HOLD1

tk = WHERE( year_pos EQ year, npos )
XGSE = INTERPOL( XGSE_POS[tk], DOY_POS[tk], DOY, /SPLINE )
YGSE = INTERPOL( YGSE_POS[tk], DOY_POS[tk], DOY, /SPLINE )
ZGSE = INTERPOL( ZGSE_POS[tk], DOY_POS[tk], DOY, /SPLINE )
YGSM = INTERPOL( YGSM_POS[tk], DOY_POS[tk], DOY, /SPLINE )
ZGSM = INTERPOL( ZGSM_POS[tk], DOY_POS[tk], DOY, /SPLINE )

; -------------------------------------------------------------------------------------
; *****DEBUG***** SCREENING FOR NAN's, INFINITIES, ETC
; -------------------------------------------------------------------------------------
finiteTEST = finite(doy)*finite(fit)*finite(vp)*finite(sigma_vp)*finite(vxp)*finite(vyp)*$
  finite(vzp)*finite(sigma_vxp)*finite(sigma_vyp)*finite(sigma_vzp)*finite(wtrace)*$
  finite(sigma_wtrace)*finite(wperp)*finite(sigma_wperp)*finite(wparp)*finite(sigma_wparp)*$
  finite(ew)*finite(sigma_ew)*finite(ns)*finite(sigma_ns)*finite(np)*finite(sigma_np)*$
  finite(va)*finite(sigma_va)*finite(vxa)*finite(vya)*finite(vza)*finite(sigma_vxa)*$
  finite(sigma_vya)*finite(sigma_vza)*finite(wtraceA)*finite(sigma_wtraceA)*finite(wpera)*$
  finite(wpara)*finite(sigma_wpera)*finite(sigma_wpara)*finite(na)*finite(sigma_na)*$
  finite(chisq)*finite(vm)*finite(vxm)*finite(vym)*finite(vzm)*finite(wm)*finite(wperm)*$
  finite(wparm)*finite(nm)*finite(bx)*finite(by)*finite(bz)*finite(bangdev)*$
  finite(bmagdev)*finite(xgse)*finite(ygse)*finite(zgse)*finite(ygsm)*finite(zgsm)*$
  finite(peakdoy)*finite(dpeakdoy)

screen = where(finiteTEST eq 0, nscreen)
if nscreen gt 0 then begin
    print, '  Error in NAN screen. Not all of this data is finite.'
    print, '  Execution halted at prepare_bimax_CDF.pro'
    stop
endif


; -------------------------------------------------------------------------------------
; FORMATTED DATA OUTPUT BEGINS HERE
; -------------------------------------------------------------------------------------

; identify the CDF format (skeleton) file
;FSKELETON = '/crater/observatories/wind/code/prep_data/swe_bimax_skeleton.cdf'

save, filename =  '/crater/observatories/wind/swe/nssdc_idl/wi_h1_swe_'+s_year+'_v01.idl', $
  doy, fit, vp, sigma_vp, vxp, vyp, vzp, sigma_vxp, sigma_vyp, sigma_vzp, wtrace, sigma_wtrace, $
  wperp, sigma_wperp, wparp, sigma_wparp, ew, sigma_ew, ns, sigma_ns, np, sigma_np, va, $
  sigma_va, vxa, vya, vza, sigma_vxa, sigma_vya, sigma_vza, wtraceA, sigma_wtraceA, $
  wpera, wpara, sigma_wpera, sigma_wpara, na, sigma_na, chisq, vm, vxm, vym, vzm, wm, $
  wperm, wparm, nm, bx, by, bz, bangdev, bmagdev, xgse, ygse, zgse, ygsm, zgsm, peakdoy, dpeakdoy

; Write out day-by-day blocks of data
int_maxdoy = fix(max(doy[where(doy lt 367.)]))
listing = ''
FOR j=doy_start, int_maxdoy DO BEGIN

;    d_start = 20.0*j
;    d_end = 20.0*(j+1.0) - 1.0
    
    PRINT, ' Generating file ', si(j,3,3), ' of ', si(int_maxdoy,3,3), ' FDOY: ', $
           si(j,3,3)
    
    tk = WHERE( (DOY GE j) AND (DOY LT (j + 1.0)), ntk )
    IF ntk GT 3 THEN BEGIN 
        PRINT, '   Number points selected: ', ntk
    
; name the CDF output file
        caldat, julday(1, 0, fix(s_year), 0, 0)+j, moo, daa
        yyyymmdd = s_year + string(moo, format = "(i02)") + string(daa, format = "(i02)")
        foutname = '/crater/observatories/wind/swe/nssdc_cdf/wi_h1_swe_'+yyyymmdd+'_v01.cdf'
        FSAVE = foutname ;'wi_swefc_apbimax.'+s_year+'.'+s_doy_start+'.'+s_doy_end+'.cdf'
        listing = [listing, fsave]

; load the variables into an idl structure
        struc = read_master_cdf(FSKELETON, FSAVE)

        nrecs = ntk ; get number of CDF records

        ; calculate the CDF_EPOCH dating
        epoch_tk = dblarr(nrecs)
        for i = 0, nrecs - 1 do begin &$
          julian = julday(1, 1, year, 0, 0, 0) + (doy[tk[i]]-1.) &$
          caldat, julian, gmonth, gday, gyear, ghour, gminute, gsecond &$
          gmilli = 1000.*(gsecond - fix(gsecond)) &$
          cdf_epoch, thisEpoch, gyear, gmonth, gday, ghour, gminute, fix(gsecond), gmilli, /compute_epoch &$
          epoch_tk[i] = thisepoch &$
          endfor

        ; debug measure 6/6/12. Apparent epoch r/w erro
        if (max(epoch_tk) eq min(epoch_tk)) then stop

; re-assign the data structure pointers to the data variables
        ptr_free, struc.epoch.data
        struc.epoch.data = ptr_new(epoch_tk)
        ptr_free, struc.year.data
        struc.year.data = ptr_new(year[tk])
        ptr_free, struc.doy.data
        struc.doy.data = ptr_new(doy[tk])
        ptr_free, struc.fit_flag.data
        struc.fit_flag.data = ptr_new(fit[tk])

; proton v
        ptr_free, struc.Proton_V_nonlin.data
        struc.Proton_V_nonlin.data = ptr_new(vp[tk])
        ptr_free, struc.Proton_sigmaV_nonlin.data
        struc.Proton_sigmaV_nonlin.data = ptr_new(sigma_vp[tk])
        ptr_free, struc.Proton_VX_nonlin.data
        struc.Proton_VX_nonlin.data = ptr_new(vxp[tk])
        ptr_free, struc.Proton_sigmaVX_nonlin.data
        struc.Proton_sigmaVX_nonlin.data = ptr_new(sigma_vxp[tk])
        ptr_free, struc.Proton_VY_nonlin.data
        struc.Proton_VY_nonlin.data = ptr_new(vyp[tk])
        ptr_free, struc.Proton_sigmaVY_nonlin.data
        struc.Proton_sigmaVY_nonlin.data = ptr_new(sigma_vyp[tk])
        ptr_free, struc.Proton_VZ_nonlin.data
        struc.Proton_VZ_nonlin.data = ptr_new(vzp[tk])
        ptr_free, struc.Proton_sigmaVZ_nonlin.data
        struc.Proton_sigmaVZ_nonlin.data = ptr_new(sigma_vzp[tk])
;wp
        ptr_free, struc.Proton_W_nonlin.data
        struc.Proton_W_nonlin.data = ptr_new(wtrace[tk])
        ptr_free, struc.Proton_sigmaW_nonlin.data
        struc.Proton_sigmaW_nonlin.data = ptr_new(sigma_wtrace[tk])
        ptr_free, struc.Proton_Wperp_nonlin.data
        struc.Proton_Wperp_nonlin.data = ptr_new(wperp[tk])
        ptr_free, struc.Proton_sigmaWperp_nonlin.data
        struc.Proton_sigmaWperp_nonlin.data = ptr_new(sigma_wperp[tk])
        ptr_free, struc.Proton_Wpar_nonlin.data
        struc.Proton_Wpar_nonlin.data = ptr_new(wparp[tk])
        ptr_free, struc.Proton_sigmaWpar_nonlin.data
        struc.Proton_sigmaWpar_nonlin.data = ptr_new(sigma_wparp[tk])
; angles
        ptr_free, struc.EW_flowangle.data
        struc.EW_flowangle.data = ptr_new(ew[tk])
        ptr_free, struc.SigmaEW_flowangle.data
        struc.SigmaEW_flowangle.data = ptr_new(sigma_ew[tk])
        ptr_free, struc.NS_flowangle.data
        struc.NS_flowangle.data = ptr_new(ns[tk])
        ptr_free, struc.sigmaNS_flowangle.data
        struc.sigmaNS_flowangle.data = ptr_new(sigma_ns[tk])
; density
        ptr_free, struc.Proton_Np_nonlin.data
        struc.Proton_Np_nonlin.data = ptr_new(np[tk])
        ptr_free, struc.Proton_sigmaNp_nonlin.data
        struc.Proton_sigmaNp_nonlin.data = ptr_new(sigma_np[tk])
; alpha v
        ptr_free, struc.Alpha_V_nonlin.data
        struc.Alpha_V_nonlin.data = ptr_new(va[tk])
        ptr_free, struc.Alpha_sigmaV_nonlin.data
        struc.Alpha_sigmaV_nonlin.data = ptr_new(sigma_va[tk])
        ptr_free, struc.Alpha_VX_nonlin.data
        struc.Alpha_VX_nonlin.data = ptr_new(vxa[tk])
        ptr_free, struc.Alpha_sigmaVX_nonlin.data
        struc.Alpha_sigmaVX_nonlin.data = ptr_new(sigma_vxa[tk])
        ptr_free, struc.Alpha_VY_nonlin.data
        struc.Alpha_VY_nonlin.data = ptr_new(vya[tk])
        ptr_free, struc.Alpha_sigmaVY_nonlin.data
        struc.Alpha_sigmaVY_nonlin.data = ptr_new(sigma_vya[tk])
        ptr_free, struc.Alpha_VZ_nonlin.data
        struc.Alpha_VZ_nonlin.data = ptr_new(vza[tk])
        ptr_free, struc.Alpha_sigmaVZ_nonlin.data
        struc.Alpha_sigmaVZ_nonlin.data = ptr_new(sigma_vza[tk])
; alpha w
        ptr_free, struc.Alpha_W_nonlin.data
        struc.Alpha_W_nonlin.data = ptr_new(wtraceA[tk])
        ptr_free, struc.Alpha_sigmaW_nonlin.data
        struc.Alpha_sigmaW_nonlin.data = ptr_new(sigma_wtrace[tk])
        ptr_free, struc.Alpha_Wperp_nonlin.data
        struc.Alpha_Wperp_nonlin.data = ptr_new(wpera[tk])
        ptr_free, struc.Alpha_sigmaWperp_nonlin.data
        struc.Alpha_sigmaWperp_nonlin.data = ptr_new(sigma_wpera[tk])
        ptr_free, struc.Alpha_Wpar_nonlin.data
        struc.Alpha_Wpar_nonlin.data = ptr_new(wpara[tk])
        ptr_free, struc.Alpha_sigmaWpar_nonlin.data
        struc.Alpha_sigmaWpar_nonlin.data = ptr_new(sigma_wpara[tk])
; alpha density
        ptr_free, struc.Alpha_Na_nonlin.data
        struc.Alpha_Na_nonlin.data = ptr_new(na[tk])
        ptr_free, struc.Alpha_sigmaNa_nonlin.data
        struc.Alpha_sigmaNa_nonlin.data = ptr_new(sigma_na[tk])
; proton moment stuff    
        ptr_free, struc.ChisQ_DOF_nonlin.data
        struc.ChisQ_DOF_nonlin.data = ptr_new(chisq[tk])
        ptr_free, struc.Proton_V_moment.data
        struc.Proton_V_moment.data = ptr_new(vm[tk])
        ptr_free, struc.Proton_VX_moment.data
        struc.Proton_VX_moment.data = ptr_new(vxm[tk])
        ptr_free, struc.Proton_VY_moment.data
        struc.Proton_VY_moment.data = ptr_new(vym[tk])
        ptr_free, struc.Proton_VZ_moment.data
        struc.Proton_VZ_moment.data = ptr_new(vzm[tk])
        ptr_free, struc.Proton_W_moment.data
        struc.Proton_W_moment.data = ptr_new(wm[tk])
        ptr_free, struc.Proton_wperp_moment.data
        struc.Proton_wperp_moment.data = ptr_new(wperm[tk])
        ptr_free, struc.Proton_wpar_moment.data
        struc.Proton_wpar_moment.data = ptr_new(wparm[tk])
        ptr_free, struc.Proton_Np_moment.data
        struc.Proton_Np_moment.data = ptr_new(nm[tk])
; B
        ptr_free, struc.BX.data
        struc.BX.data = ptr_new(bx[tk])
        ptr_free, struc.BY.data
        struc.BY.data = ptr_new(by[tk])
        ptr_free, struc.BZ.data
        struc.BZ.data = ptr_new(bz[tk])
        ptr_free, struc.Ang_dev.data
        struc.Ang_dev.data = ptr_new(bangdev[tk])
        ptr_free, struc.dev.data
        struc.dev.data = ptr_new(bmagdev[tk])
; position
        ptr_free, struc.xgse.data
        struc.xgse.data = ptr_new(xgse[tk])
        ptr_free, struc.ygse.data
        struc.ygse.data = ptr_new(ygse[tk])
        ptr_free, struc.zgse.data
        struc.zgse.data = ptr_new(zgse[tk])
        ptr_free, struc.ygsm.data
        struc.ygsm.data = ptr_new(ygsm[tk])
        ptr_free, struc.zgsm.data
        struc.zgsm.data = ptr_new(zgsm[tk])
; timing
        ptr_free, struc.Peak_DOY.data
        struc.Peak_DOY.data = ptr_new(peakDOY[tk])
        ptr_free, struc.sigmaPeak_DOY.data
        struc.sigmaPeak_DOY.data = ptr_new(dPeakDOY[tk])
  
;        stop; DEBUG
        
; reload the structured data into the output file, with the  
; skeleton structure
        result = write_data_to_cdf(Fsave, struc)
  
        if result eq 1 then MESSAGE, 'CDF file output complete: ' + fsave, /INFORM $
        else MESSAGE, 'CDF file output NOT complete: '+fsave + $
          ', an error occured in CDF output formatting.', /INFORM
        
        ENDIF ELSE BEGIN 
            PRINT, '   No data for this period'
        ENDELSE
    ENDFOR

; trim the updated file listing array
if n_elements(listing) gt 1 then listing = listing[1: n_elements(listing)-1] else listing = -1

IF keyword_set(writeASCII) THEN BEGIN
; write output to ASCII file
foutname = '/crater/observatories/wind/swe/nssdc_ascii/wi_h1_swe_'+s_year+'_v01.desc'
MESSAGE, 'Writing output to file: ' + foutname, /INFORM

FORMAT='(i4.4,'+ $              ;                YEAR
  '" ", f11.6,'+  $             ;      doy
  '" ", i4.2,'+ $               ; FIT FLAG
  '18(" ",f7.1),'+ $            ; proton nonlinear params
  '2(" ",f9.3),'+$              ; proton nonlinear density
  '14(" ",f7.1),' + $           ; alpha nonlinear params
  '2(" ",f9.3),' + $            ; alpha nonlinear density (same as proton but w/o flow angles)
  '" ",f6.1,'+$                 ; chi-square per dof
  '7(" ",f7.1),'+$              ; moment params
  '" ",f9.3,'+$                 ; moment density
  '10(" ",f9.3),'+$             ; B and traj
  '2(" ", f11.6))'              ;   peak timing items


openw, fout, foutname, /get_lun
printf, fout, '; Project: WIND/SWE Faraday Cup (Proton-Alpha Anisotropy Analysis)'
printf, fout, '; Description: Solar wind proton and alpha parameters, including anisotropic'
printf, fout, ';  temperatures, derived by non-linear fitting of the measurements'
printf, fout, ';  and with moment techniques.'
printf, fout, '; Filename: ' + foutname
printf, fout, '; Author: J. Kasper jkasper@cfa.harvard.edu'
printf, fout, ';         M. Stevens (mstevens@cfa.harvard.edu) 1 (617) 495-7852'
printf, fout, '; Created: '+systime()
printf, fout, '; '
printf, fout, '; Notes: '
printf, fout, ';   - Data reported within this file do not exceed the limits of'
printf, fout, ';     various paremeters listed in the following section.  There'
printf, fout, ';     may be more valid data in the original dataset that requires'
printf, fout, ';     additional work to interpret but was discarded due to the'
printf, fout, ';     limits. 
printf, fout, ';   - We provide the one sigma uncertainty for each parameter'
printf, fout, ';     produced by the non-linear curve fitting analysis either'
printf, fout, ';     directly from the fitting or by propagating uncertainties'
printf, fout, ';     for bulk speeds, flow angles or any other derived parameter.'
printf, fout, ';   - For the non-linear anisotropic proton analysis, a scalar'
printf, fout, ';     thermal speed is produced by determining parallel and'
printf, fout, ';     perpendicular tmperatures, taking the trace, '
printf, fout, ';     Tscalar = (2Tperp + Tpara)/3 and converting the result'
printf, fout, ';     back to a thermal speed.  The uncertainties are also'
printf, fout, ';     propagated through'
printf, fout, '; '
printf, fout, '; '
printf, fout, '; Limits:'
printf, fout, ';	Minimum mach number: ' + string(MACHMIN)
printf, fout, ';	Maximum chisq/dof:   ' + string(CHISQMAX)
printf, fout, ';	Maximum uncertainty in any'
printf, fout, ';          parameter from non-linear'
printf, fout, ';          analysis:          ' + string(100.0*D_ERRMAX)+ '[%]'
printf, fout, ';'
printf, fout, ';  Total number of spectra in this period:     ' + string(n_all_nocut, format='(i7)')
printf, fout, ';         Spectra after applying limits:       ' + string(n_all_cut, format='(i7)')
printf, fout, ';         Spectra removed as time regressions: ' + string(n_regression, format='(i7)')
printf, fout, ';         Spectra removed as spikes:           ' + string(n_spike, format='(i7)')
printf, fout, ';         Spectra written to this file:        ' + string(N_ELEMENTS(DOY), format='(i7)')
printf, fout, ';         Spectra with alpha particle data:    ' + string(n_alpha, format='(i7)')
printf, fout, ';' 
printf, fout, ';' 
printf, fout, '; Fit Flag Guide:'
printf, fout, ';  The fit flag indicates non-ideal conditions that may affect the quality of '
printf, fout, ';  the nonlinear fit and, where applicable, simplifying assumptions that have been' 
printf, fout, ';  taken.'
printf, fout, ';'
printf, fout, ';  10:  Solar wind parameters OK -- no action necessary'
printf, fout, ';   9:  Alpha particles are relatively too cold'
printf, fout, ';   8:  Alpha particles overlap within protons in current distribution function.'
printf, fout, ';   7:  Alphas too fast, out of SWE range'
printf, fout, ';   6:  Alpha particle peak may be confused with second proton peak.'
printf, fout, ';   5:  Parameters OK, but Tp=Ta constraint used (params obtained with SUB_PROT=1)'
printf, fout, ';   4:  Alphas are unusually cold, Tp=Ta constraint used (SUB_PROT=1)'
printf, fout, ';   3:  Alphas are relatively too hot (SUB_PROT=1). Tp=Ta constraint used'
printf, fout, ';   2:  Alphas are unusually slow.'
printf, fout, ';   1:  Poor peak identification'
printf, fout, ';   0:  Spectrum cannot be fit with a bimax model. May be strongly non-Maxwellian or '
printf, fout, ';         may contain a discontinuity.'
printf, fout, ';' 
printf, fout, ';'
printf, fout, '; Format Code: ' + FORMAT
printf, fout, ';'
printf, fout, '; Column #	Desciption'
printf, fout, ';    1		Year'
printf, fout, ';    2		Fractional day of year (FDOY) of start of spectrum (Noon on January 1 = 1.5)'
printf, fout, ';    3		Fit flag (see table)'
printf, fout, ';    4           Proton bulk speed V (km/s) from non-linear analysis'
printf, fout, ';    5		 One sigma uncertainty in V [km/s]'
printf, fout, ';    6		Proton velocity component Vx (GSE, km/s) from non-linear analysis'
printf, fout, ';    7		 One sigma uncertainty in Vx [km/s]'
printf, fout, ';    8		Proton velocity component Vy (GSE, km/s) from non-linear analysis'
printf, fout, ';    9		 One sigma uncertainty in Vy [km/s]'
printf, fout, ';   10		Proton velocity component Vz (GSE, km/s) from non-linear analysis'
printf, fout, ';   11		 One sigma uncertainty in Vz [km/s]'
printf, fout, ';   12		Scalar RMS proton thermal speed (km/s) from trace of anisotropic temperatures'
printf, fout, ';   13		 One sigma uncertainty in trace RMS thermal speed'
printf, fout, ';   14 		Proton RMS thermal speed Wperpendicular (km/s) from non-linear analysis'
printf, fout, ';   15		 One sigma uncertainty in Wperpendicular [km/s]'
printf, fout, ';   16		Proton RMS thermal speed Wparallel (km/s) from non-linear analysis'
printf, fout, ';   17		 One sigma uncertainty in Wparallel [km/s]'
printf, fout, ';   18		East-West flow angle (degrees)'
printf, fout, ';   19		 One sigma uncertainty in EW flow angle'
printf, fout, ';   20		North-South flow angle (degrees)'
printf, fout, ';   21		 One sigma uncertainty in NS flow angle'
printf, fout, ';   22		Proton number density Np (n/cc) from non-linear analysis'
printf, fout, ';   23		 One sigma uncertainty in Np [n/cc]'
printf, fout, ';   24           Alpha bulk speed V (km/s) from non-linear analysis'
printf, fout, ';   25		 One sigma uncertainty in V [km/s]'
printf, fout, ';   26		Alpha velocity component Vx (GSE, km/s) from non-linear analysis'
printf, fout, ';   27		 One sigma uncertainty in Vx [km/s]'
printf, fout, ';   28		Alpha velocity component Vy (GSE, km/s) from non-linear analysis'
printf, fout, ';   29		 One sigma uncertainty in Vy [km/s]'
printf, fout, ';   30		Alpha velocity component Vz (GSE, km/s) from non-linear analysis'
printf, fout, ';   31		 One sigma uncertainty in Vz [km/s]'
printf, fout, ';   32		Scalar alpha RMS thermal speed (km/s) from trace of anisotropic temperatures'
printf, fout, ';   33		 One sigma uncertainty in trace Alpha RMS thermal speed'
printf, fout, ';   34 		Alpha RMS thermal speed Wperpendicular (km/s) from non-linear analysis'
printf, fout, ';   35		 One sigma uncertainty in Alpha Wperpendicular [km/s]'
printf, fout, ';   36		Alpha RMS thermal speed Wparallel (km/s) from non-linear analysis'
printf, fout, ';   37		 One sigma uncertainty in Alpha Wparallel [km/s]'
printf, fout, ';   38		Alpha number density Na (n/cc) from non-linear analysis'
printf, fout, ';   39		 One sigma uncertainty in Na [n/cc]'
printf, fout, ';   40		CHISQ/DOF for this fit' 
printf, fout, ';   41		Proton bulk speed (km/s) from moment analysis'
printf, fout, ';   42		Proton velocity component Vx (GSE, km/s) from moment analysis'
printf, fout, ';   43		Proton velocity component Vy (GSE, km/s) from moment analysis'
printf, fout, ';   44		Proton velocity component Vz (GSE, km/s) from moment analysis'
printf, fout, ';   45		Proton RMS thermal speed W (km/s) from isotropic moment analysis'
printf, fout, ';   46		Proton RMS thermal speed Wperpendicular (km/s) from bimax moment analysis'
printf, fout, ';   47		Proton RMS thermal speed Wparallel (km/s) from bimax moment analysis'
printf, fout, ';   48		Proton number density Np (n/cc) from moment analysis'
printf, fout, ';   49		Magnetic field component Bx (GSE, nT) averaged over plasma measurement'
printf, fout, ';   50		Magnetic field component By (GSE, nT) averaged over plasma measurement'
printf, fout, ';   51		Magnetic field component Bz (GSE, nT) averaged over plasma measurement'
printf, fout, ';   52		Angluar deviation of magnetic field over plasma measurement [degrees]'
printf, fout, ';   53		Deviation in magnitude of field over plasma measurement [nT]'
printf, fout, ';   54		X (GSE) Position of Wind S/C at start of spectrum [Re]'
printf, fout, ';   55		Y (GSE) Position of Wind S/C at start of spectrum [Re]'
printf, fout, ';   56		Z (GSE) Position of Wind S/C at start of spectrum [Re]'
printf, fout, ';   57		Y (GSM) Position of Wind S/C at start of spectrum [Re]'
printf, fout, ';   58		Z (GSM) Position of Wind S/C at start of spectrum [Re]'
printf, fout, ';   59		Fractional day of year (FDOY) when peak charge flux was observed (Noon on January 1 = 1.5)'
printf, fout, ';   60		One sigma uncertainty in FDOY of peak charge flux'
printf, fout, ';'
close, fout
free_lun, fout

MESSAGE, 'Description file output complete.', /INFORM

; Write out 20 day blocks of data
FOR j=0.0,18.0 DO BEGIN
    d_start = 20.0*j
    d_end = 20.0*(j+1.0) - 1.0
    
    
    tk = WHERE( (DOY GE d_start) AND (DOY LT (d_end + 1.0)), ntk )
    IF ntk GT 3 THEN BEGIN 
        PRINT, '   Number points selected: ', ntk
            
        foutname = '/crater/observatories/wind/swe/nssdc_ascii/wi_h1_swe_'+s_year+'.'+si(d_start,3,3)+'.'+si(d_end,3,3)+'_v01.txt'
        openw, fout, foutname, /get_lun
        PRINT, '   Writing output to file: ' + foutname
   
        per = 0.0
        n_out = double(ntk)
        FOR i=0L,(n_out-1) DO BEGIN
            IF 100.0*double(i)/n_out GE per THEN BEGIN
                PRINT, '     ', string(per, format='(f5.1)'), ' % complete'
                per = per + 25.0
            ENDIF

        FORMAT='(i4.4,'+ $      ;                YEAR
          '" ", f11.6,'+  $     ;      doy
          '" ", i4.2,'+ $       ; FIT FLAG
          '18(" ",f7.1),'+ $    ; proton nonlinear params
          '2(" ",f9.3),'+$      ; proton nonlinear density
          '14(" ",f7.1),' + $   ; alpha nonlinear params
          '2(" ",f9.3),' + $ ; alpha nonlinear density (same as proton but w/o flow angles)
          '" ",f6.1,'+$         ; chi-square per dof
          '7(" ",f7.1),'+$      ; moment params
          '" ",f9.3,'+$         ; moment density
          '10(" ",f9.3),'+$     ; B and traj
          '2(" ", f11.6))'      ;   peak timing items

        PRINTf, fout, $
          year, $               ;1
          doy[tk[i]], $         ;2
          fit[tk[i]], $         ;3
          vp[tk[i]], $          ;4***
          sigma_vp[tk[i]], $    ;5
          vxp[tk[i]], $         ;6
          sigma_vxp[tk[i]], $   ;7
          vyp[tk[i]], $         ;8
          sigma_vyp[tk[i]], $   ;9
          vzp[tk[i]], $         ;10
          sigma_vzp[tk[i]], $   ;11
          wtrace[tk[i]], $      ;12
          sigma_wtrace[tk[i]], $ ;13
          wperp[tk[i]], $       ;14
          sigma_wperp[tk[i]], $ ;15
          wparp[tk[i]], $       ;16
          sigma_wparp[tk[i]], $ ;17
          ew[tk[i]], $          ;18
          sigma_ew[tk[i]], $    ;19
          ns[tk[i]], $          ;20
          sigma_ns[tk[i]], $    ;21
          np[tk[i]], $          ;22***
          sigma_np[tk[i]], $    ;23
          va[tk[i]], $          ;24***
          sigma_va[tk[i]], $    ; 25
          vxa[tk[i]], $         ; 26
          sigma_vxa[tk[i]], $   ; 27
          vya[tk[i]], $         ; 28
          sigma_vya[tk[i]], $   ; 29
          vza[tk[i]], $         ; 30
          sigma_vza[tk[i]], $   ; 31
          wtraceA[tk[i]], $     ; 32
          sigma_wtraceA[tk[i]],$ ; 33
          wpera[tk[i]], $       ; 34
          sigma_wpera[tk[i]], $ ; 35
          wpara[tk[i]], $       ; 36
          sigma_wpara[tk[i]], $ ; 37
          na[tk[i]], $l         ; 38***
          sigma_na[tk[i]], $    ; 39
          chisq[tk[i]], $       ; 40
          vm[tk[i]], $          ; 41***
          vxm[tk[i]], $         ; 42
          vym[tk[i]], $         ; 43
          vzm[tk[i]], $         ; 44
          wm[tk[i]], $          ; 45
          wperm[tk[i]], $       ; 46
          wparm[tk[i]], $       ; 47
          nm[tk[i]], $          ; 48***
          bx[tk[i]], $          ; 49
          by[tk[i]], $          ; 50
          bz[tk[i]], $          ; 51
          bangdev[tk[i]], $     ; 52
          bmagdev[tk[i]], $     ; 53
          xgse[tk[i]], $        ; 54
          ygse[tk[i]], $        ; 55
          zgse[tk[i]], $        ; 56
          ygsm[tk[i]], $        ; 57
          zgsm[tk[i]], $        ; 58
          peakDOY[tk[i]], $     ; 59***
          dPeakDOY[tk[i]], $    ; 60
          FORMAT = FORMAT

          if (peakdoy[tk[i]] lt doy[tk[i]]) or (peakdoy[tk[i]]-doy[tk[i]] gt 0.01) then stop
        
; fout, $
;              year, $
;              DOY[tk[i]], $
;              fit[tk], $
;              VP[tk[i]], $
;              sigma_vp[tk[i]], $
;              VXP[tk[i]], $
;              sigma_vxp[tk[i]], $
;              VYP[tk[i]], $
;              sigma_vyp[tk[i]], VZP[tk[i]], sigma_vzp[tk[i]], $
;                    Wtrace[tk[i]], sigma_wtrace[tk[i]], WPERP[tk[i]], sigma_wperp[tk[i]], WPARP[tk[i]], sigma_wparp[tk[i]], $
;                    ew[tk[i]], sigma_ew[tk[i]], ns[tk[i]], sigma_ns[tk[i]], NP[tk[i]], sigma_np[tk[i]],  $
;                    VA[tk[i]], sigma_va[tk[i]], VXA[tk[i]], sigma_vxa[tk[i]], VYA[tk[i]], sigma_vya[tk[i]], VZA[tk[i]], sigma_vza[tk[i]], $
;                    WtraceA[tk[i]], sigma_wtraceA[tk[i]], NA[tk[i]], sigma_na[tk[i]], CHISQ[tk[i]], $
;                    VM[tk[i]], VXM[tk[i]], VYM[tk[i]], VZM[tk[i]], WM[tk[i]], WPERM[tk[i]], WPARM[tk[i]], NM[tk[i]], $
;                    BX[tk[i]], BY[tk[i]], BZ[tk[i]], BANGDEV[tk[i]], BMAGDEV[tk[i]], $
;                    XGSE[tk[i]], YGSE[tk[i]], ZGSE[tk[i]], YGSM[tk[i]], ZGSM[tk[i]], $
;                    FORMAT=FORMAT
;

        ENDFOR

       close, fout 
       free_lun, fout

    ENDIF ELSE BEGIN 
        PRINT, '   No data for this period'
    ENDELSE

ENDFOR

MESSAGE, 'ASCII file output complete.', /INFORM

ENDIF


IF keyword_set(FPLOT) THEN BEGIN
	DEVICE, /CLOSE
	SET_PLOT, 'x'
	LOADCT, 39
	RESETM, 1
ENDIF

; done!
MESSAGE, 'DONE!', /INFORM

END


