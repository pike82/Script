Print ("Intilising other CPU's").

Print "Old Config:IPU Setting:" + Config:IPU.
Set Config:IPU to 1000.// this needs to be set based on the maximum number of processes happening at once, usually 500 is enought unless its going to be a very heavy script such as a suicide landing script which may require upto 1500
Print "New Config:IPU Setting:" + Config:IPU.
Set Config:Stat to false.

intParameters().

PRINT ("Downloading libraries").
//download dependant libraries first

FOR file IN LIST(
	"Util_Launch",
	"Launch_atm",
	"OrbMnvs",
	"orbRV",
	"OrbMnvNode",
	"Landing_atm",
	"Util_Vessel"){ 
		//Method for if to download or download again.
		IF (not EXISTS ("1:/" + file)) or (not runMode["runMode"] = 0.1)  { //Want to ignore existing files within the first runmode.
			gf_DOWNLOAD("0:/Library/",file,file).
			wait 0.001.	
		}
		RUNPATH(file).
	} 
Rel_Parameters().

Function Mission_runModes{
		
	if runMode["runMode"] = 0.1 { 
		Print "Run mode is:" + runMode["runMode"].

		Set sv_targetInclination to ff_launchwindow(mun).
		Print "Target inc: " + sv_targetInclination.
		Rel_Parameters().
		ff_preLaunch().
		ff_liftoff().
		gf_set_runmode("runMode",1.1).
	}	

	else if runMode["runMode"] = 1.1 { 
		Print "Run mode is:" + runMode["runMode"].
		ff_liftoffclimb() .
		ff_GravityTurnAoA(-0.9,"boost",1.0, 0.03, 0.15, 0.45, 0.4).
		ff_Coast().
		Print "Free CPU Space: " + core:currentvolume:FreeSpace.
		ff_Circ("apo").
		lock throttle to 0.
		ff_COMMS().
		Print "Deploying Solar".
		Panels on.
		Wait 10.
		gf_set_runmode("runMode",2.1).
	}	
	
	else if runMode["runMode"] = 2.1 { 
		Print "Run mode is:" + runMode["runMode"].
		ff_AdjPlaneInc(0, Mun).
		Wait 1.
		//ff_BodyTransfer(Mun, 10000, 1000).
		ff_Hohmann(Mun, 200000, Ship:BODY, 75).
		Wait 1.
		Lock Steering to Ship:Prograde + R(90,0,0). 
		gf_set_runmode("runMode",3.1).
	}	
	
	else if runMode["runMode"] = 3.1 { 
		Print "Run mode is:" + runMode["runMode"].
		Local nexttime is time:seconds + orbit:nextpatchETA.
		
		Until time:seconds - 300 > nexttime{
			Wait 10.
		}
		gf_set_runmode("runMode",3.2).
	}	
	
	else if runMode["runMode"] = 3.2 { 
		Print "Run mode is:" + runMode["runMode"].
		ff_Circ("Per").
		Wait 10.
		Lock Steering to Ship:Prograde + R(90,0,0). 
		Wait 10.0.
		gf_set_runmode("runMode",3.3).
	}	
	else if runMode["runMode"] = 3.3 { 
		Print "Run mode is:" + runMode["runMode"].
		ff_AdjOrbInc (75).
		Wait 10.
		Lock Steering to Ship:Prograde + R(90,0,0). 
		Wait 10.0.
		gf_set_runmode("runMode",0).
	}	

	
} /// end of function runmodes


Function intParameters {
	///////////////////////
	//Ship Particualrs
	//////////////////////
	Global sv_maxGeeTarget to 5.5.  //max G force to be experienced

	Global sv_shipHeightflight to 4.1. // the height of the ship from the ground to the ship base part
	Global sv_gimbalLimit to 100. //Percent limit on the Gimbal is (10% is typical to prevent vibration however may need higher for large rockets with poor control up high)
	Global sv_MaxQLimit to 0.2. //0.3 is the Equivalent of 40Kpa Shuttle was 30kps and others like mercury were 40kPa.
	
	///////////////////////
	//Ship Variable Inital Launch Parameters
	///////////////////////
 	Global sv_targetInclination to 0. //Desired Inclination
    Global sv_targetAltitude to 80000. //Desired Orbit Altitude from Sea Level
    Global sv_ClearanceHeight to 200. //Intital Climb to Clear the Tower and start Pitchover Maneuver
    Global sv_anglePitchover to 88. //Final Pitchover angle
	Global sv_landingtargetLATLNG to latlng(-0.0972092543643722, -74.557706433623). // This is for KSC but use target:geoposition if there is a specific target vessel on the surface that can be used.
	Global sv_prevMaxThrust to 0. //used to set up for the flameout function
	
	//////////////////////////////////////////
	///Ship PID Control variables//////////////////
	/////////////////////////////////////////
	
//===ALTITUDE====
	//Desired vertical speed
	Global sv_PIDALT to PIDLOOP(0.9, 0.0, 0.0005, -5, 10).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	//Desired throttle setting
	Global sv_PIDThrott to PIDLOOP(0.1, 0.2, 0.005, 0.05, 1).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	

//===LATITUDE (North) ====
	//Desired velocity
	Global sv_PIDLAT to PIDLOOP(1, 0.0, 5, -0.005, 0.005).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	//Desired direction
	Global sv_PIDNorth to PIDLOOP(5000, 0, 2000, -2.5, 2.5).// SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	

//===LONGITUDE (East)====
	//Desired velocity
	Global sv_PIDLONG to PIDLOOP(1, 0, 5, -0.005, 0.005).// SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).			
	//Desired direction	 
	Global sv_PIDEast to PIDLOOP(5000, 0, 2000, -2.5, 2.5).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	

//===Direction ====
	//Desired velocity
	Global sv_PIDDIST to PIDLOOP(0.1, 0, 0.5, -2, 2).// SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).			
	//Desired direction	 
	Global sv_PIDDIR to PIDLOOP(1.5, 0, 0, -2.5, 2.5).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	
	///////////////////////
	//Global Locked Parameters
	//////////////////////
//Locations	
	lock gl_shipLatLng to SHIP:GEOPOSITION. // provides the current co-ordiantes
	lock gl_surfaceElevation to gl_shipLatLng:TERRAINHEIGHT. // provides the height at the current co-ordinates
	lock gl_baseALTRADAR to max( 0.1, min(ship:Altitude , ship:Altitude - gl_surfaceElevation - sv_shipHeightflight)). // Note: this assumes the root part is on the top of the ship.
		
	Print "end of parameters".
}/////End of function

Function Rel_Parameters {

	Global sv_intAzimith TO ff_LaunchAzimuth(sv_targetInclination,sv_targetAltitude).

//Engines 
	Lock gl_Grav to ff_Gravity().
    Lock gl_TWR to MAX( 0.001, MAXTHRUST / (ship:MASS*gl_Grav["G"])). //Provides the current thrust to weight ratio
	Lock gl_TWRTarget to min( gl_TWR, sv_maxGeeTarget*(9.81/gl_Grav["G"])). // enables the trust to be limited based on the TWR which is dependant on the local gravity compared to normal G forces
	Lock gl_TVALMax to min(
							gl_TWRTarget/gl_TWR, 
							(sv_MaxQLimit / max(0.01,SHIP:Q))^2
							). //use this to set the Max throttle as the TWR changes with time or the ship reaches max Q for throttleable engines.
	//Lock Throttle to gl_TVALMax. // this is the command that will need to be used in individual functions when re-setting the throttle after making the throttle zero.

	Print "end of Rel parameters".
}/////End of function
	
	