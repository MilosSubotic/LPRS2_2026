//Sinisa Stevanovic RA58/2023
#include <iostream>
#include <cmath>
#include <vector>
#include <cstdlib> 
#include <algorithm>

struct KeyPoint {
    int x;
    int y;
    float angle;
    int score; 
    unsigned char descriptor[32]; 
};

const int krug_x[16] = { 0,  1,  2,  3, 3, 3, 2, 1, 0, -1, -2, -3, -3, -3, -2, -1 };
const int krug_y[16] = {-3, -3, -2, -1, 0, 1, 2, 3, 3,  3,  2,  1,  0, -1, -2, -3 };

static int par_Ax[256], par_Ay[256];
static int par_Bx[256], par_By[256];
static bool parovi_generisani = false;

void generisi_brief_parove() {
    std::srand(42); 
    for(int i = 0; i < 256; i++) {
        par_Ax[i] = std::rand() % 31 - 15; 
        par_Ay[i] = std::rand() % 31 - 15;
        par_Bx[i] = std::rand() % 31 - 15;
        par_By[i] = std::rand() % 31 - 15;
    }
    parovi_generisani = true;
}

int jel_fast_tacka_sa_skorom(const std::vector<unsigned char>& gray, int cx, int cy, int width, int height, int threshold) {
    int p_idx = cy * width + cx;
    unsigned char p_val = gray[p_idx];
    int provera_idx[4] = {0, 4, 8, 12};
    int svetliji_brojac = 0, tamniji_brojac = 0;

    for (int i = 0; i < 4; i++) {
        int k = provera_idx[i];
        unsigned char n_val = gray[(cy + krug_y[k]) * width + (cx + krug_x[k])];
        if (n_val > p_val + threshold) svetliji_brojac++;
        if (n_val < p_val - threshold) tamniji_brojac++;
    }
    if (svetliji_brojac < 3 && tamniji_brojac < 3) return 0;

    unsigned char v[16];
    for (int i = 0; i < 16; i++) {
        v[i] = gray[(cy + krug_y[i]) * width + (cx + krug_x[i])];
    }

    bool jeste_tacka = false;
    for (int i = 0; i < 16; i++) {
        bool niz_svetliji = true, niz_tamniji = true;
        for (int n = 0; n < 9; n++) {
            int idx = (i + n) % 16;
            if (v[idx] <= p_val + threshold) niz_svetliji = false;
            if (v[idx] >= p_val - threshold) niz_tamniji = false;
        }
        if (niz_svetliji || niz_tamniji) {
            jeste_tacka = true;
            break;
        }
    }

    if (!jeste_tacka) return 0;

    int skor = 0;
    for (int i = 0; i < 16; i++) {
        skor += std::abs(v[i] - p_val);
    }
    return skor;
}

float izracunaj_orijentaciju(const std::vector<unsigned char>& gray, int cx, int cy, int width, int height) {
    long long m10 = 0, m01 = 0;
    int poluprecnik = 7;
    for (int y = -poluprecnik; y <= poluprecnik; y++) {
        for (int x = -poluprecnik; x <= poluprecnik; x++) {
            int nx = cx + x, ny = cy + y;
            if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                unsigned char intenzitet = gray[ny * width + nx];
                m10 += x * intenzitet;
                m01 += y * intenzitet;
            }
        }
    }
    return std::atan2(m01, m10);
}

int izracunaj_hamingovu(const unsigned char* d1, const unsigned char* d2) {
    int distanca = 0;
    for (int i = 0; i < 32; i++) {
        distanca += __builtin_popcount(d1[i] ^ d2[i]);
    }
    return distanca;
}

bool sortiraj_po_skoru(const KeyPoint& a, const KeyPoint& b) {
    return a.score > b.score;
}

extern "C" {
    void stabilizuj_frejm(unsigned char *data, int width, int height, int channels, int stride) {
        if (!parovi_generisani) {
            generisi_brief_parove();
        }

        // ZAKRPA 1: Statička memorija koja se reciklira
        static std::vector<unsigned char> gray;
        if (gray.size() != width * height) {
            gray.resize(width * height);
        }
        
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int index = (y * stride) + (x * channels);
                unsigned char b = data[index];
                unsigned char g = data[index + 1];
                unsigned char r = data[index + 2];
                gray[y * width + x] = (unsigned char)((114 * b + 587 * g + 299 * r) / 1000);
            }
        }

        std::vector<KeyPoint> sve_tacke;
        int prag = 10; 

        
        for (int y = 25; y < height - 25; y++) {
            for (int x = 25; x < width - 25; x++) {
                int skor = jel_fast_tacka_sa_skorom(gray, x, y, width, height, prag);
                if (skor > 0) {
                    KeyPoint kp;
                    kp.x = x;
                    kp.y = y;
                    kp.score = skor;
                    sve_tacke.push_back(kp);
                }
            }
        }

        std::sort(sve_tacke.begin(), sve_tacke.end(), sortiraj_po_skoru);

        int max_tacaka = 250;
        if (sve_tacke.size() > max_tacaka) {
            sve_tacke.resize(max_tacaka);
        }

        std::vector<KeyPoint> kljucne_tacke;
        for (auto& kp : sve_tacke) {
            kp.angle = izracunaj_orijentaciju(gray, kp.x, kp.y, width, height);
            
            for(int d = 0; d < 32; d++) kp.descriptor[d] = 0;

            float cos_t = std::cos(kp.angle);
            float sin_t = std::sin(kp.angle);

            for(int i = 0; i < 256; i++) {
                int ax_rot = std::round(par_Ax[i] * cos_t - par_Ay[i] * sin_t);
                int ay_rot = std::round(par_Ax[i] * sin_t + par_Ay[i] * cos_t);
                int bx_rot = std::round(par_Bx[i] * cos_t - par_By[i] * sin_t);
                int by_rot = std::round(par_Bx[i] * sin_t + par_By[i] * cos_t);
                
                int pA = gray[(kp.y + ay_rot) * width + (kp.x + ax_rot)];
                int pB = gray[(kp.y + by_rot) * width + (kp.x + bx_rot)];
                
                if (pA < pB) {
                    kp.descriptor[i / 8] |= (1 << (i % 8));
                }
            }
            kljucne_tacke.push_back(kp);
        }

        static std::vector<KeyPoint> prethodne_tacke;
        
        static float kumu_dx = 0.0f;
        static float kumu_dy = 0.0f;

        int prosecan_potres_x = 0;
        int prosecan_potres_y = 0;

        if (!prethodne_tacke.empty() && !kljucne_tacke.empty()) {
            
            std::vector<int> dx_lista;
            std::vector<int> dy_lista;

            for (const auto& curr : kljucne_tacke) {
                int najbolja_distanca = 256;
                KeyPoint najbolji_par;

                for (const auto& prev : prethodne_tacke) {
                    int dist = izracunaj_hamingovu(curr.descriptor, prev.descriptor);
                    if (dist < najbolja_distanca) {
                        najbolja_distanca = dist;
                        najbolji_par = prev;
                    }
                }

                if (najbolja_distanca < 45) {
                    int dx = curr.x - najbolji_par.x;
                    int dy = curr.y - najbolji_par.y;

                    if (std::abs(dx) < 30 && std::abs(dy) < 30) {
                        dx_lista.push_back(dx);
                        dy_lista.push_back(dy);
                    }
                }
            }

            if (dx_lista.size() > 8) {
                std::sort(dx_lista.begin(), dx_lista.end());
                std::sort(dy_lista.begin(), dy_lista.end());
                
                int medijana_dx = dx_lista[dx_lista.size() / 2];
                int medijana_dy = dy_lista[dy_lista.size() / 2];

                kumu_dx += (float)medijana_dx;
                kumu_dy += (float)medijana_dy;
            }
        }
        
        int zoom_procenat = 130; 
        int centar_x = width / 2;
        int centar_y = height / 2;
        
        kumu_dx *= 0.95f;
        kumu_dy *= 0.95f;

        int max_x = centar_x - (centar_x * 100) / zoom_procenat;
        int max_y = centar_y - (centar_y * 100) / zoom_procenat;

        if (kumu_dx > max_x) kumu_dx = max_x;
        if (kumu_dx < -max_x) kumu_dx = -max_x;
        if (kumu_dy > max_y) kumu_dy = max_y;
        if (kumu_dy < -max_y) kumu_dy = -max_y;
        prosecan_potres_x = std::round(kumu_dx);
        prosecan_potres_y = std::round(kumu_dy);

        
        static std::vector<unsigned char> temp_bgr;
        if (temp_bgr.size() != stride * height) {
            temp_bgr.resize(stride * height);
        }

        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int dest_idx = (y * stride) + (x * channels);
                
                int izvor_x = ((x - centar_x) * 100) / zoom_procenat + centar_x + prosecan_potres_x;
                int izvor_y = ((y - centar_y) * 100) / zoom_procenat + centar_y + prosecan_potres_y;
                
                if (izvor_x >= 0 && izvor_x < width && izvor_y >= 0 && izvor_y < height) {
                    int src_idx = (izvor_y * stride) + (izvor_x * channels);
                    temp_bgr[dest_idx]     = data[src_idx];     // B
                    temp_bgr[dest_idx + 1] = data[src_idx + 1]; // G
                    temp_bgr[dest_idx + 2] = data[src_idx + 2]; // R
                } else {
                    temp_bgr[dest_idx]     = 0;
                    temp_bgr[dest_idx + 1] = 0;
                    temp_bgr[dest_idx + 2] = 0;
                }
            }
        }
        
        std::copy(temp_bgr.begin(), temp_bgr.end(), data);
        
        prethodne_tacke = kljucne_tacke;
    } 
} // Kraj extern "C" bloka