import os
import sys
# access to the drivers
sys.path.append(os.path.join(os.path.dirname(__file__),'../git')) 
try:
    import dartv2_drivers_v3.drivers_v3 as drv
except:
    print ('could not import dartv2_drivers_v3.drivers_v3, try adding .. to sys.path')
    sys.path.append(os.path.join(os.path.dirname(__file__),'..'))
import dartv2_drivers_v3.drivers_v3 as drv
import time
import numpy as np

if __name__ == "__main__":
    mybot = drv.DartV2DriverV3()
    
    spd = 100
    try:
        spd = int(sys.argv[1])     
    except:
        pass

    print ("go ...")
    mybot.powerboard.set_speed (spd,spd)
    time.sleep(1.0)
    print ("stop ...")
    mybot.powerboard.set_speed (0,0)
    time.sleep(2.0)
    print ("back ...")
    mybot.powerboard.set_speed (-spd,-spd)
    time.sleep(1.0)
    print ("stop ...")
    mybot.powerboard.set_speed (0,0)
    time.sleep(2.0)
    print ("done ...")
    
    mybot.end() # clean end of the robot mission

