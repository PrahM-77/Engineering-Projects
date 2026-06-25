import cv2
import numpy as np
 
camera = cv2.VideoCapture(0) # Set to whichever source camera is attached to

if not camera.isOpened(): 
    exit()

def camread(source): # Camera reading function that changes output to HSV, making color detection easier
    while True:
        ret, frame = source.read()

        if not ret:
            break
    
        HSV_version = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)

        cv2.imshow("cam", HSV_version)

        if cv2.waitKey(1) & 0xFF == ord('?'):
            break
    
    cv2.destroyAllWindows()
    source.release()

def getColorBounds(): # Gets color boundaries for required color
    col = input("Color Choice (R, G or B): ")
    while True:
        if col == "R":
            lower_R = np.array([0, 0, 200], dtype = "uint8")
            upper_R = np.array([0, 0, 255], dtype = "uint8")
            return lower_R, upper_R
        elif col == 'G':
            lower_G = np.array([0, 200, 0], dtype = "uint8")
            upper_G = np.array([0, 255, 0], dtype = "uint8")
            return lower_G, upper_G
        elif col == 'B':
            lower_B = np.array([200, 0, 0], dtype = "uint8")
            upper_B = np.array([255, 0, 0], dtype = "uint8")
            return lower_B, upper_B
        else:
            col = input("Invalid Choice. Must be R, G or B. Choose again: ")


def getCoordinates(cb1, cb2, camera_source): # Continously returns coordinates for center of colored object
    pass

def getServoCommand(cb1, cb2): # Decide on how to work parameter relative to everything else
    # Because of nature of main function, needs base case where nothing happens 
        # For "base case", set y and x bounds for center, based on arducam pixels. if within, pass. return 0
    return 0

def moveServos(command): # Basic servo moving function 
    if command == 0:
        pass
    else:
        return 0

def main(camera_source):
    col1, col2 = getColorBounds()
    camread(camera_source)
    while True:
        x = getCoordinates(col1, col2, camera_source)
        moveServos(getServoCommand(col1, col2)) 

# main(camera)