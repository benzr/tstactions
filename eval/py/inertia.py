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
    duration = 1.0

    try: 
        side = sys.argv[1]
        if side not in ['left','right']:
            side = 'right'
    except:
        side = 'right'

    # start the robot
    encleft0, encright0 = mybot.encoders.read_encoders()
    time0= time.time()
    mybot.powerboard.set_speed (spd,spd)
    time.sleep(duration)
    mybot.powerboard.set_speed (0,0)
    time1= time.time()
    encleft1, encright1 = mybot.encoders.read_encoders()

    print ("encoders at start:",encleft0,encright0)
    print ("encoders at stop:",encleft1,encright1)
    print ("delta time:",time1-time0)
    print ("delta encoders left:",encleft1-encleft0)
    print ("delta encoders right:",encright1-encright0)
    time.sleep(0.1)
    encleft2 = encleft1
    encright2 = encright1
    # wait for the robot to stop
    while (True):
        time2= time.time()
        encleft3, encright3 = mybot.encoders.read_encoders()
        deltaLeft = encleft3-encleft2
        deltaRight = encright3-encright2
        if (deltaLeft == 0 and deltaRight == 0):
            break
        encleft2 = encleft3
        encright2 = encright3
        time.sleep(0.1)

    print ("encoders at end of motion:",encleft3,encright3)
    print ("delta time:",time2-time1)
    print ("delta encoders left:",encleft3-encleft1)
    print ("delta encoders right:",encright3-encright1)

    delta_time = time2-time1
    if side == 'right':
        delta_enc = encright3-encright1
    else:
        delta_enc = encleft3-encleft1
    print ("using side:",side)
    mass = 6.75 + 4 * 0.3 # kg
    print ("mass:",mass,"kg")
    wheel_radius = 0.125/2 # m
    nb_ticks_per_revol = 300
    distance = -(delta_enc * 2 * np.pi * wheel_radius) / nb_ticks_per_revol # m

    #inertia = -(delta_enc * 2 * np.pi * wheel_radius) / (delta_time * nb_ticks_per_revol) # kg.m^2
    momentum = mass * 2 * distance / delta_time # N.m
    print ("distance:",distance,"m")
    print ("time:",delta_time,"s")
    #print ("inertia:",inertia,"kg.m^2")
    print ("momentum:",momentum)

    mybot.end() # clean end of the robot mission