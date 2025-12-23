-- V2 version with motor modelling added
-- global stuff
connexionTimeout = 0.005
cntTimeout = 0
socket = require("socket")
portNb = 30100

logOn = false
logFile = "../dartv2b.log"

portRemoteAPI =  21212

sensed = false
dataOut = {}
for i = 1, 23 do dataOut[i] = 0.0 end

leftWheelSpeed = 0.0
rightWheelSpeed = 0.0

motor_init_dt = false
motor_dt = 0.01

-- Use sleeping function of socket library
function sleep(sec) socket.select(nil, nil, sec) end

-- Get cuurent time (in sec) 
function gettime() return socket.gettime() end

distRearLast = 0.0
sonarLastTime = simGetSimulationTime()

motorVoltageMax = 8.2 -- fully charged LIPO 2S battery
motorLeftI = 0.0 -- motor left current
motorleftOmega = 0.0 -- motor left angular velocity
motorRightI = 0.0 -- motor right current
motorRightOmega = 0.0 -- motor right angular velocity
motorT0 = gettime()

-- Following function writes data to the socket (only single packet data for simplicity sake):
writeSocketData = function(client, data)
    -- print(string.format("Lua version %q", _VERSION)) 
    local header = string.char(59, 57, math.mod(#data, 256),
                               math.floor(#data / 256), 0, 0)
    -- Packet header is (in this case): headerID (59,57), dataSize (WORD), packetsLeft (WORD) but not used here
    local string_data = string.char (data:byte(1,#data))
    data_all = header .. string_data
    -- print ("send",string.len(data_all),"bytes ...")
    -- print ("header type is ",type(header))
    -- print ("data type is ",type(data))
    -- print ("string_data type is ",type(string_data))
    -- print ("data_all type is ",type(data_all))
    client:send(data_all)
end

-- Following function reads data from the socket (only single packet data for simplicity sake):
readSocketData = function(client)
    -- Packet header is: headerID (59,57), dataSize (WORD), packetsLeft (WORD) but not used here
    local header = client:receive(6)
    if (header == nil) then
        return (nil) -- error
    end
    if (header:byte(1) == 59) and (header:byte(2) == 57) then
        local l = header:byte(3) + header:byte(4) * 256
        return (client:receive(l))
    else
        return (nil) -- error
    end
end

-- Get wheel angular position (in degrees)
function getWheelAngularPosition(handle)
    ref_handle = simGetObjectHandle("Dart")
    -- angles = simGetObjectOrientation(handle, sim_handle_parent)
    angles = simGetObjectOrientation(handle, ref_handle)
    angPos = angles[3] * 180.0 / math.pi
    angPos = angPos + 180.0
    return angPos
end
-- Compute increment of odemeter 
function deltaWheelAngularPosition(curPos, lastPos, wSpeed, iw)
    local deltaPos0 = 0.0
    if wSpeed ~= 0.0 then
        deltaPos0 = curPos - lastPos
    end
    local deltaPos = deltaPos0
    -- if deltaPos0 < 0.0 then
    --     if wSpeed > 0.0 then deltaPos = deltaPos0 - 360.0 end
    --     if wSpeed < 0.0 then deltaPos = deltaPos0 + 360.0 end
    -- end
    if deltaPos < -180.0 then
        deltaPos = deltaPos + 360.0
    end
    if deltaPos > 180.0 then
        deltaPos = deltaPos - 360.0
    end
    local nTicks = 300.0
    local deltaPosTicks = deltaPos * nTicks / 360.0
    -- if (iw == 4 or iw == 3) and (math.abs(deltaPos)) > 100 then
    -- if (iw == 4 or iw == 3) and deltaPos0 ~= 0.0 then
    --     print ("delta pos ",iw,curPos,lastPos,curPos==lastPos,wSpeed,deltaPos0,deltaPos0<0.0,deltaPos,deltaPosTicks)
    -- end
    return deltaPosTicks
end



-- Motor and vehicle parameters
local motor_Resistance = 0.5         -- Armature resistance (Ohms)
local motor_Inductance = 0.01        -- Armature inductance (H)
local motor_K_t = 0.1       -- Torque constant (Nm/A)
local motor_K_e = 0.1      -- Back EMF constant (V·s/rad)
local motor_J = 0.01        -- Moment of inertia (kg·m^2)
-- local motor_B = 0.025       -- Friction coefficient (N·m·s)
local motor_B = 0.05       -- Friction coefficient (N·m·s) -- time constant increase whith B decrease

-- Vehicle-specific parameters for starting and stopping torques
local motor_T_static = 0.075  -- Static friction torque (Nm)  -- acts on vmin only
local motor_T_rolling = 0.050 -- Rolling resistance torque (Nm) -- acts on vmin and on motion stop (inertia)
local motor_T_inertia = 0.075 -- Initial inertia - acts on vmin only
-- -- Vehicle-specific parameters for starting torque
-- local motor_T_static = 0.1  -- Static friction torque (Nm)
-- local motor_T_rolling = 0.05 -- Rolling resistance torque (Nm)
-- local motor_T_inertia = 0.1 -- Initial inertia

local motor_max_voltage = 8 -- LIPO 2S battery

-- Helper function to compute the minimum voltage
function motor_compute_min_voltage(T_static, T_rolling, T_inertia, R, K_t)
    local T_start = T_static + T_rolling + T_inertia
    return (T_start * R) / K_t
end

-- Function pwm to voltage
function motor_pwm_to_voltage(pwm, max_voltage)
    return pwm / 255 * max_voltage
end

local motor_vmin = motor_compute_min_voltage(motor_T_static, motor_T_rolling, motor_T_inertia, motor_Resistance, motor_K_t)
print ("motor_vmin, pwm_min",motor_vmin, motor_vmin/motor_max_voltage*255)


-- Initial conditions
local motor_left_omega = 0.0     -- Initial angular velocity (rad/s)
local motor_left_I = 0.0         -- Initial current (A)
local motor_right_omega = 0.0     -- Initial angular velocity (rad/s)
local motor_right_I = 0.0         -- Initial current (A)
local motor_left_torque = 0.0
local motor_right_torque = 0.0
local motor_left_stops_flag = false
local motor_right_stops_flag = false
local time0 = gettime()
local target_pwm_speed_left = 0
local target_pwm_speed_right = 0
motor_time_last = gettime()
motor_init_dt = false
motor_dt = 0.05

-- Function to compute motor model
function motor_compute_model(V_applied, V_min, omega, I, torque, dtsim, stops_flag)
    local back_emf, omega_dot, dI_dt
    local time = gettime() - time0
    --print ("motor_compute_model",V_applied, V_min, omega, I, torque, dtsim, stops_flag)
    -- print ("torque",torque)
    dt = 0.005
    nb_iter = 10
    dt = dtsim / nb_iter
    for iter = 1, nb_iter do
        if V_applied >= 0 then
            if V_applied < V_min and math.abs(omega) > 0 then
                -- Motor is still moving due to inertia and friction
                torque = -motor_B * omega -- Frictional torque slowing it down
                omega_dot = torque / motor_J -- Deceleration
                omega = omega + omega_dot * dt -- Update angular velocity
                I = 0.0 -- No current since voltage is below dead zone
                -- print(string.format("t=%.3f, omega=%.3f, torque=%.3f", time, omega, torque))
                -- If torque is very small, stop the motor
                if math.abs(torque) < motor_T_rolling and not stops_flag then
                    stops_flag = true
                    -- print(string.format("Motor stops: t=%.3f, omega=%.3f, torque=%.3f", time, omega, torque))
                    omega = 0.0
                    torque = 0.0
                end
                -- print ("torque 0",torque)
            elseif V_applied >= V_min then
                stops_flag = false
                -- Normal operation
                back_emf = motor_K_e * omega

                -- Voltage across the armature circuit including inductance
                dI_dt = (V_applied - motor_Resistance * I - back_emf) / motor_Inductance
                I = I + dI_dt * dt -- Euler's method to update current

                -- Motor torque
                torque = motor_K_t * I
                -- print ("torque",torque)

                -- Equation of motion: J * dw/dt = torque - B * omega
                omega_dot = (torque - motor_B * omega) / motor_J
                omega = omega + omega_dot * dt
            else
                -- Motor is at rest (if omega = 0)
                torque = 0.0
                I = 0.0
                omega = 0.0 -- Ensure motor stops completely if not moving
            end
        else
            if V_applied > -V_min and math.abs(omega) then
                -- Motor is still moving due to inertia and friction
                torque = -motor_B * omega -- Frictional torque slowing it down
                omega_dot = torque / motor_J -- Deceleration
                omega = omega + omega_dot * dt -- Update angular velocity
                I = 0.0 -- No current since voltage is below dead zone

                -- If torque is very small, stop the motor
                if math.abs(torque) < motor_T_rolling and not stops_flag then
                    stops_flag = true
                    print(string.format("Motor stops: t=%.3f, omega=%.3f, torque=%.3f", time, omega, torque))
                    omega = 0.0
                    torque = 0.0
                end
            elseif V_applied <= -V_min then
                stops_flag = false
                -- Normal operation
                back_emf = motor_K_e * omega

                -- Voltage across the armature circuit including inductance
                dI_dt = (V_applied - motor_Resistance * I - back_emf) / motor_Inductance
                I = I + dI_dt * dt -- Euler's method to update current

                -- Motor torque
                torque = motor_K_t * I

                -- Equation of motion: J * dw/dt = torque - B * omega
                omega_dot = (torque - motor_B * omega) / motor_J
                omega = omega + omega_dot * dt
            else
                -- Motor is at rest (if omega = 0)
                torque = 0.0
                I = 0.0
                omega = 0.0 -- Ensure motor stops completely if not moving
            end
        end
    end
    return omega, I, torque, stops_flag
end


function defineLeftSpeed(cmd)
    local vapplied = motor_pwm_to_voltage(cmd, motor_max_voltage)
    motor_left_omega, motor_left_I, motor_left_torque, motor_left_stops_flag = 
        motor_compute_model(vapplied, motor_vmin, motor_left_omega, motor_left_I,motor_left_torque, motor_dt, motor_left_stops_flag) 
    --print ("left",cmd,vapplied,motor_dt,motor_left_omega, motor_left_I, motor_left_torque, motor_left_stops_flag)
    --print ("left",cmd,motor_left_torque, motor_left_omega)
    return motor_left_omega
end

function defineRightSpeed(cmd)
    local vapplied = motor_pwm_to_voltage(cmd, motor_max_voltage)
    motor_right_omega, motor_right_I, motor_right_torque, motor_right_stops_flag = 
        motor_compute_model(vapplied, motor_vmin, motor_right_omega, motor_right_I, motor_right_torque,motor_dt, motor_right_stops_flag)
    --print ("right",cmd,vapplied,motor_dt,motor_right_omega, motor_right_I, motor_right_torque, motor_right_stops_flag)
    --print ("right",cmd,motor_right_torque, motor_right_omega)
    return motor_right_omega
end

function doSensing()
    local t0 = gettime()
    local simTime = simGetSimulationTime()

    -- data sent to python control program dartv2b.py
    -- simulationTime
    -- distFront, distRear,distLeft, distRight
    -- distFrontLeft,distFrontRight
    -- encoderFrontLeft, encoderFrontRight, encoderRearLeft, encoderRearRight
    -- xRob,yRob,zRob,xAcc,yAcc,zAcc,xGyro,yGyro,zGyro
    local rb = simGetObjectPosition(dart, -1) -- -1 , location in world coordinates
    -- get accelerometer data
    tmpData = simTubeRead(accelCommunicationTube)
    if (tmpData) then accel = simUnpackFloats(tmpData) end
    -- get gyroscope data
    tmpData = simTubeRead(gyroCommunicationTube)
    if (tmpData) then gyro = simUnpackFloats(tmpData) end
    -- local stOut = "Dart Accel x="..accel[1]..", y="..accel[2]..", z="..accel[3]
    -- stOut = stOut.." , Gyro x="..gyro[1]..", y="..gyro[2]..", z="..gyro[3]
    -- print (stOut)

    dataOut = {
        simTime, distFront, distRear, distLeft, distRight, distFrontLeft,
        distFrontRight, frontLeftEncoder, frontRightEncoder, rearLeftEncoder,
        rearRightEncoder, heading, rb[1], rb[2], rb[3], accel[1], accel[2],
        accel[3], gyro[1], gyro[2], gyro[3], rearEncoderLeftReset,
        rearEncoderRightReset
    }
    for iv = 1, 3 do dataOut[13 + iv - 1] = rb[iv] end
    for iv = 1, 3 do dataOut[16 + iv - 1] = accel[iv] end
    for iv = 1, 3 do dataOut[19 + iv - 1] = gyro[iv] end

    -- sonar sensors : old version 1 sonar at a time
    -- if (cntSonar == cntActiveSonar) then
    --     cntSonar = 0
    --     if (numActiveSonar == 1) then
    --         local result, distFront1, dtPoint, dtObjHandle, dtSurfNorm =
    --             simHandleProximitySensor(sonarFront)
    --         distFront = distFront1
    --         if not (result > 0) then distFront = distMax end
    --     end
    --     if (numActiveSonar == 5) then
    --         local result, distFrontLeft1, dtPoint, dtObjHandle, dtSurfNorm =
    --             simHandleProximitySensor(sonarFrontLeft)
    --         distFrontLeft = distFrontLeft1
    --         if not (result > 0) then distFrontLeft = distMax end
    --     end
    --     if (numActiveSonar == 6) then
    --         local result, distFrontRight1, dtPoint, dtObjHandle, dtSurfNorm =
    --             simHandleProximitySensor(sonarFrontRight)
    --         distFrontRight = distFrontRight1
    --         if not (result > 0) then distFrontRight = distMax end
    --     end
    --     if (numActiveSonar == 2) then
    --         local result, distRear1, dtPoint, dtObjHandle, dtSurfNorm =
    --             simHandleProximitySensor(sonarRear)
    --         distRear = distRear1
    --         if not (result > 0) then distRear = distMax end
    --     end
    --     if (numActiveSonar == 3) then
    --         local result, distLeft1, dtPoint, dtObjHandle, dtSurfNorm =
    --             simHandleProximitySensor(sonarLeft)
    --         distLeft = distLeft1
    --         if not (result > 0) then distLeft = distMax end
    --     end
    --     if (numActiveSonar == 4) then
    --         local result, distRight1, dtPoint, dtObjHandle, dtSurfNorm =
    --             simHandleProximitySensor(sonarRight)
    --         distRight = distRight1
    --         if not (result > 0) then distRight = distMax end
    --     end
    --     numActiveSonar = numActiveSonar + 1
    --     if (numActiveSonar == 7) then numActiveSonar = 1 end
    -- end
    -- cntSonar = cntSonar + 1

    -- sonar sensors : new version 2 sets of sonars : cardinal + diagonal
    if (cntSonar == cntActiveSonar) then
        cntSonar = 0
        if (numActiveSonar == 1) then
            local result, distFront1, dtPoint, dtObjHandle, dtSurfNorm =
                simHandleProximitySensor(sonarFront)
            distFront = distFront1
            if not (result > 0) then distFront = distMax end
            if (distFront <= 0) then distFront = distMax end
        end
        if (numActiveSonar == 2) then
            local result, distFrontLeft1, dtPoint, dtObjHandle, dtSurfNorm =
                simHandleProximitySensor(sonarFrontLeft)
            distFrontLeft = distFrontLeft1
            if not (result > 0) then distFrontLeft = distMax end
            if (distFrontLeft <= 0) then distFrontLeft = distMax end
        end
        if (numActiveSonar == 2) then
            local result, distFrontRight1, dtPoint, dtObjHandle, dtSurfNorm =
                simHandleProximitySensor(sonarFrontRight)
            distFrontRight = distFrontRight1
            if not (result > 0) then distFrontRight = distMax end
            if (distFrontRight <= 0) then distFrontRight = distMax end
        end
        if (numActiveSonar == 1) then
            local result, distRear1, dtPoint, dtObjHandle, dtSurfNorm =
                simHandleProximitySensor(sonarRear)
            distRear = distRear1
            if not (result > 0) then distRear = distMax end
            if (distRear <= 0) then distRear = distMax end
        end
        if (numActiveSonar == 1) then
            local result, distLeft1, dtPoint, dtObjHandle, dtSurfNorm =
                simHandleProximitySensor(sonarLeft)
            distLeft = distLeft1
            if not (result > 0) then distLeft = distMax end 
            if (distLeft <= 0) then distLeft = distMax end
        end
        if (numActiveSonar == 1) then
            local result, distRight1, dtPoint, dtObjHandle, dtSurfNorm =
                simHandleProximitySensor(sonarRight)
            distRight = distRight1
            if not (result > 0) then distRight = distMax end
            if (distRight <= 0) then distRight = distMax end
        end
        numActiveSonar = numActiveSonar + 1
        if (numActiveSonar == 3) then numActiveSonar = 1 end
    end
    cntSonar = cntSonar + 1


    -- print ("Sonars : "..distFront..", "..distRear..", "..distLeft..", "..distRight)
    -- if (distRear ~= distRearLast) then
    --     distRearLast = distRear
    --     sonarNowTime = simGetSimulationTime()
    --     sonarDt = sonarNowTime - sonarLastTime
    --     sonarLastTime = sonarNowTime
    --     print("Sonar Rear changed : "..distRear..", dt = "..sonarDt)
    -- end
    dataOut[2] = distFront
    dataOut[3] = distRear
    dataOut[4] = distLeft
    dataOut[5] = distRight
    dataOut[6] = distFrontLeft
    dataOut[7] = distFrontRight

    -- update encoders with relative orientation of the wheel (wrt joint axis)
    for iw = 1, #wheelId do
        handle = wheelId[iw]
        -- print ("wheel",iw,handle,lastRelativeOrientation[iw])
        relativeOrientation = getWheelAngularPosition(handle)
        currentOrientationTime = simGetSimulationTime()
        -- print (iw,relativeOrientation,lastRelativeOrientation[iw])
        if iw == 1 or iw == 3 then -- left wheels
            wheelSpeed = leftWheelSpeed
        end
        if iw == 2 or iw == 4 then -- right wheels
            wheelSpeed = rightWheelSpeed
        end
        -- print (iw,wheelCnt[iw])
        if iw == 1 or iw == 2 then -- front wheels (count ++)
            dCnt = deltaWheelAngularPosition(relativeOrientation,
                                             lastRelativeOrientation[iw],
                                             wheelSpeed)
            -- print (iw,"dcnt",dCnt)
            wheelCnt[iw] = wheelCnt[iw] + dCnt
            wheelCnt[iw] = wheelCnt[iw] % 65536.0
        end
        if iw == 3 or iw == 4 then -- rear wheels (count --)
            dCnt = deltaWheelAngularPosition(relativeOrientation,
                                             lastRelativeOrientation[iw],
                                             wheelSpeed)
            -- print (iw,"dcnt",dCnt)
            wheelCnt[iw] = wheelCnt[iw] - dCnt
            wheelCnt[iw] = wheelCnt[iw] % 65536.0
        end
        -- print (iw,wheelCnt[iw])
        lastRelativeOrientation[iw] = relativeOrientation
        lastOrientationTime[iw] = currentOrientationTime
    end
    frontLeftEncoder = wheelCnt[1]
    frontRightEncoder = wheelCnt[2]
    rearLeftEncoder = wheelCnt[3]
    rearRightEncoder = wheelCnt[4]
    -- print ("wheel cnt ",wheelCnt[1],wheelCnt[2],wheelCnt[3],wheelCnt[4])
    -- transformation to 16 bits integers is now done in python 
    dataOut[8] = frontLeftEncoder
    dataOut[9] = frontRightEncoder
    dataOut[10] = rearLeftEncoder
    dataOut[11] = rearRightEncoder

    -- update heading
    local handle = simGetObjectHandle("Dart")
    local angles = simGetObjectOrientation(handle, -1)
    for i = 1, #angles do angles[i] = angles[i] * 180.0 / math.pi end
    -- print ("heading",angles[1],angles[2],angles[3])
    heading = -angles[3] -- north along X > 0
    dataOut[12] = heading
end

function sysCall_init()
    -- do some initialization here
    -- get Main robot
    dart = simGetObjectHandle("Dart")

    -- get handles of sonar sensor
    sonarFrontLeft = simGetObjectHandle("SonarFrontLeft")
    sonarFrontRight = simGetObjectHandle("SonarFrontRight")
    sonarLeft = simGetObjectHandle("SonarLeft")
    sonarRight = simGetObjectHandle("SonarRight")
    sonarFront = simGetObjectHandle("SonarFront")
    sonarRear = simGetObjectHandle("SonarRear")
    distMax = 99.9
    distFront = distMax
    distFrontLeft = distMax
    distFrontRight = distMax
    distRear = distMax
    distLeft = distMax
    distRight = distMax

    frontRightMotor = simGetObjectHandle("MotorFR")
    frontLeftMotor = simGetObjectHandle("MotorFL")
    rearRightMotor = simGetObjectHandle("MotorRR")
    rearLeftMotor = simGetObjectHandle("MotorRL")

    -- initialize communication tube with accelerometers and gyroscopes
    accelCommunicationTube = simTubeOpen(0, 'accelerometerData' ..
                                             simGetNameSuffix(nil), 1)
    accel = {0.0, 0.0, 0.0}
    gyroCommunicationTube = simTubeOpen(0, 'gyroData' .. simGetNameSuffix(nil),
                                        1) -- put this in the initialization phase
    gyro = {0.0, 0.0, 0.0}

    frontLeftEncoder = 0.0
    frontRightEncoder = 0.0
    rearLeftEncoder = 65535.0
    rearRightEncoder = 65535.0
    rearEncoderLeftReset = 0.0
    rearEncoderRightReset = 0.0
    -- rearWheelPosLastLeft = simGetJointPosition(rearLeftMotor)
    -- rearWheelPosLastRight = simGetJointPosition(rearRightMotor)
    -- frontWheelPosLastLeft = simGetJointPosition(frontLeftMotor)
    -- frontWheelPosLastRight = simGetJointPosition(frontRightMotor)

    heading = 0.0

    -- get orientation of Dart's body
    lastRelativeOrientation = {}
    lastOrientationTime = {}
    wheelCnt = {}
    wheelId = {}
    wheels = {"WheelFL", "WheelFR", "WheelRL", "WheelRR"}
    for i = 1, #wheels do
        handle = simGetObjectHandle(wheels[i])
        wheelId[#wheelId + 1] = handle
        lastRelativeOrientation[#lastRelativeOrientation + 1] =
            getWheelAngularPosition(handle)
        lastOrientationTime[#lastOrientationTime + 1] = simGetSimulationTime()
        wheelCnt[#wheelCnt + 1] = 0.0
    end

    cnt = 0
    cntDispl = 1000
    cntSonar = 0
    numActiveSonar = 1
    cntActiveSonar = 1 -- 5

    -- init socket
    simAddStatusbarMessage('start virtual DartV2 at port ' .. portNb)
    socket = require("socket")
    srv = assert(socket.bind('0.0.0.0', portNb))
    if (srv == nil) then
        print("bad connect")
    else
        ip, port = srv:getsockname()
        print("server ok at " .. ip .. " on port " .. port)
        simAddStatusbarMessage("server ok at " .. ip .. " on port " .. port)
        serverOn = true
        -- srv:settimeout(connexionTimeout)
        print("connexion granted !!! ")
    end

    print ("init remote API (old) at port "..portRemoteAPI)
    debugRemoteApi=false
    --simRemoteApi.start(portRemoteAPI,2000,debugRemoteApi)
    simRemoteApi.start(portRemoteAPI,250,debugRemoteApi)
end

-- actuate before sensing
function sysCall_actuation()
    -- put your actuation code here
    if sensed then
        sensed = false
        srv:settimeout(connexionTimeout)
        clt1 = srv:accept()
        if clt1 == nil then
            cntTimeout = cntTimeout + 1
            -- print ("accept timeout")
            -- serverOn = false
            -- srv:close()
        else
            clt1:settimeout(connexionTimeout)
            dataIn = readSocketData(clt1)
            if dataIn ~= nil then
                -- print (dataIn)
                targetCmd = simUnpackFloats(dataIn)
                if targetCmd[5] ~= 0.0 or targetCmd[6] ~= 0.0 then
                    print("received", targetCmd[1], targetCmd[2], targetCmd[3],
                          targetCmd[4], targetCmd[5], targetCmd[6])
                end
                local doLog = targetCmd[1]
                if doLog == 1.0 and not logOn then
                    -- open new log file and start to log data
                    file = io.open(logFile, "w")
                    file:write("Hello!", "\n")
                    file:close()
                    logOn = true
                end
                if doLog == 0.0 and logOn then
                    -- stop data log in file
                    logOn = false
                end
                speedCmdNew = targetCmd[4]
                if speedCmdNew == 1 then
                    print("set cmd speed", targetCmd[2], leftWheelSpeed, targetCmd[3], rightWheelSpeed)
                    target_pwm_speed_left = targetCmd[2]
                    target_pwm_speed_right = targetCmd[3]
                end
                rearEncoderLeftResetRx = targetCmd[5]
                rearEncoderRightResetRx = targetCmd[6]
                if rearEncoderLeftResetRx == 1.0 then
                    wheelCnt[3] = 0
                    rearEncoderLeftReset = -1.0
                else
                    rearEncoderLeftReset = 0.0
                end
                dataOut[22] = rearEncoderLeftReset
                if rearEncoderRightResetRx == 1.0 then
                    wheelCnt[4] = 0
                    rearEncoderRightReset = -1.0
                else
                    rearEncoderRightReset = 0.0
                end
                dataOut[23] = rearEncoderRightReset
                -- print ("sz",table.getn(dataOut))
                -- Pack the data as a string:srv:close()
                dataPacked = simPackFloats(dataOut)
                -- Send the data:
                writeSocketData(clt1, dataPacked)
                clt1:send(dataIn)
                -- print (string.len(dataPacked)," bytes")
                -- print ("dataOut sent ... ")

                -- rearEncoderLeftReset = 0.0
                -- rearEncoderRightReset = 0.0     
            else
                print("no data")
            end
            clt1:close()
        end
    end
    -- Simulation parameters
    if motor_init_dt == false then
        motor_time_last = gettime()
        motor_init_dt = true
    else
        motor_time_now = gettime()
        motor_dt = motor_time_now - motor_time_last
        motor_time_last = motor_time_now
    end
    leftWheelSpeed = defineLeftSpeed(target_pwm_speed_left)
    rightWheelSpeed = defineRightSpeed(target_pwm_speed_right)
    simSetJointTargetVelocity(frontRightMotor, rightWheelSpeed)
    simSetJointTargetVelocity(frontLeftMotor, leftWheelSpeed)
    simSetJointTargetVelocity(rearRightMotor, rightWheelSpeed)
    simSetJointTargetVelocity(rearLeftMotor, leftWheelSpeed)
end

function sysCall_sensing()
    -- put your sensing code here
    doSensing()
    sensed = true
end

function sysCall_cleanup()
    -- do some clean-up here
    print("cleanup")
end

-- See the user manual or the available code snippets for additional callback functions and details
