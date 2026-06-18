from pymodbus.client import ModbusSerialClient
import time
import pressure_sensor_enum as pse

class PressureSensor:
    #REGISTER ADDRESSES
    PRESSURE_VALUE_REG = 0x0001             #MINIMUM PRESSURE is  1.01 bar
                                            #MAXIMUM PRESSURE is  10.0 bar
    PRESSURE_TARGET_VALUE_REG = 0x0010
    HIGHER_LIMIT_REG = 0x0011
    LOWER_LIMIT_REG = 0x0012
    PRESSURE_MODE_WORKING_REG = 0x0013 
                              # 0 - NORMAL /EASY
                              # 1 - Histeresis
                              # 2 - comparator (between low and high borders)
    PRESSURE_COLOR_REG = 0x0014 
                       # 0 - RED ON (NPN)
                       #_1 - GREEN ON (NPN)
                       # 2 - RED ALWAYS
                       # 3 - GREEN ALWAYS
    NORMALY_OPEN_REG = 0x0016 
                        # 0 - Normaly open
                        # 1 - Normaly closed

    PRESSURE_UNIT_REG = 0x0015  # Units value:
                                    # 0 - MPA
                                    # 1 - KPA
                                    # 2 - KGF
                                    # 3 - BAR
                                    # 4 - PSI
    NPN_STATUS_REG = 0x0003 

    def __init__(self, port, highLimit=6.0, lowLimit = 5.0, targetValue = 6.0, mode = pse.WorkingMode.WINDOW_COMPARATOR, unit = pse.Units.BAR, measureLogic = pse.MeasureLogic.POSITIVE):

        self.port = port
        self.instance = ModbusSerialClient(
            port = port,
            baudrate = 19200,
            bytesize = 8,
            parity = 'N',
            stopbits = 1,
            timeout = 1
        ) 
        self.setUnit(unit)
        self.setMeasureLogic(measureLogic)
        self.setMode(highLimit,lowLimit,targetValue,mode)

    def __str__(self):
        return f"Current pressure: {self.getCurrentValue()}\nLow limit is {self.getLowLimit()}\nHigh limit is: {self.getHighLimit()}\nTarget value is: {self.getTargetValue()}\nNPN OUT value: {self.getNPNStatus()}\nWork mode: {self.getWorkMode()}"
    

    def connect(self):
        if self.instance.connect() == False:
            print("Nije moguce povezati se na uredjaj")
        else:
            print("Uspesno ste se povezali na uredjaj")

    def getCurrentValue(self):
        try:
            value = self.instance.read_input_registers(address = self.PRESSURE_VALUE_REG)
            ret = value.registers[0]/100
            #print(f"Current pressure is: {ret}")
            return ret
        except:
            raise ValueError("An error occurred. It is not possible to read the current value from the register")

    def getLowLimit(self):
        value = self.instance.read_holding_registers(address = self.LOWER_LIMIT_REG)
        #print(f"Low limit is: {value.registers[0]}")
        return value.registers[0]

    def getHighLimit(self):
        value = self.instance.read_holding_registers(address = self.HIGHER_LIMIT_REG)
        #print(f"High limit is: {value.registers[0]}")
        return value.registers[0]

    def getTargetValue(self):
        value = self.instance.read_holding_registers(address = self.PRESSURE_TARGET_VALUE_REG)
        print(f"Target value is: {value.registers[0]}")
        return value.registers[0]

    def getNPNStatus(self):
        value = self.instance.read_holding_registers(address = self.NPN_STATUS_REG)
        #print(f"Vrednost na izlazu NPN je: {value.registers[0]}")
        return value.registers[0]

    def isGoodValue(self, value, name = "Value"):
        try:
            if value > 10.0 or value < 1.01:
                raise ValueError(f"{name} is out of range (1.01 - 10.0 BAR)")
        except:
            raise ValueError("Value is not a number")

    def setHighLimit(self, value):
        #if self.unit != pse.Units.BAR:
        #    self.setUnit(pse.Units.BAR)
        self.isGoodValue(value, "High limit")
        try:
            value = int(value*100)
            self.instance.write_register(address = self.HIGHER_LIMIT_REG, value = value)
            self.highLimit = value/100
        except:
            raise ValueError("An error occurred when entering the high limit in the register.")

    def setLowLimit(self, value):
        #if self.unit != pse.Units.BAR:
        #    self.setUnit(pse.Units.BAR)
        self.isGoodValue(value, "Low limit")
        try:
            value = int(value*100)
            self.instance.write_register(address = self.LOWER_LIMIT_REG, value = value)
            self.lowLimit = value/100
        except:
            raise ValueError("An error occurred when entering the low limit in the register.")
        
    def setTargetValue(self, value):
        #if self.unit != pse.Units.BAR:
        #    self.setUnit(pse.Units.BAR)
        self.isGoodValue(value, "Target value")
        try:
            value = int(value*100)
            self.instance.write_register(address = self.PRESSURE_TARGET_VALUE_REG, value = value)
            self.targetValue = value/100
        except:
            raise ValueError("An error occurred when entering the target value in the register.")
        
    def setMode(self, highLimit, lowLimit = None, targetValue = None, mode = pse.WorkingMode.WINDOW_COMPARATOR):
        if mode not in pse.WorkingMode: # WORKING MODE
            raise ValueError("Incorrect operating mode. Allowed operating modes: EASY, HYSTERESIS and WINDOW_COMPARATOR")
        else:
            try:
                self.instance.write_register(address = self.PRESSURE_MODE_WORKING_REG, value = mode.value)
                self.mode = mode
            except:
                raise ValueError("An error occurred when entering the operating mode in the register.")
        
        #self.setHighLimit(highLimit)
        #self.targetValue = None

        if mode == pse.WorkingMode.EASY:
            #self.lowLimit = lowLimit
            self.setTargetValue(targetValue)

        else:
            self.setLowLimit(lowLimit)
            self.setHighLimit(highLimit)
            if targetValue != None:
                self.setTargetValue(targetValue)  # ovo je upitno??
            
    def setPullUpResistor(self, obj = pse.NPNstatus.NO):
        if obj not in pse.NPNstatus:
            raise ValueError("Incorrect NPN status mode. Allowed NPN status modes: NO (Normaly open) and NC (Noraly closed), HYSTERESIS and WINDOW_COMPARATOR")
        try:
            self.instance.write_register(address = self.NORMALY_OPEN_REG, value = obj.value)
        except:
            raise ValueError("An error occurred when entering the value in the NPN register (Normaly open/Normaly closed).")
        
    def setUnit(self, unit = pse.Units.BAR):
        if unit not in pse.Units:
            raise ValueError("The unit entered is not allowed. Possible values ​​for the units are: BAR, MPA, KPA, KGF, BAR, PSI")
        else:
            try:
                self.instance.write_register(address = self.PRESSURE_UNIT_REG, value = unit.value)
                self.unit = unit
            except:
                raise ValueError("An error occurred when entering the unit in the register.")
            
    def setColorMode(self, colorMode = pse.ColorMode.RED_ON):
        if colorMode not in pse.ColorMode:
             raise ValueError("The color mode entered is not allowed. Possible values ​​for the color mode are: RED_ON, GREEN_ON, RED_ALWAYS, GREEN_ALWAYS")
        try:
            self.color = self.instance.write_register(address= self.PRESSURE_COLOR_REG, value = colorMode.value)
        except:
            raise ValueError("An error occurred when entering the color in the register.")
        
    def setMeasureLogic(self, measureLogic = pse.MeasureLogic.POSITIVE):
        if measureLogic not in pse.MeasureLogic:
            raise ValueError("The logic entered is not allowed. Possible values for the measure logic are: POSITIVE and NEGATIVE")
        else:
            if measureLogic.name == "POSITIVE":
                self.setPullUpResistor(pse.NPNstatus.NC)
            else:
                self.setPullUpResistor(pse.NPNstatus.NO)

            self.setColorMode(pse.ColorMode.RED_ON)

    def getWorkMode(self):
        return self.mode
    
