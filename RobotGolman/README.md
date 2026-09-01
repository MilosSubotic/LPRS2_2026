YT link: https://youtu.be/r1rNZ8aMOkI

- Pokretanje igre

Po uključivanju sistema prikazuje se glavni meni sa dva režima rada:

Singleplayer
Multiplayer

Pomoću analognog džojstika bira se željeni režim rada, dok se pritiskom na džojstik potvrđuje izbor.

- Singleplayer režim

U ovom režimu Raspberry Pi preuzima kompletnu kontrolu nad golmanom.

Aktivira se USB kamera.
Kamera neprekidno prati kretanje loptice.
Algoritam određuje položaj loptice i predviđa njeno buduće kretanje.
Na osnovu izračunatog položaja Raspberry Pi šalje Arduino Uno ploči odgovarajući ugao servomotora.
Servo motor pomera golmana u pokušaju odbrane šuta.

Ponovnim pritiskom na džojstik igra se prekida, golman se vraća u početni položaj i sistem se vraća u glavni meni.

- Multiplayer režim

U multiplayer režimu korisnik upravlja golmanom pomoću analognog džojstika.

Pomeranjem džojstika ulevo ili udesno servo motor direktno pomera golmana, bez korišćenja kamere i algoritama za detekciju loptice.

Ponovnim pritiskom na džojstik izlazi se iz igre i sistem se vraća u glavni meni.

- Završetak rada

Za bezbedno gašenje sistema potrebno je:

Prekinuti rad programa kombinacijom tastera Ctrl + C.
Izvršiti komandu:
sudo shutdown now
Nakon što se Raspberry Pi potpuno isključi, može se isključiti napajanje sistema.
