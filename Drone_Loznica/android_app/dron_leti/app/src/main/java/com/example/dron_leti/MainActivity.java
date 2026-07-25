package com.example.dron_leti; // Obavezno proveri da li je ovo tvoj pravi paket

import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.util.Timer;
import java.util.TimerTask;

public class MainActivity extends AppCompatActivity {

    private int throttleValue = 1000;
    private float yawValue = 0;
    private float pitchValue = 0;
    private float rollValue = 0;
    private int stopFlag = 0;

    // PID promenljive
    private float rpP = 1.0f, rpI = 0.0f, rpD = 0.0f;
    private float yP = 2.0f, yI = 0.0f, yD = 0.0f;

    // UI Elementi
    private TextView tvThrottle, tvYaw, tvPitch, tvRoll, tvStatus;
    private TextView tvDroneRoll, tvDronePitch, tvDroneYaw; // Telemetrija
    private SeekBar sbThrottle, sbYaw, sbPitch, sbRoll;
    private Button btnStop, btnUpdatePid;
    private EditText etRpP, etRpI, etRpD, etYawP, etYawI, etYawD;

    // --- UDP MREŽA ---
    private String espIpAddress = "192.168.4.1";
    private int espUdpPort = 4210;
    private Timer udpTimer;
    private DatagramSocket udpSocket; // Jedan stalno otvoren socket!
    private Thread receivingThread;
    private boolean isRunning = true;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        tvStatus = findViewById(R.id.tvStatus);
        tvThrottle = findViewById(R.id.tvThrottle);
        tvYaw = findViewById(R.id.tvYaw);
        tvPitch = findViewById(R.id.tvPitch);
        tvRoll = findViewById(R.id.tvRoll);

        tvDroneRoll = findViewById(R.id.tvDroneRoll);
        tvDronePitch = findViewById(R.id.tvDronePitch);
        tvDroneYaw = findViewById(R.id.tvDroneYaw);

        sbThrottle = findViewById(R.id.sbThrottle);
        sbYaw = findViewById(R.id.sbYaw);
        sbPitch = findViewById(R.id.sbPitch);
        sbRoll = findViewById(R.id.sbRoll);
        btnStop = findViewById(R.id.btnStop);
        btnUpdatePid = findViewById(R.id.btnUpdatePid);

        etRpP = findViewById(R.id.etRpP);
        etRpI = findViewById(R.id.etRpI);
        etRpD = findViewById(R.id.etRpD);
        etYawP = findViewById(R.id.etYawP);
        etYawI = findViewById(R.id.etYawI);
        etYawD = findViewById(R.id.etYawD);

        // --- INICIJALIZACIJA MREŽE ---
        try {
            udpSocket = new DatagramSocket(); // OS dodeljuje nasumičan lokalni port
        } catch (Exception e) {
            e.printStackTrace();
        }

        // --- EVENT LISENERI ---
        sbThrottle.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                throttleValue = 1000 + progress;
                tvThrottle.setText("Gas (Throttle): " + throttleValue);
                if (progress > 0) {
                    stopFlag = 0;
                    tvStatus.setText("Spremno za UDP");
                    tvStatus.setTextColor(android.graphics.Color.GREEN);
                }
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        sbYaw.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                yawValue = (progress - 200)/(float)10;
                tvYaw.setText("Skretanje (Yaw): "+ yawValue);
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        sbPitch.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                pitchValue = (progress - 200)/(float)10;
                tvPitch.setText(pitchValue < 0 ? "Napred (Pitch): " + pitchValue : (pitchValue > 0 ? "Nazad (Pitch): " + pitchValue : "Napred/Nazad (Pitch): 0"));
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        sbRoll.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                rollValue = (progress - 200)/(float)10;
                tvRoll.setText(rollValue < 0 ? "Levo (Roll): " + rollValue : (rollValue > 0 ? "Desno (Roll): " + rollValue : "Levo/Desno (Roll): 0"));
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        btnStop.setOnClickListener(v -> {
            sbThrottle.setProgress(0);
            sbYaw.setProgress(200);
            sbPitch.setProgress(200);
            sbRoll.setProgress(200);

            stopFlag = 1;
            tvStatus.setText("HITNO ZAUSTAVLJENO!");
            tvStatus.setTextColor(android.graphics.Color.RED);
        });

        btnUpdatePid.setOnClickListener(v -> {
            try {
                rpP = Float.parseFloat(etRpP.getText().toString());
                rpI = Float.parseFloat(etRpI.getText().toString());
                rpD = Float.parseFloat(etRpD.getText().toString());
                yP = Float.parseFloat(etYawP.getText().toString());
                yI = Float.parseFloat(etYawI.getText().toString());
                yD = Float.parseFloat(etYawD.getText().toString());
                Toast.makeText(MainActivity.this, "PID Vrednosti Primenjene!", Toast.LENGTH_SHORT).show();
            } catch (NumberFormatException e) {
                Toast.makeText(MainActivity.this, "Greška: Proverite format brojeva!", Toast.LENGTH_SHORT).show();
            }
        });

        // Pokrećemo slanje i prijem
        pokreniUdpPrijem();
        pokreniUdpSlanje();
    }

    private void pokreniUdpSlanje() {
        udpTimer = new Timer();
        udpTimer.scheduleAtFixedRate(new TimerTask() {
            @Override
            public void run() {
                posaljiUdpPaket();
            }
        }, 0, 50); // Šaljemo svakih 50ms
    }

    private void posaljiUdpPaket() {
        if (udpSocket == null || udpSocket.isClosed()) return;

        String poruka = "T:" + throttleValue + ",Y:" + yawValue + ",P:" + pitchValue + ",R:" + rollValue + ",S:" + stopFlag +
                ",RPP:" + rpP + ",RPI:" + rpI + ",RPD:" + rpD +
                ",YP:" + yP + ",YI:" + yI + ",YD:" + yD;

        try {
            InetAddress adresa = InetAddress.getByName(espIpAddress);
            byte[] bafer = poruka.getBytes();
            DatagramPacket paket = new DatagramPacket(bafer, bafer.length, adresa, espUdpPort);
            udpSocket.send(paket);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // --- OSLUŠKIVANJE ODGOVORA OD DRONA ---
    private void pokreniUdpPrijem() {
        receivingThread = new Thread(() -> {
            byte[] receiveData = new byte[256];
            while (isRunning) {
                try {
                    if (udpSocket != null && !udpSocket.isClosed()) {
                        DatagramPacket receivePacket = new DatagramPacket(receiveData, receiveData.length);
                        udpSocket.receive(receivePacket); // Nit čeka ovde dok paket ne stigne

                        String incomingMsg = new String(receivePacket.getData(), 0, receivePacket.getLength());

                        // Očekujemo R:12.34,P:-5.67,Y:8.90
                        if(incomingMsg.startsWith("R:")) {
                            String[] delovi = incomingMsg.split(",");
                            if (delovi.length == 3) {
                                String rollStr = delovi[0].replace("R:", "Roll: ");
                                String pitchStr = delovi[1].replace("P:", "Pitch: ");
                                String yawStr = delovi[2].replace("Y:", "Yaw: ");

                                // Osvežavamo UI (samo Main/UI thread sme da dira TextView)
                                runOnUiThread(() -> {
                                    tvDroneRoll.setText(rollStr);
                                    tvDronePitch.setText(pitchStr);
                                    tvDroneYaw.setText(yawStr);
                                });
                            }
                        }
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        });
        receivingThread.start();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        isRunning = false;
        if (udpTimer != null) {
            udpTimer.cancel();
        }
        if (udpSocket != null && !udpSocket.isClosed()) {
            udpSocket.close();
        }
    }
}