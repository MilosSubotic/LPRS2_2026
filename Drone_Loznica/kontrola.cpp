#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <string.h>
#include <linux/input.h>
#include <math.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define ESP32_IP "192.168.4.1" 
#define ESP32_PORT 4210     
#define PATH "/dev/input/event16"     

#define MAX_NAGIB 15.0          

int main() {
    int sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock_fd < 0) {
        perror("Neuspešno kreiranje soketa");
        return 1;
    }

    fcntl(sock_fd, F_SETFL, O_NONBLOCK);

    struct sockaddr_in esp_addr;
    memset(&esp_addr, 0, sizeof(esp_addr));
    esp_addr.sin_family = AF_INET;
    esp_addr.sin_port = htons(ESP32_PORT);
    inet_pton(AF_INET, ESP32_IP, &esp_addr.sin_addr);

    int input_fd = open(PATH, O_RDONLY);
    if (input_fd < 0) {
        perror("Greška pri otvaranju kontrolera! Proveri broj event-a i pokreni sa sudo");
        close(sock_fd);
        return 1;
    }
    fcntl(input_fd, F_SETFL, O_NONBLOCK);

    int left_y = 128;  
    int right_x = 128; 
    int right_y = 128; 
    
    static int l1_pritisnut = 0;
    static int l2_pritisnut = 0;

    int throttle = 1175; 
    static float zadati_yaw = 0.0; 
    float pitch_slanje = 0.0; 
    float roll_slanje = 0.0;  
    int stop_flag = 0;

    float rpp = 1.0, rpi = 1.0, rpd = 0.35;
    float yp = 1.2, yi = 0.5, yd = 0.0;

    struct input_event ev;
    char buffer[256];
    
    int ispis_brojac = 0;

    printf("Povezan na kontroler. Pokrećem upravljanje dronom na (%s:%d)...\n", ESP32_IP, ESP32_PORT);
    printf("Gas je direktno mapiran: Gore=1350, Sredina=1175, Dole=1000.\n");
    printf("-----------------------------------------------------------------\n");

    while (1) {
        while (read(input_fd, &ev, sizeof(struct input_event)) > 0) {
            if (ev.type == EV_KEY) {
                if (ev.code == BTN_SOUTH) { 
                    stop_flag = ev.value;
                }
                else if (ev.code == BTN_TL) { 
                    l1_pritisnut = ev.value; 
                }
                else if (ev.code == BTN_TL2) { 
                    l2_pritisnut = ev.value;
                }
            }
            else if (ev.type == EV_ABS) {
                if (ev.code == ABS_Y) {
                    left_y = ev.value;
                } else if (ev.code == ABS_RX) {
                    right_x = ev.value;
                } else if (ev.code == ABS_RY) {
                    right_y = ev.value;
                }
            }
        }

        if (stop_flag == 1) {
            throttle = 1000;
            zadati_yaw = 0.0;
            pitch_slanje = 0.0;
            roll_slanje = 0.0;
        } 
        else {
            throttle = 1000 + ((255 - left_y) * 350 / 255);

            if (throttle > 1350) throttle = 1350;
            if (throttle < 1000) throttle = 1000;
            if (l1_pritisnut && !l2_pritisnut) {
                zadati_yaw += 0.1;
                if (zadati_yaw > 360.0) zadati_yaw = 360.0;
            }
            else if (l2_pritisnut && !l1_pritisnut) {
                zadati_yaw -= 0.1;
                if (zadati_yaw < -360.0) zadati_yaw = -360.0;
            }

            int pitch_devijacija = right_y - 128; 
            if (abs(pitch_devijacija) > 5) { 
                pitch_slanje = -((float)pitch_devijacija * MAX_NAGIB / 128.0);
            } else {
                pitch_slanje = 0.0;
            }

            int roll_devijacija = right_x - 128;
            if (abs(roll_devijacija) > 5) {  
                roll_slanje = ((float)roll_devijacija * MAX_NAGIB / 128.0);
            } else {
                roll_slanje = 0.0;
            }
        }

        snprintf(buffer, sizeof(buffer), 
                 "T:%d,Y:%.2f,P:%.2f,R:%.2f,S:%d,RPP:%.2f,RPI:%.2f,RPD:%.2f,YP:%.2f,YI:%.2f,YD:%.2f",
                 throttle, zadati_yaw, pitch_slanje, roll_slanje, stop_flag,
                 rpp, rpi, rpd, yp, yi, yd);

        sendto(sock_fd, buffer, strlen(buffer), 0, (struct sockaddr*)&esp_addr, sizeof(esp_addr));

        ispis_brojac++;
        if (ispis_brojac >= 20) {
            printf("\r[STATUS] Gas: %4d | Yaw: %7.2f° | Pitch: %6.2f° | Roll: %6.2f° | STOP: %d", 
                   throttle, zadati_yaw, pitch_slanje, roll_slanje, stop_flag);
            fflush(stdout); 
            ispis_brojac = 0;
        }
        usleep(10000);
    }

    close(input_fd);
    close(sock_fd);
    return 0;
}