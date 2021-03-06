pro azimuth, cups, reset_angle, rmid_time, fcspectra, specmax, cup1_angles, cup2_angles 

;this is a program that calculates the exact azimuth angle of the measurements

offset = 180.0             ;the angle between the cup one and cup two detector

cup1_angles = fltarr(20, (specmax+1)) ;arrays for the measurement angles for
cup2_angles = fltarr(20, (specmax+1)) ;cup one and cup two

cup1 = where (cups eq 1)   ;cups is an array that contains the cup numbers
cup2 = where (cups eq 2)   ;these two lines seperates the information

cup1_meastime = rmid_time[cup1]  ;the measured times are sorted by cup
cup2_meastime = rmid_time[cup2]

;calculate the twenty azimuth angles for each cup, for each spectra

for q = 1, specmax do begin

cup1_angles[*, q] = reset_angle + (cup1_meastime * 360 / fcspectra[q].spin_period)
cup2_angles [*, q] = reset_angle + offset + (cup2_meastime * 360 / fcspectra[q].spin_period)

endfor

;because cup two is offset from cup one, the calculated angle here can 
;exceed 360.  These two lines account for that, and keep the angle
;between 0 and 360

too_big = where(cup2_angles gt 180.0, ntoo_big) 
 if ntoo_big gt 0 then cup2_angles[too_big]= cup2_angles[too_big] - 360.0

end
