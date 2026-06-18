from enum import Enum
class WorkingMode(Enum):
    EASY = 0    # <=> NORMAL   NPN turns on when pressure when under some pressure value
    HYSTERESIS = 1             #NPN turns on when pressure is over high limit, and doesn't turn off until is under low limit
    WINDOW_COMPARATOR = 2       # DEFAULT     NPN turns on when pressure is not in a given range

class Units(Enum):
    MPA = 0
    KPA = 1
    KGF = 2
    BAR = 3  # DEFAULT
    PSI = 4 

class ColorMode(Enum):
    RED_ON = 0      # (NPN)     #DEFAULT
    GREEN_ON = 1    # (NPN)
    RED_ALWAYS = 2
    GREEN_ALWAYS = 3

class MeasureLogic(Enum):   # Positive logic implies that the NPN connection is active when the value is outside the allowed range.     
    POSITIVE = 0     # DEFAULT
    NEGATIVE = 1

class NPNstatus(Enum):
    NO = 0
    NC = 1     