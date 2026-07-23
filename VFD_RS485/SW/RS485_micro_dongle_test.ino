#include <SoftwareSerial.h>

#define DE_RE_PIN 8
#define RS485_RX  3   // RO → pin 3
#define RS485_TX  2   // DI → pin 2

SoftwareSerial RS485(RS485_RX, RS485_TX);

void setup() {
  Serial.begin(9600);
  RS485.begin(9600);
  pinMode(DE_RE_PIN, OUTPUT);
  digitalWrite(DE_RE_PIN, LOW);  // Start in receive mode
}

void loop() {
  if (Serial.available()) {
    String msg = Serial.readStringUntil('\n');
    digitalWrite(DE_RE_PIN, HIGH);  //  setting to send mode
    RS485.println(msg);
    delay(10);
    digitalWrite(DE_RE_PIN, LOW);   //  setting back to receive
  }

  if (RS485.available()) {
    String incoming = RS485.readStringUntil('\n');
    Serial.println("Received: " + incoming);
  }
}
