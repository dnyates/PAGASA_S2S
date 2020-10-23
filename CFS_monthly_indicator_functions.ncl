; **********************************************
; Functions for calculating monthly indicators
; **********************************************


function compute_monthly_et5mm(refevt)
local et5mm		
begin

	et5mm			= refevt
        et5mm@_FillValue        = 1.e20
        et5mm			= where(refevt.gt.5.,1,0)
	et5mm_monthly		= calculate_monthly_values(et5mm,"sum",0,False)
	et5mm_monthly@units 	= "days"
	et5mm_monthly@long_name = "number of days with refevt >5mm"
	return(et5mm_monthly)

end 


