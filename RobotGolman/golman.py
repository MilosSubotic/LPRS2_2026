import time
import serial
import cv2
import numpy as np
from picamera2 import Picamera2

# UART
ser = serial.Serial('/dev/ttyS0', 9600, timeout=1)
time.sleep(2)

print("PRO MAX golman spreman...")

picam = None

# tracking
prev_x = 145
prev_t = time.time()

last_sent_angle = 90
servo_angle = 90

try:

    while True:

        if ser.in_waiting > 0:

            izbor = ser.read()[0]

            if izbor == 0:

                print("[STOP]")

                if picam is not None:
                    try:
                        picam.stop()
                        picam.close()
                    except:
                        pass

                    picam = None

                continue

            # SINGLEPLAYER
            if izbor == 1:

                print("[PRO MAX MODE]")

                picam = Picamera2()

                picam.configure(
                    picam.create_video_configuration(
                        main={"size": (320, 240)}
                    )
                )

                picam.start()

                time.sleep(1)

                prev_x = 145
                prev_t = time.time()

                servo_angle = 90
                last_sent_angle = 90

                while True:

                    if ser.in_waiting > 0:

                        prekid = ser.read()[0]

                        if prekid == 0:
                            print("[PREKID]")
                            break

                    frame = picam.capture_array()

                    if frame is None:
                        continue

                    frame = frame[40:240, :]

                    hsv = cv2.cvtColor(
                        frame,
                        cv2.COLOR_RGB2HSV
                    )


                    lower_orange = np.array(
                        [5, 120, 120]
                    )

                    upper_orange = np.array(
                        [25, 255, 255]
                    )

                    mask = cv2.inRange(
                        hsv,
                        lower_orange,
                        upper_orange
                    )

                    kernel = np.ones(
                        (5, 5),
                        np.uint8
                    )

                    mask = cv2.erode(
                        mask,
                        kernel,
                        iterations=1
                    )

                    mask = cv2.dilate(
                        mask,
                        kernel,
                        iterations=2
                    )

                    contours, _ = cv2.findContours(
                        mask,
                        cv2.RETR_EXTERNAL,
                        cv2.CHAIN_APPROX_SIMPLE
                    )

                    lopta_nadjena = False

                    if len(contours) > 0:

                        largest = max(
                            contours,
                            key=cv2.contourArea
                        )

                        area = cv2.contourArea(
                            largest
                        )

                        if area > 80:

                            M = cv2.moments(
                                largest
                            )

                            if M["m00"] != 0:

                                lopta_nadjena = True

                                x = int(
                                    M["m10"] /
                                    M["m00"]
                                )

                                now = time.time()

                                dt = now - prev_t

                                prev_t = now

                                vx = (
                                    (x - prev_x) / dt
                                    if dt > 0 else 0
                                )

                                prev_x = x

                                prediction_time = 0.15

                                predicted_x = (
                                    x +
                                    vx *
                                    prediction_time
                                )

                                predicted_x = max(
                                    0,
                                    min(
                                        320,
                                        predicted_x
                                    )
                                )

                                center = 145

                                error = (
                                    predicted_x -
                                    center
                                )

                                if abs(error) < 20:
                                    error = 0

                                norm = (
                                    error /
                                    145.0
                                )

                                norm *= 3.0

                                target_angle = int(
                                    90 -
                                    norm * 80
                                )

                                target_angle = max(
                                    30,
                                    min(
                                        150,
                                        target_angle
                                    )
                                )

                                servo_angle = int(
                                    0.65 * servo_angle +
                                    0.35 * target_angle
                                )

                                if abs(
                                    servo_angle -
                                    last_sent_angle
                                ) >= 3:

                                    ser.write(
                                        bytes(
                                            [servo_angle]
                                        )
                                    )

                                    last_sent_angle = (
                                        servo_angle
                                    )

                    # NEMA LOPTE
                    if not lopta_nadjena:

                        servo_angle = int(
                            0.9 * servo_angle +
                            0.1 * 90
                        )

                        if abs(
                            servo_angle -
                            last_sent_angle
                        ) >= 3:

                            ser.write(
                                bytes(
                                    [servo_angle]
                                )
                            )

                            last_sent_angle = (
                                servo_angle
                            )

                    time.sleep(0.003)

                print("Gasim kameru...")

                picam.stop()
                picam.close()

                picam = None

            # MULTIPLAYER
            elif izbor == 2:

                print("[MULTIPLAYER]")

                while True:

                    if ser.in_waiting > 0:

                        prekid = ser.read()[0]

                        if prekid == 0:
                            break

                    time.sleep(0.1)

except KeyboardInterrupt:

    print("\nGasenje programa...")

    if picam is not None:

        try:
            picam.stop()
            picam.close()
        except:
            pass
