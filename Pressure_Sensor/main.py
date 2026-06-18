from pressure_sensor import *
import pressure_sensor_enum as pse

if __name__== "__main__":
    sensor = PressureSensor(port="/dev/ttyUSB0")
    
    while(1):
        print(sensor)
        print("-" * 50)
        time.sleep(5)        
