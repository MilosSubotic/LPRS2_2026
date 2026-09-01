#include <SoftwareSerial.h>
#include <Servo.h>

SoftwareSerial mojUART(12, 13); // RX, TX
Servo mojServo;

const int pinPecurkaX = A0; 
const int pinKlik = 2;       // SW pin sa pecurke ide na Digital 2
const int pinServo = 11;

int trenutniMod = 1;         // 1 = Selektovan Singleplayer, 2 = Selektovan Multiplayer
bool igraAktivna = false;

// Varijable za filtriranje treperenja tastera (Debounce)
unsigned long vremeZadnjegKlika = 0;
const unsigned long debouncePauza = 300; 

void prikaziMeni() {
  Serial.println("\n=======================");
  Serial.println("     GLAVNI MENI       ");
  Serial.println("=======================");
  if (trenutniMod == 1) {
    Serial.println(" > [1. SINGLEPLAYER] < ");
    Serial.println("   [2. MULTIPLAYER]   ");
  } else {
    Serial.println("   [1. SINGLEPLAYER]   ");
    Serial.println(" > [2. MULTIPLAYER] < ");
  }
  Serial.println("Pomeraj LEVO/DESNO za izbor, KLIKNI za START.");
}

void setup() {
  Serial.begin(9600);   
  mojUART.begin(9600);  
  mojServo.attach(pinServo);
  mojServo.write(90);   // Golman na sredinu
  
  pinMode(pinKlik, INPUT_PULLUP); 
  
  prikaziMeni();
}

void loop() {
  int kliknut = digitalRead(pinKlik);
  int citanjeX = analogRead(pinPecurkaX);
  
  if (kliknut == LOW && (millis() - vremeZadnjegKlika > debouncePauza)) {
    vremeZadnjegKlika = millis();
    
    if (!igraAktivna) {
      igraAktivna = true;
      Serial.print("\n[IGRA POKRENUTA] Ulazim u mod: ");
      Serial.println(trenutniMod);
      mojUART.write((byte)trenutniMod);
    } 
    else {
      igraAktivna = false;
      Serial.println("\n[PREKID] Igra zaustavljena. Povratak u meni...");
      mojUART.write((byte)0); 
      mojServo.write(90); // Vraca golmana na sredinu
      delay(500);
      prikaziMeni();
    }
    delay(200);
  }
  
  if (!igraAktivna) {
    if (citanjeX < 200 && trenutniMod != 1) {
      trenutniMod = 1;
      prikaziMeni();
      delay(300);
    }
    if (citanjeX > 800 && trenutniMod != 2) {
      trenutniMod = 2;
      prikaziMeni();
      delay(300);
    }
  }
  
  if (igraAktivna) {
    if (trenutniMod == 1) {
      if (mojUART.available() > 0) {
        int ugao = mojUART.read();
        if (ugao >= 30 && ugao <= 150) {
          mojServo.write(ugao);
        }
      }
    }
    if (trenutniMod == 2) {
      int vrednostX = analogRead(pinPecurkaX);
      int ugao = map(vrednostX, 0, 1023, 30, 150);
      mojServo.write(ugao);
      delay(15);
    }
  }
}
