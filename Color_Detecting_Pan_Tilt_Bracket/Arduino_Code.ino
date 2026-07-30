#include <Servo.h>

Servo servo_pan;
Servo servo_tilt;

void setup() {
    Serial.begin(115200);

    servo_pan.attach(10);    // Pan servo
    servo_tilt.attach(11);  // Tilt servo

    // Start centered
    servo_pan.write(90);
    servo_tilt.write(90);

    Serial.println("Arduino Pan/Tilt Controller Ready");
}

void loop() {
    // Check if a full line has arrived
    if (Serial.available()) {
        String line = Serial.readStringUntil('\n');
        line.trim();

        if (line.length() == 0) {
            return;  // ignore empty lines
        }

        // Find comma
        int commaIndex = line.indexOf(',');
        if (commaIndex == -1) {
            Serial.print("Invalid command: ");
            Serial.println(line);
            return;
        }

        // Extract pan and tilt values
        String panStr = line.substring(0, commaIndex);
        String tiltStr = line.substring(commaIndex + 1);

        int panAngle = panStr.toInt();
        int tiltAngle = tiltStr.toInt();

        // Clamp angles to safe range
        panAngle = constrain(panAngle, 0, 180);
        tiltAngle = constrain(tiltAngle, 0, 180);

        // Move servos
        servo_pan.write(panAngle);
        servo_tilt.write(tiltAngle);

        // Feedback to Python
        Serial.print("Pan: ");
        Serial.print(panAngle);
        Serial.print("  Tilt: ");
        Serial.println(tiltAngle);
    }
}
