import cv2
import numpy as np
import time
import serial

pico = serial.Serial("COM13", 115200)

camera = cv2.VideoCapture(0)

if not camera.isOpened(): 
    exit()

def getColorBounds(): # Gets color boundaries for required color    
    col = input("Color Choice (R, G or B): ")
    blank = None
    blank_2 = None

    while True:
        if col == "R":
            lower_R_1 = np.array([0, 150, 90])
            upper_R_1 = np.array([8, 255, 255])

            lower_R_2 = np.array([172, 150, 90])
            upper_R_2 = np.array([180, 255, 255])

            return lower_R_1, upper_R_1, lower_R_2, upper_R_2
        elif col == 'G':
            lower_G = np.array([35, 70, 50])
            upper_G = np.array([85, 255, 255])

            return lower_G, upper_G, blank, blank_2
        elif col == 'B':
            lower_B = np.array([90, 70, 50])
            upper_B = np.array([140, 255, 255])
            return lower_B, upper_B, blank, blank_2
        else:
            col = input("Invalid Choice. Must be R, G or B. Choose again: ")

def getCoordinates(cb1, cb2, cb3, cb4, camera_source): # Continously returns coordinates for center of colored object

    _, frame = camera_source.read()

    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV) # Uses HSV, as it is easier to detect things in

    if cb3 is not None: # If red, requires assigning 2 masks and combining due to more boundaries being introduced
        mask_1 = cv2.inRange(hsv, cb1, cb2) 
        mask_2 = cv2.inRange(hsv, cb3, cb4)
        mask = cv2.bitwise_or(mask_1, mask_2)
    else:
        mask = cv2.inRange(hsv, cb1, cb2) # If not red, just 1 mask

    contours, _ = cv2.findContours(mask, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)

    x_cord, y_cord = None, None

    for c in contours:
        area = cv2.contourArea(c) # Gets area of each contour
        if area > 1000: # Filters out small noise
            m = cv2.moments(c)
            if m["m00"] != 0: # if total area of moment is not 0, assumes it is object
                x_cord = int(m["m10"] / m["m00"]) # = (first order for x) / (total)
                y_cord = int(m["m01"] / m["m00"]) # = (first order for y) / (total)
                break

    cv2.imshow("mask", mask)
    cv2.waitKey(1)

    return x_cord, y_cord

def camread(source, x_cord, y_cord): # Camera Display function
    radius_circle = 60
    while True:
        ret, frame = source.read()
        if not ret:
            break
        cv2.circle(frame, (x_cord, y_cord), radius_circle, color=(255,255,255), thickness=2)

        cv2.imshow("cam", frame)
        
        if cv2.waitKey(1) & 0xFF == ord('?'):
            break
    cv2.destroyAllWindows()
    source.release()

def getServoCommand(curr, s_pos):
    Bound_1, Bound_2 = 125, 375 # X Left and Right Boundaries
    while True:
        if curr < Bound_1:
            return (s_pos + 3)
        elif curr > Bound_2:
            return (s_pos - 3)
        else:
            return s_pos

def main(camera_source, serialdev):

    serialdev.write(f"{90}, {90}\n".encode())

    if serialdev.in_waiting:
        print(serialdev.readline().decode(errors="ignore").strip())

    pan_pos = 90
    tilt_pos = 90

    duration = float(33)
    end_time = time.time() + duration

    col1, col2, col3, col4 = getColorBounds()

    time.sleep(3)

    while (time.time() < end_time):
        pan_coord, tilt_coord = getCoordinates(col1, col2, col3, col4, camera_source)

        if pan_coord is None:
            continue

        pan_cmd = getServoCommand(pan_coord, pan_pos)
        tilt_cmd = getServoCommand(tilt_coord, tilt_pos)

        serialdev.write(f"{pan_cmd}, {tilt_cmd}\n".encode())

        if serialdev.in_waiting:
            print(serialdev.readline().decode(errors="ignore").strip())

        pan_pos = pan_cmd
        tilt_pos = tilt_cmd

main(camera_source=camera, serialdev=pico)
