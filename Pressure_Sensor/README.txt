RS-485 Communication Pressure Gauge

## Project Description

This project is a Python application used for communication with an industrial pressure sensor over RS-485 / Modbus RTU protocol.

The application allows:

* reading the current pressure value,
* setting the lower and upper pressure limits,
* setting the target pressure value,
* selecting the sensor working mode,
* selecting the measurement unit,
* configuring the NPN output,
* configuring the sensor logic,
* printing the current sensor status in the console.

## Project Structure

pressure_sensor.py
Contains the PressureSensor class. This class includes all methods required for communication with the sensor, reading registers, and writing values to registers.

pressure_sensor_enum.py
Contains enumerations used for working modes, measurement units, color modes, measurement logic, and NPN status.

requirements.txt
Contains the Python libraries required to run the project.

## Required Libraries

To use this project, install the required Python libraries from requirements.txt.

Installation:

```
pip install -r requirements.txt
```

If a virtual environment is used, it should be activated before running the installation command.

## Running the Program

Before running the program, check which serial port is used by the RS-485 adapter.

Example:

```
python main.py
```

The current example of main.py uses the following port:

```
/dev/ttyUSB0
```

If the sensor is connected to another port, change the port value when creating the PressureSensor object:

```
sensor = PressureSensor(port="/dev/ttyUSB0")
```

## Default Sensor Configuration

When a PressureSensor object is created, the following default values are used:

* highLimit = 6.0 bar
* lowLimit = 5.0 bar
* targetValue = 6.0 bar     //doesn't matter
* mode = WINDOW_COMPARATOR
* unit = BAR
* measureLogic = POSITIVE

This means that the sensor works in WINDOW_COMPARATOR mode by default, with the allowed pressure range between 5.0 bar and 6.0 bar.

## Working Modes

The sensor supports three working modes:

1. EASY / NORMAL

   This mode uses one target value.
   The NPN output is activated when the pressure exceeds the upper limit.

2. HYSTERESIS

   This mode uses the lower and upper pressure limits.
   The NPN output is activated when the pressure exceeds the upper limit and remains active until the pressure drops below the lower limit.

3. WINDOW_COMPARATOR

   This mode uses the lower and upper pressure limits.
   In positive logic, the NPN output is active when the pressure value is outside the configured range.

## Measurement Logic

The project supports two measurement logic modes:

1. POSITIVE

   In WINDOW_COMPARATOR mode, the NPN output is active when the pressure is outside the allowed range.

2. NEGATIVE

   The output logic is inverted compared to the positive logic mode.

## Measurement Units

The supported measurement units are:

* MPA
* KPA
* KGF
* BAR
* PSI

The default (only) measurement unit is BAR.

## Allowed Pressure Range

The pressure values written to the sensor must be within the allowed range:

```
1.01 bar - 10.0 bar
```

If a value outside this range is entered, the program raises an error.

## Example Usage

Creating a sensor object with default values:

```
sensor = PressureSensor(port="/dev/ttyUSB0")
```

Creating a sensor object with custom configuration:

```
sensor = PressureSensor(
    port="/dev/ttyUSB0",
    highLimit=6.0,
    lowLimit=5.0,
    targetValue=6.0,
    mode=pse.WorkingMode.WINDOW_COMPARATOR,
    unit=pse.Units.BAR,
    measureLogic=pse.MeasureLogic.POSITIVE
)
```

## Main Program Loop  // Example

The main.py file prints the current sensor status every 5 seconds.

The printed status includes:

* current pressure,
* lower pressure limit,
* upper pressure limit,
* target pressure value,
* NPN output status,
* current working mode.

## Notes

* Make sure that the sensor is physically connected before running the program.
* Make sure that the correct serial port is selected.
* On Linux systems, the serial port is usually /dev/ttyUSB0 or /dev/ttyACM0.
* If there is no communication with the sensor, check the baudrate, wiring, RS-485 adapter, and port permissions.
* The project uses Modbus RTU communication.
