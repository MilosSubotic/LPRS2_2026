#Sinisa Stevanovic RA58/2023
import socket
import numpy as np
import cv2
import ctypes
from os import path

lib_path = path.abspath("./libstabilizacija.so")
lib = ctypes.CDLL(lib_path)

# posto koristim c++ funkciju ovde definisem sta joj mora biti prosledjeno
lib.stabilizuj_frejm.argtypes = [
    ctypes.POINTER(ctypes.c_ubyte), # data_ptr
    ctypes.c_int,                   # width
    ctypes.c_int,                   # height
    ctypes.c_int,                   # channels
    ctypes.c_int                    # stride (bajtova po redu)
]
lib.stabilizuj_frejm.restype = None # Funkcija vraća void
# ---------------------------------

# Promenili smo ime prozora
cv2.namedWindow('ESP32-CAM Poredjenje', cv2.WINDOW_NORMAL)
print("Prozor otvoren. Čekam podatke...")

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 65536)
sock.bind(("0.0.0.0", 8888))

print("Slušam...")

data = bytearray()

while True:
    packet, addr = sock.recvfrom(4096)
    data.extend(packet)
    
    if len(data) > 2 and data[0:2] == b'\xff\xd8':
        if b'\xff\xd9' in data:
            nparr = np.frombuffer(data, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if img is not None:
                original_img = img.copy()
                
                h, w, c = img.shape
                # stride koristim zato sto opencv dodaje bitove kada ih cuva u ramu 
                # tako da finalni broj bita bude deljiv sa 4 ili 8
                stride = img.strides[0] 
                
                data_ptr = img.ctypes.data_as(ctypes.POINTER(ctypes.c_ubyte))
                
                # pozivam c++ funkciju (Ona menja isključivo 'img' bafer)
                lib.stabilizuj_frejm(data_ptr, w, h, c, stride)
                
                
                cv2.putText(original_img, "Original", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
                cv2.putText(img, "Stabilizovano", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
                

                kombinovani_prikaz = np.hstack((original_img, img))
                # w je širina jednog videa, a h/2 čuva savršene proporcije
                kombinovani_prikaz = cv2.resize(kombinovani_prikaz, (w, h // 2))
                
                # Prikazujemo spojenu sliku
                cv2.imshow('ESP32-CAM Poredjenje', kombinovani_prikaz)
                cv2.waitKey(1)
                
            data = bytearray()
    else:
        if len(data) > 0:
            data = bytearray()

    if cv2.waitKey(1) == 27: 
        break

cv2.destroyAllWindows()