

; This procedure reads the [rsynced] wind trajectory 
; files from cdf and converts to the frequently-used
; idl traj format.

; Running once will rewrite the traj file for the PRESENT YEAR, based
; on the available data in /wind/traj/pre_or. Those data are rsynced
; with sscweb.

; Note that the model quantities (bs, ns, and mp distances)
; are filled with 9999 in the present version. This is 
; because automatic syncing with the model outputs at sscweb
; is presently disallowed. Note that this fill value was chosen 
; so that any magnetopause proxity checks (i.e. traj_bs lt 10) will return
; false.


pro wind_traj_idl_update, year=year

if keyword_set(year) $
  then yyyy = string(year, format= '(I4)') $
  else yyyy = strmid(systime(), 3,4, /reverse)

cdf_dir = '/crater/observatories/wind/traj/pre_or/'
idl_dir = '/crater/observatories/wind/traj/idl/'

spawn, 'ls '+cdf_dir+yyyy+'/*.cdf', fl

; output file should contain quantities of the form:
; traj_X, traj_Y, traj_Z = position in GSE (earth radii)
; traj_fdoy
; traj_ysm, traj_zsm
; traj_bs, traj_mp, traj_NS

xgse = [0]
ygse = [0]
zgse = [0]
xgsm = [0]
ygsm = [0]
zgsm = [0]
yr = [0]
dy = [0]
msec = [0]
Re = 6378.1 ; earth radius in km

for i = 0, n_elements(fl)-1 do begin &$
  id = cdf_open(fl[i]) &$
  recs = (cdf_inquire(id)).maxrec &$
  cdf_varget, id, 'GSE_POS', gse_pos, rec_count = recs &$
  cdf_varget, id, 'GSM_POS', gsm_pos, rec_count = recs &$
  cdf_varget, id, 'Time_PB5', time_pb5, rec_count = recs &$
  xgse = [xgse, reform(gse_pos[0, *])] &$
  ygse = [ygse, reform(gse_pos[1, *])] &$
  zgse = [zgse, reform(gse_pos[2, *])] &$
  xgsm = [xgsm, reform(gsm_pos[0, *])] &$
  ygsm = [ygsm, reform(gsm_pos[1, *])] &$
  zgsm = [zgsm, reform(gsm_pos[2, *])] &$ 
  yr = [yr, reform(time_pb5[0, *])] &$
  dy = [dy, reform(time_pb5[1, *])] &$
  msec = [msec, reform(time_pb5[2, *])] &$
  cdf_close, id &$
  endfor

n = n_elements(xgse)-1
traj_x = xgse[1:n]/Re
traj_y = ygse[1:n]/Re
traj_z = zgse[1:n]/Re
traj_ysm = ygsm[1:n]/Re
traj_zsm = zgsm[1:n]/Re
traj_fdoy = (dy + msec/(60.*60.*24.*1000.))[1:N]

traj_bs = 9999.+0.*traj_x
traj_ns = 9999.+0.*traj_x
traj_mp = 9999.+0.*traj_x

save, traj_x, traj_y, traj_z, traj_ysm, traj_zsm, traj_bs, traj_ns, $
  traj_mp, traj_fdoy, filename = idl_dir+'wind.traj.'+yyyy+'.idl'

end
