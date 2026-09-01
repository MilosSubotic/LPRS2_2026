//prednji desni motor 17
//prednji levi motor 18
//zadnji desni motor 16
//zadnje levi motor 19

//promena parametara pitch i roll u zavisnosti od naginjanja drona
//napred-pitch u negativno
//nazad-pitch u pozitivno
//levo-roll u negativno
//desno-roll u pozitivno


#include <Wire.h>
#include <algorithm>
#include <math.h>
#include <ESP32Servo.h>
#include <ESP32Servo.h>
#include <WiFi.h>
#include <WiFiUdp.h>

#define roll_offset 2.23
#define pitch_offset -3.08

// --- WIFI I UDP PODEŠAVANJA ---
const char *ssid = "Dron_Mreza";
const char *password = "12345678"; 
WiFiUDP udp;
unsigned int localUdpPort = 4210;
char incomingPacket[255];

// --- DELJENE PROMENLJIVE (Zaštićene Mutexom) ---
SemaphoreHandle_t dataMutex;

int rx_throttle = 1000;
float rx_yaw = 0;
float rx_pitch = 0;
float rx_roll = 0;
int rx_stop_flag = 0;
unsigned long rx_last_packet_time = 0; // Izuzetno bitno za Failsafe!

double roll_filtered;
double pitch_filtered;

float pid_p_gain_roll = 1.6;               //Gain setting for the roll P-controller
float pid_i_gain_roll = 2.5;               //Gain setting for the roll I-controller
float pid_d_gain_roll = 0.308;              //Gain setting for the roll D-controller
int pid_max_roll = 200;                    //Maximum output of the PID-controller (+/-)

float pid_p_gain_pitch = pid_p_gain_roll;  //Gain setting for the pitch P-controller.
float pid_i_gain_pitch = pid_i_gain_roll;  //Gain setting for the pitch I-controller.
float pid_d_gain_pitch = pid_d_gain_roll;  //Gain setting for the pitch D-controller.
int pid_max_pitch = pid_max_roll;          //Maximum output of the PID-controller (+/-)

float pid_p_gain_yaw = 5;                //Gain setting for the pitch P-controller. //4.0
float pid_i_gain_yaw = 2.5;          //Gain setting for the pitch I-controller. //0.02
float pid_d_gain_yaw = 0.0;                //Gain setting for the pitch D-controller.
int pid_max_yaw = 200;                     //Maximum output of the PID-controller (+/-)
float pid_i_mem_roll = 0, pid_last_roll_d_error = 0;
float pid_i_mem_pitch = 0, pid_last_pitch_d_error = 0;
float pid_i_mem_yaw = 0, pid_last_yaw_d_error = 0;
float pid_roll_setpoint, pid_pitch_setpoint, pid_yaw_setpoint;
float pid_output_roll, pid_output_pitch, pid_output_yaw;
float pid_error_temp = 0;

float temp_pitch = 0, temp_yaw = 0, temp_roll = 0;

unsigned int throttle = 1000;
Servo esc1, esc2, esc3, esc4;

const int Gyro_addr = 0x68;
const int SDA_PIN = 21;
const int SCL_PIN = 22;

int16_t raw_ax;
int16_t raw_ay;
int16_t raw_az;
int16_t raw_gx;
int16_t raw_gy;
int16_t raw_gz;
bool flag_stop;
int last_packet;

double dt=0;


int mesto_bafera = 0;


double roll_a, pitch_a;
double roll = 0, pitch = 0, yaw = 0;
double yaw_error = 0, roll_error = 0, pitch_error = 0;
float staro_vreme, vreme;

// ===== KALMAN FILTER STRUKTURA =====
struct KalmanFilter {
  double R;      // Measurement noise (akcelerometar) - VEĆA = manje verovanja akcelerometru
  double Q;      // Process noise (žiroskop) - MANJA = više verovanja žirooskopskom signalu
  double P;
  double U_hat;
  double K;

  KalmanFilter(double R_val = 50.0, double Q_val = 0.01)
    : R(R_val), Q(Q_val), P(0.0), U_hat(0.0), K(0.0) {}

  // Filtriranje sa malim udelom akcelerometra
  double update(double gyro_rate, double accel_angle) {
    // Predikcija (dominantno žiroskop)
    U_hat += gyro_rate;
    P += Q;

    // Korekcija (mali uticaj akcelerometra)
    K = P / (P + R);
    U_hat = U_hat + K * (accel_angle - U_hat);
    P = (1 - K) * P;

    return U_hat;
  }
};

// Parametri za slabu korekciju drifta:
// R = 50.0   → akcelerometar se koristi samo za korekciju, ne dominira
// Q = 0.01   → žiroskop je pouzdan, minimalno šuma
KalmanFilter kalman_roll(150.0, 0.01);
KalmanFilter kalman_pitch(150.0, 0.01);

int last_delivered_time = 0;
const int MISSED_PACKET_TIME_LIMIT = 1000;
SemaphoreHandle_t packet_count_mutex;  



  void udpTask(void *pvParameters) {
    for (;;) {
      int packetSize = udp.parsePacket();
      if (packetSize) {
        int len = udp.read(incomingPacket, 255);
        if (len > 0) {
          incomingPacket[len] = '\0'; // Null-terminacija
        }
  
        // Privremene promenljive za čitanje paketa
        int temp_t = 1000;
        float temp_y = 0, temp_p = 0, temp_r = 0, temp_s = 0;
        float temp_rp_p = 0.0, temp_rp_i = 0.0, temp_rp_d = 0.0;
        float temp_y_p = 0.0, temp_y_i = 0.0, temp_y_d = 0.0;
  
        // Očekujemo format sa komandama i PID vrednostima
        if (sscanf(incomingPacket, "T:%d,Y:%f,P:%f,R:%f,S:%f,RPP:%f,RPI:%f,RPD:%f,YP:%f,YI:%f,YD:%f", 
                   &temp_t, &temp_y, &temp_p, &temp_r, &temp_s, 
                   &temp_rp_p, &temp_rp_i, &temp_rp_d, &temp_y_p, &temp_y_i, &temp_y_d) == 11) {
          
          if (xSemaphoreTake(dataMutex, pdMS_TO_TICKS(2))) {
            rx_throttle = temp_t;
            rx_yaw = temp_y;
            rx_pitch = temp_p;
            rx_roll = temp_r;
            rx_stop_flag = temp_s;
            
            // PID koeficijenti
            pid_p_gain_roll = temp_rp_p;
            pid_i_gain_roll = temp_rp_i;
            pid_d_gain_roll = temp_rp_d;
            pid_p_gain_pitch = pid_p_gain_roll;
            pid_i_gain_pitch = pid_i_gain_roll;
            pid_d_gain_pitch = pid_d_gain_roll;
            pid_p_gain_yaw = temp_y_p;
            pid_i_gain_yaw = temp_y_i;
            pid_i_gain_yaw = temp_y_d;

            rx_last_packet_time = millis();
            if (xSemaphoreTake(packet_count_mutex, pdMS_TO_TICKS(1))) {
                last_delivered_time=micros();
                xSemaphoreGive(packet_count_mutex);
            }
            xSemaphoreGive(dataMutex);
          }

          // === SLANJE TELEMETRIJE NAZAD APLIKACIJI ===
          // Formatiramo string sa uglovima i šaljemo ga nazad
          udp.beginPacket(udp.remoteIP(), udp.remotePort());
          char replyPacket[64];
          snprintf(replyPacket, sizeof(replyPacket), "R:%.2f,P:%.2f,Y:%.2f", roll_filtered, pitch_filtered, yaw);
          udp.print(replyPacket);
          udp.endPacket();

        } else {
          if (xSemaphoreTake(packet_count_mutex, pdMS_TO_TICKS(1))) {
                xSemaphoreGive(packet_count_mutex);
            }
        }
      }
      vTaskDelay(10 / portTICK_PERIOD_MS); 
    }
}



void setup() {
  Serial.begin(115200);

  dataMutex = xSemaphoreCreateMutex();
  packet_count_mutex = xSemaphoreCreateMutex();

  // Podizanje WiFi Access Point-a
  WiFi.softAP(ssid, password);
  udp.begin(localUdpPort);
  Serial.println("WiFi i UDP pokrenuti.");

  // Prebacivanje UDP osluškivanja na Core 0
  xTaskCreatePinnedToCore(
    udpTask,          // Funkcija koju task izvršava
    "udpTask",        // Ime taska
    4096,             // Veličina memorije (stack size)
    NULL,             // Parametri
    1,                // Prioritet (1 je sasvim dovoljno)
    NULL,             // Task handle
    0                 // ZAKUCAJ GA NA CORE 0
  );
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(400000);

  // 1. Buđenje senzora i postavljanje Clock Source-a na Gyro X (preporuka za stabilnost)
  Wire.beginTransmission(Gyro_addr);
  Wire.write(0x6B);
  Wire.write(0x01); // 0x01 je stabilnije nego 0x00
  Wire.endTransmission();
  delay(100);

  // 2. Postavljanje DLPF (Low Pass Filter) na 42Hz
  // Registar 0x1A, vrednost 3 odgovara 42Hz za žiroskop i 44Hz za akcelerometar
  Wire.beginTransmission(Gyro_addr);
  Wire.write(0x1A);
  Wire.write(0x03); 
  Wire.endTransmission();

  // 3. Postavljanje opsega žiroskopa na +/- 1000 stepeni/s
  // Registar 0x1B, vrednost 0x10 (binarno 00010000) postavlja FS_SEL na 2
  Wire.beginTransmission(Gyro_addr);
  Wire.write(0x1B);
  Wire.write(0x10); 
  Wire.endTransmission();

  // 4. Postavljanje Sample Rate na 1kHz
  // Formula: Sample Rate = Internal_Output_Rate / (1 + SMPLRT_DIV)
  // Kada je DLPF upaljen, Internal_Output_Rate je 1kHz.
  // Da dobijemo 1kHz, SMPLRT_DIV mora biti 0 (1000 / (1 + 0) = 1000Hz)
  Wire.beginTransmission(Gyro_addr);
  Wire.write(0x19);
  Wire.write(0x00); 
  Wire.endTransmission();
  
  Serial.println("Kalibrac  ija ziroskopa... NE DIRAJ DRONA!");
  delay(5000);
  for (int i = 0; i < 500; i++) {
    citaj_senzor();
    //Sabiramo sirove podatke
    pitch_error += raw_gx;
    roll_error += raw_gy;
    yaw_error += raw_gz;
    delayMicroseconds(200); // Malo cekamo da senzor osvezi vrednost
  }
  pitch_error /= 500;
  roll_error /= 500;
  yaw_error /= 500;

  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);

  esc1.setPeriodHertz(100);
  esc2.setPeriodHertz(100);
  esc3.setPeriodHertz(100);
  esc4.setPeriodHertz(100);

  esc1.attach(17, 1000, 2000);//prednji desni
  esc2.attach(18, 1000, 2000);//prednji levi
  esc3.attach(16, 1000, 2000);//zadnji desni
  esc4.attach(19, 1000, 2000);//zadnji levi

  esc1.writeMicroseconds(1000);
  esc2.writeMicroseconds(1000);
  esc3.writeMicroseconds(1000);
  esc4.writeMicroseconds(1000); 
  staro_vreme = micros();
}

void loop() {
  unsigned long vreme_pocetka_ciklusa = micros();

  unsigned long  last_delivered_time1 = 0;
  if (xSemaphoreTake(packet_count_mutex, pdMS_TO_TICKS(1))) {
      last_delivered_time1 = last_delivered_time;
      xSemaphoreGive(packet_count_mutex);
  }
  if (xSemaphoreTake(dataMutex, pdMS_TO_TICKS(2))){
      throttle=rx_throttle;
      pid_yaw_setpoint=rx_yaw;
      pid_pitch_setpoint=rx_pitch;
      pid_roll_setpoint=rx_roll;
      flag_stop=rx_stop_flag;
      last_packet=rx_last_packet_time;
  
    
      xSemaphoreGive(dataMutex);
    }
  if(flag_stop!=1 && vreme_pocetka_ciklusa-last_delivered_time1 < MISSED_PACKET_TIME_LIMIT*1000){
    
    
    
    
      citaj_senzor();
    
      float x = (float)raw_ax;
      float y = (float)raw_ay;
      float z = (float)raw_az;
    
      //Uglovi iz akcelerometra
      pitch_a  = atan2(y, z) * 180.0 / PI;
      roll_a = atan2(-x, sqrt(y * y + z * z)) * 180.0 / PI;
    
      // Ugaone brzine sa žiroskopa (u stepenima/sec)
      float gx_degs = (raw_gx - pitch_error) / 32.8;
      float gy_degs = (raw_gy - roll_error) / 32.8;
      float gz_degs = (raw_gz - yaw_error) / 32.8;
    
      vreme = micros();
      dt = (vreme - staro_vreme) / 1000000.0;
      staro_vreme = vreme;
    
    
      // ===== OPCIJA 1: KALMAN FILTER (preporučeno za PID) =====
      roll_filtered  = kalman_roll.update(gy_degs * dt, roll_a);
      pitch_filtered = kalman_pitch.update(gx_degs * dt, pitch_a);
      yaw += (gz_degs * dt);
    
      calculate_pid();
      int esc_1_value;
      int esc_2_value;
      int esc_3_value;
      int esc_4_value;
      
      if (throttle < 1050) {
        // Dron je na zemlji, gasimo motore i resetujemo PID memoriju
        esc_1_value = 1000;
        esc_2_value = 1000;
        esc_3_value = 1000;
        esc_4_value = 1000;
        
        pid_i_mem_roll = 0;
        pid_last_roll_d_error = 0;
        pid_i_mem_pitch = 0;
        pid_last_pitch_d_error = 0;
        pid_i_mem_yaw = 0;
        pid_last_yaw_d_error = 0;
      }else{
        esc_1_value = throttle - pid_output_pitch + pid_output_roll + pid_output_yaw;  // Prednji desni-17-CCW
        esc_2_value = throttle - pid_output_pitch - pid_output_roll - pid_output_yaw;  // Prednji levi-18-CW
        esc_3_value = throttle + pid_output_pitch + pid_output_roll - pid_output_yaw;  // Zadnji desni-16-CW
        esc_4_value = throttle + pid_output_pitch - pid_output_roll + pid_output_yaw;  // Zadnji levi-19-CCW
          
      }
  
      
      esc1.writeMicroseconds(constrain(esc_1_value, 1000, 2000));
      esc2.writeMicroseconds(constrain(esc_2_value, 1000, 2000));
      esc3.writeMicroseconds(constrain(esc_3_value, 1000, 2000));
      esc4.writeMicroseconds(constrain(esc_4_value, 1000, 2000));
    
    
    
      
      
    }else{
      int esc_1_value = 1000;// Prednji desni-17-CCW
      int esc_2_value = 1000;  // Prednji levi-18-CW
      int esc_3_value = 1000;  // Zadnji desni-16-CW
      int esc_4_value = 1000;  // Zadnji levi-19-CCW
      esc1.writeMicroseconds(esc_1_value);
      esc2.writeMicroseconds(esc_2_value);
      esc3.writeMicroseconds(esc_3_value);
      esc4.writeMicroseconds(esc_4_value);
      pid_i_mem_roll = 0;
      pid_last_roll_d_error = 0;
      pid_i_mem_pitch = 0;
      pid_last_pitch_d_error = 0;
      pid_i_mem_yaw = 0;
      pid_last_yaw_d_error = 0;
    
      
          
      if (xSemaphoreTake(dataMutex, pdMS_TO_TICKS(2))) {
        throttle=rx_throttle;
        pid_yaw_setpoint=rx_yaw;
        pid_pitch_setpoint=rx_pitch;
        pid_roll_setpoint=rx_roll;
        flag_stop=rx_stop_flag;
        last_packet=rx_last_packet_time;
    
      
        xSemaphoreGive(dataMutex);
      }
      
    }
  while (micros() - vreme_pocetka_ciklusa < 10000) {
    yield();
  }

}
void citaj_senzor() {
  Wire.beginTransmission(Gyro_addr);
  Wire.write(0x3B);
  Wire.endTransmission(false);
  Wire.requestFrom(Gyro_addr, 14, true);

  if (Wire.available() == 14) {
    raw_ax = (Wire.read() << 8 | Wire.read());
    raw_ay = (Wire.read() << 8 | Wire.read());
    raw_az = (Wire.read() << 8 | Wire.read());
    trash  = (Wire.read() << 8 | Wire.read());
    raw_gx = (Wire.read() << 8 | Wire.read());
    raw_gy = (Wire.read() << 8 | Wire.read());
    raw_gz = (Wire.read() << 8 | Wire.read());
  }
}

void calculate_pid() {
  //---------------------ROLL--------------------------
  pid_error_temp = roll_filtered - pid_roll_setpoint + roll_offset;
  pid_i_mem_roll += pid_i_gain_roll * pid_error_temp * dt;

  if (pid_i_mem_roll > pid_max_roll)pid_i_mem_roll = pid_max_roll;
  else if (pid_i_mem_roll < pid_max_roll * -1)pid_i_mem_roll = pid_max_roll * -1;
  pid_output_roll = pid_p_gain_roll * pid_error_temp + pid_i_mem_roll + pid_d_gain_roll * (pid_error_temp - pid_last_roll_d_error)/dt;///dt;

  if (pid_output_roll > pid_max_roll)pid_output_roll = pid_max_roll;
  else if (pid_output_roll < pid_max_roll * -1)pid_output_roll = pid_max_roll * -1;

  pid_last_roll_d_error = pid_error_temp;
  //---------------------PITCH-------------------------
  pid_error_temp = pitch_filtered - pid_pitch_setpoint + pitch_offset;
  pid_i_mem_pitch += pid_i_gain_pitch * pid_error_temp * dt;

  if (pid_i_mem_pitch > pid_max_pitch)pid_i_mem_pitch = pid_max_pitch;
  else if (pid_i_mem_pitch < pid_max_pitch * -1)pid_i_mem_pitch = pid_max_pitch * -1;

  pid_output_pitch = pid_p_gain_pitch * pid_error_temp + pid_i_mem_pitch + pid_d_gain_pitch * (pid_error_temp - pid_last_pitch_d_error)/dt;///dt;
  if (pid_output_pitch > pid_max_pitch)pid_output_pitch = pid_max_pitch;
  else if (pid_output_pitch < pid_max_pitch * -1)pid_output_pitch = pid_max_pitch * -1;

  pid_last_pitch_d_error = pid_error_temp;

  //---------------------YAW---------------------------
  pid_error_temp = yaw - pid_yaw_setpoint;
  pid_i_mem_yaw += pid_i_gain_yaw * pid_error_temp * dt;
  if (pid_i_mem_yaw > pid_max_yaw)pid_i_mem_yaw = pid_max_yaw;
  else if (pid_i_mem_yaw < pid_max_yaw * -1)pid_i_mem_yaw = pid_max_yaw * -1;

  pid_output_yaw = pid_p_gain_yaw * pid_error_temp + pid_i_mem_yaw + pid_d_gain_yaw * (pid_error_temp - pid_last_yaw_d_error)/dt;///dt;
  if (pid_output_yaw > pid_max_yaw)pid_output_yaw = pid_max_yaw;
  else if (pid_output_yaw < pid_max_yaw * -1)pid_output_yaw = pid_max_yaw * -1;

  pid_last_yaw_d_error = pid_error_temp;

}
