## 1. Requirements & Dependencies
Install tools for compiling and the Java Runtime Environment (JRE) needed to run the simulator:

```
sudo apt update && sudo apt install -y gcc make default-jre flex bison
```

Beta simulator is provided in simulator directory.

---

## 2. Install

The install.sh script copies beta.uasm to /usr/local/share/beta (default include path) and makes ./betac globally accessible.
Run the installer:

```
sudo chmod +x install.sh
sudo ./install.sh
```

---

## 3. Run Simulator
Start the graphical simulator:
```
java -jar bsim.jar
```
Inside the simulator, simply load your compiled .uasm file and run.


---
## 4. Youtube video demonstration:
```
https://www.youtube.com/watch?v=UT04qsTdKA4
```
