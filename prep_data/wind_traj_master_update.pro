;BS              FLOAT     = Array[488568]
;DOY             DOUBLE    = Array[488568]
;FYEAR           DOUBLE    = Array[488568]
;MP              FLOAT     = Array[488568]
;NS              FLOAT     = Array[488568]
;XGSE            FLOAT     = Array[488568]
;XGSM            FLOAT     = Array[488568]
;YEAR            INT       = Array[488568]
;YGSE            FLOAT     = Array[488568]
;YGSM            FLOAT     = Array[488568]
;ZGSE            FLOAT     = Array[488568]
;ZGSM            FLOAT     = Array[488568]



;TRAJ_BS         DOUBLE    = Array[34749]
;TRAJ_FDOY       FLOAT     = Array[34749]
;TRAJ_MP         DOUBLE    = Array[34749]
;TRAJ_NS         DOUBLE    = Array[34749]
;TRAJ_X          DOUBLE    = Array[34749]
;TRAJ_Y          DOUBLE    = Array[34749]
;TRAJ_YSM        DOUBLE    = Array[34749]
;TRAJ_Z          DOUBLE    = Array[34749]
;TRAJ_ZSM        DOUBLE    = Array[34749]

; make one master traj file from all of the annual files
pro wind_traj_master_update

spawn, 'ls /crater/observatories/wind/traj/idl/wind.traj.*.idl', tfiles

restore, tfiles[0]

thisyear = strmid(tfiles[0], 7, 4, /reverse)
thisyear = thisyear + 0.*traj_fdoy
thisfyear = thisyear + traj_fdoy/365.25
BS = TRAJ_BS
DOY = TRAJ_FDOY
FYEAR = thisfyear
MP = TRAJ_MP
NS = TRAJ_NS
XGSE = TRAJ_X
XGSM = TRAJ_X
YEAR = fix(thisyear)
YGSE  = TRAJ_Y
YGSM = TRAJ_YSM
ZGSE = TRAJ_Z
ZGSM = TRAJ_ZSM

for i = 1, n_elements(tfiles) -1 do begin
    print, 'processing file: ' + tfiles[i]
    restore, tfiles[i]
    thisyear = strmid(tfiles[i], 7, 4, /reverse)
    thisyear = thisyear + 0.*traj_fdoy
    thisfyear = thisyear + traj_fdoy/365.25
    BS = [BS, TRAJ_BS]
    DOY = [DOY, TRAJ_FDOY]
    FYEAR = [FYEAR, thisfyear]
    MP = [MP, TRAJ_MP]
    NS = [NS, TRAJ_NS]
    XGSE = [XGSE, TRAJ_X]
    XGSM = [XGSM, TRAJ_X]
    YEAR = [YEAR, fix(thisyear)]
    YGSE  = [YGSE, TRAJ_Y]
    YGSM = [YGSM, TRAJ_YSM]
    ZGSE = [ZGSE, TRAJ_Z]
    ZGSM = [ZGSM, TRAJ_ZSM]
    save, BS, DOY, FYEAR, MP, NS, XGSE, XGSM, YEAR, YGSE, YGSM, ZGSE, ZGSM, $
      filename =  '/crater/observatories/wind/traj/idl/wind.traj.idl'
endfor

end

