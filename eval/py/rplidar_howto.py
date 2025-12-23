# test code taken and adapted from dartv2_tools repo
# move back and forth and get scans when bot stops
import os
import sys
# access to the drivers
sys.path.append(os.path.join(os.path.dirname(__file__),'../git')) 
import dartv2_drivers_v3.drivers_v3 as drv
import time
import numpy as np

# define scan acquisition parameters
num_scan = 0
num_scan_max = 4  # number of scans to get
sleep_between_scans = 2.0 # time between scans
# set robot motion (between scans) parameters
speed_left = 44 
speed_right = 36 # curved to the right
duration_move = 0.5
# save scan parameters for external processing
save_scan = True  # save scans in python format files (useful for debug)
save_scan_file_prefix = "rplidar_scan_"
save_scan_file_folder = "./" # folder to save the scans (here current folder)

mybot = drv.DartV2DriverV3() # define the robot

# graphics allowed only in sim mode 
# (for real robot use UDP and plot on your laptop in a separate program)
if mybot.dart_sim():
    import matplotlib.pyplot as plt
    plt.figure()

# show Lidar info and health (useful on real robot)
print (mybot.lidar.info())
print (mybot.lidar.health())

# start the Lidar
mybot.lidar.start()
# wait for the Lidar motor to spin up at right speed (useful on real robot)
time.sleep(1.0) 
# get a first dummy scan (not sure it's useful on simulation)
v_scan_def = mybot.lidar.get_scan(debug=False)

# get the scans
while num_scan < num_scan_max:
    # get the Lidar scan
    v_scan_def = mybot.lidar.get_scan(debug=False)
    num_scan += 1
    print ("Scan ",num_scan,"/",num_scan_max)
    # extract the scan data
    for iscan in range(len(v_scan_def)):
        scan_t = v_scan_def[iscan]["time"]
        scan = v_scan_def[iscan]["scan"]
        scan = np.array(scan)    
    # can only display the scan in simulation mode
    if mybot.dart_sim():
        #plt.clf()
        if num_scan > 1:
            #plt.scatter(old_scan[:,1], old_scan[:,2], c='blue', label='Previous Scan')
            plt.scatter(old_x, old_y, c='blue', label='Previous Scan %d' % (num_scan-1))
        r = scan[:,2]/1000 # from mm to m
        theta = np.radians(90.0-scan[:,1]) # angles geographic to trigonometric
        x = r * np.cos(theta)
        y = r * np.sin(theta)
        #plt.scatter(scan[:,1], scan[:,2], c='red', label='Current Scan')
        plt.scatter(x, y, c='red', label='Current Scan %d'% num_scan)
        plt.axis('equal')
        plt.xlabel('Angle')
        plt.ylabel('Distance')
        plt.xlabel('Angle')
        plt.ylabel('X')
        plt.title('Y')
        plt.legend()
        plt.draw()
        plt.pause(0.5)
        #plt.clf()
        # save old scan for next display
        old_scan = scan
        old_x = x
        old_y = y
    # save the scan in a file in save enabled
    if save_scan:
        mybot.lidar.save_scan_py_array(scan, file_name=save_scan_file_prefix + str(num_scan) + ".py",
                                       file_path=save_scan_file_folder)
    time.sleep(sleep_between_scans)

    # move a bit forward the robot for next scan
    mybot.powerboard.set_speed(speed_left, speed_right)
    time.sleep(duration_move)
    mybot.powerboard.set_speed(0,0)

    if mybot.dart_sim():
        plt.clf()

# stop the Lidar acquisition 
mybot.lidar.stop_acquisition()
time.sleep(1.0)
mybot.lidar.fullstop() # clean stop of the RP Lidar

mybot.end() # clean end of the robot mission
