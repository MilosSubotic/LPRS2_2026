from pymodbus.client import ModbusSerialClient

class VFD:
    # READ ONLY
    OPERATING_FREQ_REG              = 0x1001
    OUTPUT_VOLTAGE_REG              = 0x1003
    OUTPUT_CURRENT_REG              = 0x1004
    OUTPUT_POWER_REG                = 0x1005
    OUTPUT_TORQUE_PERCENTAGE_REG    = 0x1006

    # WRITE
    SET_FREQUENCY_REG               = 0x1000
    CONTROL_COMMAND_REG             = 0x2000

    # CONTROL COMMANDS
    VALUE_FOR                       = 0x0001
    VALUE_REV                       = 0x0002    # unused
    VALUE_STOP                      = 0x0006

    def __init__(self):
        self.instance = ModbusSerialClient(
            port = '/dev/ttyUSB0',
            baudrate = 9600,
            bytesize = 8,
            parity = 'N',
            stopbits = 1,
            timeout = 1
        )

    def connect(self):
        if self.instance.connect() == False:
            print("Could not connect")
        else:
            print("Connected successfully")

    def run_for(self):
        self.instance.write_register(address = self.CONTROL_COMMAND_REG, value = self.VALUE_FOR)

    # unused
    def run_rev(self):
        self.instance.write_register(address = self.CONTROL_COMMAND_REG, value = self.VALUE_REV)

    def stop(self):
        self.instance.write_register(address = self.CONTROL_COMMAND_REG, value = self.VALUE_STOP)

    def setFrequency(self, v):
        self.instance.write_register(address = self.SET_FREQUENCY_REG, value = int(v * 100))

    def getReadings(self):
        value = self.instance.read_holding_registers(address = self.OPERATING_FREQ_REG)
        valueInHz = float(value.registers[0]) / 100
        print(f"Operating frequency: {valueInHz:.2f}Hz")
        value = self.instance.read_holding_registers(address = self.OUTPUT_VOLTAGE_REG)
        print(f"Output voltage: {value.registers[0]}V")
        value = self.instance.read_holding_registers(address = self.OUTPUT_CURRENT_REG)
        print(f"Output current: {value.registers[0]}A")
        value = self.instance.read_holding_registers(address = self.OUTPUT_POWER_REG)
        print(f"Output power: {value.registers[0]}W")
        value = self.instance.read_holding_registers(address = self.OUTPUT_TORQUE_PERCENTAGE_REG)
        print(f"Output torque percentage: {value.registers[0]}%")

    def help(self):
        print("Commands:")
        print(f"\t'run_for' \t-> starts the VFD in the forwards direction")
        # print(f"\t'run_rev' \t-> starts the VFD in the backwards direction")      -> unused
        print(f"\t'stop' \t-> stops the VFD")
        print(f"\t'set <value>' \t-> sets the running frequency to <value> (max 50.00Hz)")
        print(f"\t'status' \t-> prints current output parameters")
        print(f"\t'help' \t-> prints this help screen")
        print(f"\t'quit' \t-> exits the controller, along with setting the running frequency to 0 and stopping the VFD")


if __name__== "__main__":
    vfd = VFD()
    vfd.connect()
    print("Commands: 'run for', 'stop', 'set <value>', 'status', 'help', 'quit'")
    try:
        while True:
            command = input().strip()
            if command.startswith("set "):
                try:
                    value = float(command.split(" ")[1])
                    if value < 0 or value > 50:
                        raise ValueError
                    vfd.setFrequency(value)
                    print(f"Reading set to {value:.2f}Hz")
                except (IndexError, ValueError):
                    print("Usage: set <value>, 0.00 <= <value> <= 50.00")
            elif command == "run for":
                vfd.run_for()
            elif command == "stop":
                vfd.stop()
            elif command == "status":
                vfd.getReadings()
            elif command == "help":
                vfd.help()
            elif command == "quit":
                print("Exiting the controller")
                vfd.setFrequency(0)
                vfd.stop()
                break
            else:
                print("Invalid command")
    except KeyboardInterrupt:
        print("Exiting the controller")
        vfd.setFrequency(0)
        vfd.stop()
